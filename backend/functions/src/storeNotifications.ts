import { createHash } from "crypto";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { google } from "googleapis";
import { onRequest } from "firebase-functions/v2/https";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import {
  APPLE_APP_ID,
  APPLE_BUNDLE_ID,
  APPLE_IAP_PRIVATE_KEY,
  APPLE_ROOT_CERTS_B64_JSON
} from "./config.js";

const db = getFirestore();

function ledgerId(platform: string, externalId: string): string {
  return platform + "_" + createHash("sha256").update(externalId).digest("hex");
}

async function updatePremium(args: {
  uid: string;
  productId: string;
  platform: string;
  active: boolean;
  expiresAt?: Date;
}): Promise<void> {
  await db.doc(`users/${args.uid}/entitlements/premium`).set({
    active: args.active,
    productId: args.productId,
    platform: args.platform,
    expiresAt: args.expiresAt ? Timestamp.fromDate(args.expiresAt) : null,
    updatedAt: FieldValue.serverTimestamp()
  }, { merge: true });
}

async function appleVerifier(sandbox: boolean): Promise<any> {
  const apple: any = await import("@apple/app-store-server-library");
  const environment = sandbox ? apple.Environment.SANDBOX : apple.Environment.PRODUCTION;

  const rootsJson = JSON.parse(APPLE_ROOT_CERTS_B64_JSON.value()) as string[];
  const roots = rootsJson.map(value => Buffer.from(value, "base64"));
  const appAppleId = Number(APPLE_APP_ID.value()) || undefined;

  return new apple.SignedDataVerifier(
    roots,
    true,
    environment,
    APPLE_BUNDLE_ID.value(),
    appAppleId
  );
}

export const appleStoreNotifications = onRequest(
  {
    secrets: [APPLE_IAP_PRIVATE_KEY, APPLE_ROOT_CERTS_B64_JSON],
    timeoutSeconds: 60,
    memory: "512MiB"
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const signedPayload = req.body?.signedPayload;
    if (typeof signedPayload !== "string" || signedPayload.length === 0) {
      res.status(400).send("Missing signedPayload");
      return;
    }

    try {
      // Production and sandbox notifications share this endpoint; the verifier is environment-bound.
      let verifier = await appleVerifier(false);
      let notification: any;
      try {
        notification = await verifier.verifyAndDecodeNotification(signedPayload);
      } catch {
        verifier = await appleVerifier(true);
        notification = await verifier.verifyAndDecodeNotification(signedPayload);
      }
      const signedTransaction = notification?.data?.signedTransactionInfo;

      if (!signedTransaction) {
        res.status(200).send("OK");
        return;
      }

      const transaction = await verifier.verifyAndDecodeTransaction(signedTransaction);
      const productId = String(transaction.productId ?? "");
      const transactionId = String(transaction.transactionId ?? "");
      const originalTransactionId = String(
        transaction.originalTransactionId ?? transactionId
      );

      if (!originalTransactionId) {
        res.status(200).send("OK");
        return;
      }

      const ledger = await db.collection("purchaseLedger")
        .where("storeOriginalId", "==", originalTransactionId)
        .limit(1)
        .get();

      if (ledger.empty) {
        res.status(200).send("OK");
        return;
      }

      const uid = String(ledger.docs[0].data().uid ?? "");
      if (!uid) {
        res.status(200).send("OK");
        return;
      }

      const expiresAt = transaction.expiresDate
        ? new Date(Number(transaction.expiresDate))
        : undefined;

      const active =
        !transaction.revocationDate &&
        (!expiresAt || expiresAt.getTime() > Date.now());

      await updatePremium({
        uid,
        productId,
        platform: "apple",
        active,
        expiresAt
      });

      if (transactionId) {
        await db.doc(`purchaseLedger/${ledgerId("apple", transactionId)}`).set({
          uid,
          platform: "apple",
          productId,
          storeOriginalId: originalTransactionId,
          expiresAt: expiresAt ? Timestamp.fromDate(expiresAt) : null,
          notificationType: notification?.notificationType ?? null,
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }

      res.status(200).send("OK");
    } catch (error) {
      console.error("Apple notification verification failed", error);
      res.status(400).send("Invalid signed payload");
    }
  }
);

export const googlePlayBillingEvents = onMessagePublished(
  {
    topic: "play-billing",
    timeoutSeconds: 60,
    memory: "512MiB"
  },
  async event => {
    const payload: any = event.data.message.json;
    const subscription = payload?.subscriptionNotification;
    if (!subscription?.purchaseToken) return;

    const purchaseToken = String(subscription.purchaseToken);
    const ledgerRef = db.doc(`purchaseLedger/${ledgerId("google", purchaseToken)}`);
    const ledger = await ledgerRef.get();

    if (!ledger.exists) return;

    const row = ledger.data() ?? {};
    const uid = String(row.uid ?? "");
    const packageName = String(payload.packageName ?? row.packageName ?? "");
    const fallbackProductId = String(row.productId ?? "");

    if (!uid || !packageName) return;

    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"]
    });
    const publisher = google.androidpublisher({ version: "v3", auth });

    const response = await publisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken
    });

    const lineItems = response.data.lineItems ?? [];
    const productId = String(lineItems[0]?.productId ?? fallbackProductId);
    const expiryMillis = lineItems
      .map(item => item.expiryTime ? Date.parse(item.expiryTime) : 0)
      .reduce((max, value) => Math.max(max, value), 0);

    const state = response.data.subscriptionState ?? "";
    const entitlementStates = new Set([
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_CANCELED",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
    ]);

    const active = entitlementStates.has(state) && expiryMillis > Date.now();
    const expiresAt = expiryMillis > 0 ? new Date(expiryMillis) : undefined;

    await updatePremium({
      uid,
      productId,
      platform: "google",
      active,
      expiresAt
    });

    await ledgerRef.set({
      productId,
      subscriptionState: state,
      expiresAt: expiresAt ? Timestamp.fromDate(expiresAt) : null,
      lastNotificationType: subscription.notificationType ?? null,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
  }
);
