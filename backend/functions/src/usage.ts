import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { FREE_AI_CALLS_PER_DAY } from "./config.js";

const db = getFirestore();

function utcDayKey(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, "");
}

export async function isPremium(uid: string): Promise<boolean> {
  const doc = await db.doc(`users/${uid}/entitlements/premium`).get();
  if (!doc.exists) return false;
  const data = doc.data() ?? {};
  if (data.active !== true) return false;
  const expiresAt = data.expiresAt?.toDate?.() as Date | undefined;
  return !expiresAt || expiresAt.getTime() > Date.now();
}

export async function consumeStandardAiQuota(uid: string): Promise<void> {
  if (await isPremium(uid)) return;

  const max = Math.max(1, Number(FREE_AI_CALLS_PER_DAY.value()) || 5);
  const ref = db.doc(`users/${uid}/usage/${utcDayKey()}`);

  await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    const current = Number(snapshot.data()?.aiCalls ?? 0);
    if (current >= max) {
      throw new HttpsError("resource-exhausted", "Daily AI limit reached.", {
        reason: "free_ai_limit",
        max
      });
    }
    tx.set(ref, {
      aiCalls: current + 1,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
  });
}

export async function consumeCredits(uid: string, amount: number): Promise<void> {
  const ref = db.doc(`users/${uid}`);

  await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    const credits = Number(snapshot.data()?.credits ?? 0);
    if (credits < amount) {
      // Remembered so the offer engine can send a credit bonus later.
      tx.set(ref, { creditShortfallAt: FieldValue.serverTimestamp() }, { merge: true });
      throw new HttpsError("resource-exhausted", "Not enough credits.", {
        reason: "credits",
        required: amount,
        available: credits
      });
    }
    tx.set(ref, {
      credits: credits - amount,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
  });
}
