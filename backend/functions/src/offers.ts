import { randomUUID } from "crypto";
import { onCall } from "firebase-functions/v2/https";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { APPLE_BUNDLE_ID, APPLE_IAP_PRIVATE_KEY, APPLE_KEY_ID, OFFERS_ENABLED } from "./config.js";
import { asString, requireUid } from "./auth.js";

const db = getFirestore();
const HOUR = 60 * 60 * 1000;

/** One-off kinds use their name as the document id; recurring kinds get a unique id and a `kind` field. */
export type OfferKind = "welcome" | "exam_sprint" | "winback" | "flash" | "wheel" | "credit_boost";

type OfferRule = {
  discountPercent: number;
  durationMs: number;
  // Apple: which product to buy and, for lapsed subscribers, the promotional offer id.
  appleProductId: string;
  applePromotionalOfferId?: string;
  // Google: base-plan offer tag on premium_annual.
  googleOfferTag: string;
};

// Discounts must match what is configured in App Store Connect / Play Console.
const RULES: Record<OfferKind, OfferRule> = {
  welcome: {
    discountPercent: 40,
    durationMs: 48 * HOUR,
    appleProductId: "premium_annual_offer",
    googleOfferTag: "welcome"
  },
  exam_sprint: {
    discountPercent: 40,
    durationMs: 72 * HOUR,
    appleProductId: "premium_annual_offer",
    googleOfferTag: "welcome"
  },
  winback: {
    discountPercent: 50,
    durationMs: 7 * 24 * HOUR,
    appleProductId: "premium_annual",
    applePromotionalOfferId: "winback_annual_50",
    googleOfferTag: "winback"
  },
  // Weekly flash sale on the discounted annual product.
  flash: {
    discountPercent: 40,
    durationMs: 24 * HOUR,
    appleProductId: "premium_annual_offer",
    googleOfferTag: "welcome"
  },
  // Won on the daily gift wheel.
  wheel: {
    discountPercent: 40,
    durationMs: 24 * HOUR,
    appleProductId: "premium_annual_offer",
    googleOfferTag: "welcome"
  },
  // Bonus credits on any credit pack; discountPercent is the bonus share.
  credit_boost: {
    discountPercent: 50,
    durationMs: 48 * HOUR,
    appleProductId: "ai_credits_medium",
    googleOfferTag: ""
  }
};

/** Recurring offers are capped so they stay special: at most two a week, two days apart. */
const WEEKLY_CAP = 2;
const MIN_GAP_MS = 48 * HOUR;
const RECURRING: ReadonlySet<OfferKind> = new Set(["flash", "credit_boost"]);

type IssuedOffer = { id: string; kind: OfferKind; issuedAt: number; expiresAt: number; redeemed: boolean };

async function issuedOffers(uid: string): Promise<IssuedOffer[]> {
  const snapshot = await db.collection(`users/${uid}/offers`).get();
  return snapshot.docs.map(doc => {
    const data = doc.data();
    const expiresAt = (data.expiresAt as Timestamp | undefined)?.toMillis() ?? 0;
    const issuedAt = (data.issuedAt as Timestamp | undefined)?.toMillis() ?? expiresAt;
    return { id: doc.id, kind: (data.kind ?? doc.id) as OfferKind, issuedAt, expiresAt, redeemed: data.redeemed === true };
  });
}

/**
 * Issues this week's recurring offer when the user qualifies, else returns null.
 * Credit boosts go to learners who recently ran out of credits; flash sales to
 * learners who never subscribed and are past their welcome window.
 */
export async function issueWeeklyOffer(uid: string): Promise<{ id: string; kind: OfferKind; percent: number } | null> {
  if (OFFERS_ENABLED.value() !== "true") return null;
  const now = Date.now();
  const [user, issued, state] = await Promise.all([db.doc(`users/${uid}`).get(), issuedOffers(uid), subscriptionState(uid)]);
  const recurring = issued.filter(offer => RECURRING.has(offer.kind));
  if (recurring.some(offer => offer.expiresAt > now)) return null;
  if (recurring.filter(offer => now - offer.issuedAt < 7 * 24 * HOUR).length >= WEEKLY_CAP) return null;
  if (recurring.some(offer => now - offer.issuedAt < MIN_GAP_MS)) return null;

  const data = user.data() ?? {};
  const shortfallAt = (data.creditShortfallAt as Timestamp | undefined)?.toMillis() ?? 0;
  const firstSeenMs = (data.firstSeenAt as Timestamp | undefined)?.toMillis() ?? now;
  let kind: OfferKind | null = null;
  if (now - shortfallAt < 14 * 24 * HOUR && Number(data.credits ?? 0) < 10) {
    kind = "credit_boost";
  } else if (state === "never" && now - firstSeenMs > WELCOME_WINDOW_MS) {
    kind = "flash";
  }
  if (!kind) return null;

  const id = `${kind}_${now}`;
  await db.doc(`users/${uid}/offers/${id}`).set({
    kind,
    issuedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(now + RULES[kind].durationMs),
    discountPercent: RULES[kind].discountPercent
  });
  return { id, kind, percent: RULES[kind].discountPercent };
}

/** The live credit bonus, if any; used by the client store and by purchase grants. */
export async function activeCreditBoost(uid: string): Promise<IssuedOffer | null> {
  const now = Date.now();
  return (await issuedOffers(uid)).find(offer => offer.kind === "credit_boost" && offer.expiresAt > now && !offer.redeemed) ?? null;
}

const WELCOME_WINDOW_MS = 72 * HOUR;
const EXAM_SPRINT_DAYS = 45;

type SubscriptionState = "active" | "lapsed" | "never";

async function subscriptionState(uid: string): Promise<SubscriptionState> {
  const snapshot = await db.doc(`users/${uid}/entitlements/premium`).get();
  if (!snapshot.exists) return "never";
  const data = snapshot.data() ?? {};
  const expiresAt = (data.expiresAt as Timestamp | null)?.toMillis();
  const active = data.active === true && (!expiresAt || expiresAt > Date.now());
  return active ? "active" : "lapsed";
}

function chooseKind(
  state: SubscriptionState,
  firstSeenMs: number,
  daysToExam: number | null,
  alreadyIssued: Set<string>
): OfferKind | null {
  if (state === "active") return null;
  if (state === "lapsed") {
    return alreadyIssued.has("winback") ? null : "winback";
  }
  if (daysToExam !== null && daysToExam >= 0 && daysToExam <= EXAM_SPRINT_DAYS && !alreadyIssued.has("exam_sprint")) {
    return "exam_sprint";
  }
  if (Date.now() - firstSeenMs <= WELCOME_WINDOW_MS && !alreadyIssued.has("welcome")) {
    return "welcome";
  }
  return null;
}

async function applePromotionalSignature(productId: string, offerId: string) {
  const apple: any = await import("@apple/app-store-server-library");
  const nonce = randomUUID().toLowerCase();
  const timestamp = Date.now();
  const creator = new apple.PromotionalOfferSignatureCreator(
    APPLE_IAP_PRIVATE_KEY.value(),
    APPLE_KEY_ID.value(),
    APPLE_BUNDLE_ID.value()
  );
  // appAccountToken is empty because purchases do not set one.
  const signature = creator.createSignature(productId, offerId, "", nonce, timestamp);
  return { offerId, keyId: APPLE_KEY_ID.value(), nonce, timestamp, signature };
}

/**
 * Returns the single offer this user may see right now, or null.
 * Offers are issued once per kind with a fixed server expiry, so a countdown
 * shown in the app is real and never resets.
 */
export const getActiveOffer = onCall(
  { invoker: "public", secrets: [APPLE_IAP_PRIVATE_KEY], timeoutSeconds: 20 },
  async request => {
    const uid = requireUid(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const platform = asString(data.platform, "platform", 20);
    const daysToExam = typeof data.daysToExam === "number" ? Math.floor(data.daysToExam) : null;

    if (OFFERS_ENABLED.value() !== "true") return { offer: null };

    const userRef = db.doc(`users/${uid}`);
    const offersRef = userRef.collection("offers");
    await issueWeeklyOffer(uid);
    const [user, issued, state] = await Promise.all([userRef.get(), offersRef.get(), subscriptionState(uid)]);

    const boost = await activeCreditBoost(uid);
    const creditBoost = boost ? { bonusPercent: RULES.credit_boost.discountPercent, expiresAt: boost.expiresAt } : null;
    if (state === "active") return { offer: null, creditBoost };

    const now = Date.now();
    const firstSeenMs = (user.data()?.firstSeenAt as Timestamp | undefined)?.toMillis() ?? now;
    if (!user.data()?.firstSeenAt) {
      await userRef.set({ firstSeenAt: FieldValue.serverTimestamp() }, { merge: true });
    }

    // Keep showing a still-running offer instead of issuing a new one.
    // Subscription offers only; the credit bonus travels separately.
    let current = issued.docs
      .map(doc => ({ kind: (doc.data().kind ?? doc.id) as OfferKind, expiresAt: (doc.data().expiresAt as Timestamp).toMillis() }))
      .filter(offer => offer.kind !== "credit_boost")
      .sort((a, b) => b.expiresAt - a.expiresAt)
      .find(offer => offer.expiresAt > now && RULES[offer.kind] && (offer.kind === "winback") === (state === "lapsed"));

    if (!current) {
      const kind = chooseKind(state, firstSeenMs, daysToExam, new Set(issued.docs.map(doc => doc.id)));
      if (!kind) return { offer: null, creditBoost };
      const expiresAt = now + RULES[kind].durationMs;
      await offersRef.doc(kind).set({
        issuedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(expiresAt),
        discountPercent: RULES[kind].discountPercent
      });
      current = { kind, expiresAt };
    }

    const rule = RULES[current.kind];
    const offer: Record<string, unknown> = {
      kind: current.kind,
      discountPercent: rule.discountPercent,
      expiresAt: current.expiresAt
    };

    if (platform === "apple") {
      offer.productId = rule.appleProductId;
      if (rule.applePromotionalOfferId) {
        try {
          offer.applePromotionalOffer = await applePromotionalSignature(rule.appleProductId, rule.applePromotionalOfferId);
        } catch (error) {
          console.error("Promotional offer signing failed", error);
          return { offer: null };
        }
      }
    } else {
      offer.productId = "premium_annual";
      offer.googleOfferTag = rule.googleOfferTag;
    }

    return { offer, creditBoost };
  }
);
