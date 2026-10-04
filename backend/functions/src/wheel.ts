import { randomInt } from "crypto";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { OFFERS_ENABLED } from "./config.js";
import { requireUid } from "./auth.js";
import { isPremium } from "./usage.js";

/**
 * Daily gift wheel. Honest by construction (like Belto's welcome wheel):
 *  - the server draws the prize and the app only animates to it;
 *  - every segment is granted exactly as labelled;
 *  - one spin per local day, no purchase required.
 */

const db = getFirestore();

export type PrizeId = "credits5" | "credits10" | "credits25" | "annual40";

const CREDITS: Partial<Record<PrizeId, number>> = { credits5: 5, credits10: 10, credits25: 25 };

/** Visual order of the 8 segments, clockwise from 12 o'clock; the apps draw the same order. */
export const WHEEL_SEGMENTS: readonly PrizeId[] = [
  "credits10", "annual40", "credits5", "credits25", "annual40", "credits5", "credits10", "annual40"
];

function weights(premium: boolean): Record<PrizeId, number> {
  // Subscribers cannot use a subscription discount, so that share goes to credits.
  return premium || OFFERS_ENABLED.value() !== "true"
    ? { credits5: 40, credits10: 45, credits25: 15, annual40: 0 }
    : { credits5: 30, credits10: 30, credits25: 10, annual40: 30 };
}

function draw(premium: boolean): PrizeId {
  const table = weights(premium);
  const ids = Object.keys(table) as PrizeId[];
  const total = ids.reduce((sum, id) => sum + table[id], 0);
  let roll = randomInt(total);
  for (const id of ids) {
    roll -= table[id];
    if (roll < 0) return id;
  }
  return "credits5";
}

export const spinGiftWheel = onCall({ invoker: "public", timeoutSeconds: 20 }, async request => {
  const uid = requireUid(request);
  const localDay = String((request.data as any)?.localDay ?? "");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(localDay) || Math.abs(Date.parse(localDay) - Date.now()) > 2 * 86_400_000) {
    throw new HttpsError("invalid-argument", "localDay must be today's date (YYYY-MM-DD).");
  }

  const premium = await isPremium(uid);
  const prize = draw(premium);
  const candidates = WHEEL_SEGMENTS.flatMap((id, index) => (id === prize ? [index] : []));
  const segment = candidates[randomInt(candidates.length)];
  const userRef = db.doc(`users/${uid}`);
  const stateRef = db.doc(`users/${uid}/wheel/state`);

  const expiresAt = Date.now() + 24 * 3_600_000;
  await db.runTransaction(async tx => {
    const state = await tx.get(stateRef);
    if (state.data()?.lastSpinDay === localDay) {
      throw new HttpsError("already-exists", "Already spun today.", { reason: "already_spun" });
    }
    tx.set(stateRef, { lastSpinDay: localDay, lastPrize: prize, spunAt: FieldValue.serverTimestamp() }, { merge: true });
    const credits = CREDITS[prize];
    if (credits) {
      tx.set(userRef, { credits: FieldValue.increment(credits), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    } else {
      tx.set(db.doc(`users/${uid}/offers/wheel_${localDay}`), {
        kind: "wheel",
        issuedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(expiresAt),
        discountPercent: 40
      });
    }
  });

  return {
    prize,
    segment,
    credits: CREDITS[prize] ?? 0,
    offerExpiresAt: CREDITS[prize] ? null : expiresAt
  };
});

/** Whether this user already spun on the given local day (used by the reminder job). */
export async function spunOn(uid: string, localDay: string): Promise<boolean> {
  return (await db.doc(`users/${uid}/wheel/state`).get()).data()?.lastSpinDay === localDay;
}
