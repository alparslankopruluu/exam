import { createHash } from "crypto";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { google } from "googleapis";
import {
  APPLE_APP_ID,
  APPLE_BUNDLE_ID,
  APPLE_ENVIRONMENT,
  APPLE_IAP_PRIVATE_KEY,
  APPLE_ISSUER_ID,
  APPLE_KEY_ID,
  APPLE_ROOT_CERTS_B64_JSON,
  SMALL_CREDIT_PACK_AMOUNT
} from "./config.js";
import { asString, requireUid } from "./auth.js";

const db = getFirestore();

type VerifiedPurchase = {
  verified: boolean;
  externalId: string;
  expiresAt?: Date;
};

function ledgerId(platform: string, externalId: string): string {
  return platform + "_" + createHash("sha256").update(externalId).digest("hex");
}

async function grantVerifiedPurchase(
  uid: string,
  platform: string,
  productId: string,
  externalId: string,
  expiresAt?: Date
): Promise<void> {
  const ledgerRef = db.doc(`purchaseLedger/${ledgerId(platform, externalId)}`);

  if (productId === "ai_credits_small") {
    const amount = Math.max(1, Number(SMALL_CREDIT_PACK_AMOUNT.value()) || 25);

    await db.runTransaction(async tx => {
      const existing = await tx.get(ledgerRef);
      if (existing.exists) return;

      tx.set(db.doc(`users/${uid}`), {
        credits: FieldValue.increment(amount),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });

      tx.set(ledgerRef, {
        uid,
        platform,
        productId,
        externalIdHash: ledgerRef.id,
        consumable: true,
        verifiedAt: FieldValue.serverTimestamp()
      });
    });
    return;
  }

  if (productId === "premium_annual" || productId === "premium_monthly") {
    const batch = db.batch();

    batch.set(db.doc(`users/${uid}/entitlements/premium`), {
      active: true,
      productId,
      platform,
      expiresAt: expiresAt ? Timestamp.fromDate(expiresAt) : null,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    batch.set(ledgerRef, {
      uid,
      platform,
      productId,
      externalIdHash: ledgerRef.id,
      consumable: false,
      expiresAt: expiresAt ? Timestamp.fromDate(expiresAt) : null,
      verifiedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    await batch.commit();
  }
}

async function verifyGoogle(data: any): Promise<VerifiedPurchase> {
  const packageName = asString(data.packageName, "packageName", 300);
  const purchaseToken = asString(data.purchaseToken, "purchaseToken", 5_000);
  const productId = asString(data.productId, "productId", 300);
  const productType = asString(data.productType, "productType", 100);

  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"]
  });

  const publisher = google.androidpublisher({ version: "v3", auth });

  if (productType === "subs") {
    const response = await publisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken
    });

    const lineItems = response.data.lineItems ?? [];
    const productMatches = lineItems.some(item => item.productId === productId);
    const state = response.data.subscriptionState ?? "";
    const active = new Set([
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
    ]).has(state);

    const expiry = lineItems
      .map(item => item.expiryTime ? Date.parse(item.expiryTime) : 0)
      .reduce((max, value) => Math.max(max, value), 0);

    return {
      verified: productMatches && active && expiry > Date.now(),
      externalId: purchaseToken,
      expiresAt: expiry > 0 ? new Date(expiry) : undefined
    };
  }

  const response = await publisher.purchases.products.get({
    packageName,
    productId,
    token: purchaseToken
  });

  return {
    verified: Number(response.data.purchaseState ?? 1) === 0,
    externalId: purchaseToken
  };
}

async function verifyApple(data: any): Promise<VerifiedPurchase> {
  const transactionId = asString(data.transactionId, "transactionId", 300);
  const requestedProductId = asString(data.productId, "productId", 300);
  const apple: any = await import("@apple/app-store-server-library");

  const environment = APPLE_ENVIRONMENT.value().toLowerCase() === "production"
    ? apple.Environment.PRODUCTION
    : apple.Environment.SANDBOX;

  const client = new apple.AppStoreServerAPIClient(
    APPLE_IAP_PRIVATE_KEY.value(),
    APPLE_KEY_ID.value(),
    APPLE_ISSUER_ID.value(),
    APPLE_BUNDLE_ID.value(),
    environment
  );

  const response = await client.getTransactionInfo(transactionId);
  const signedTransaction = response.signedTransactionInfo;
  if (!signedTransaction) {
    return { verified: false, externalId: transactionId };
  }

  const rootsJson = JSON.parse(APPLE_ROOT_CERTS_B64_JSON.value()) as string[];
  const roots = rootsJson.map(value => Buffer.from(value, "base64"));
  const appAppleId = Number(APPLE_APP_ID.value()) || undefined;

  const verifier = new apple.SignedDataVerifier(
    roots,
    true,
    environment,
    APPLE_BUNDLE_ID.value(),
    appAppleId
  );

  const transaction = await verifier.verifyAndDecodeTransaction(signedTransaction);
  const actualProductId = String(transaction.productId ?? "");
  const actualTransactionId = String(transaction.transactionId ?? transactionId);
  const expiresAt = transaction.expiresDate
    ? new Date(Number(transaction.expiresDate))
    : undefined;

  return {
    verified:
      actualProductId === requestedProductId &&
      !transaction.revocationDate &&
      (!expiresAt || expiresAt.getTime() > Date.now()),
    externalId: actualTransactionId,
    expiresAt
  };
}

export const verifyStorePurchase = onCall(
  {
    secrets: [APPLE_IAP_PRIVATE_KEY, APPLE_ROOT_CERTS_B64_JSON],
    timeoutSeconds: 60,
    memory: "512MiB"
  },
  async request => {
    const uid = requireUid(request);
    const data = request.data as any;
    const platform = asString(data.platform, "platform", 30);
    const productId = asString(data.productId, "productId", 300);

    let result: VerifiedPurchase;

    try {
      if (platform === "google") {
        result = await verifyGoogle(data);
      } else if (platform === "apple") {
        result = await verifyApple(data);
      } else {
        throw new HttpsError("invalid-argument", "Unsupported platform.");
      }
    } catch (error) {
      console.error("Purchase verification failed", error);
      return { verified: false };
    }

    if (result.verified) {
      await grantVerifiedPurchase(
        uid,
        platform,
        productId,
        result.externalId,
        result.expiresAt
      );
    }

    return { verified: result.verified };
  }
);
