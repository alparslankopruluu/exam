import { createHash } from "crypto";
import { FieldPath, FieldValue, getFirestore, QueryDocumentSnapshot, Timestamp, WriteResult } from "firebase-admin/firestore";
import { getMessaging, Message } from "firebase-admin/messaging";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { REMINDER_IMAGE_URL } from "./config.js";
import { asString, requireUid } from "./auth.js";
import { REMINDER_ROUTE, ReminderKind, reminderText } from "./pushCopy.js";

const db = getFirestore();

function tokenId(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export const registerPushToken = onCall({ invoker: "public" }, async request => {
  const uid = requireUid(request);
  const data = request.data as any;
  const token = asString(data.token, "token", 8_000);
  const platform = asString(data.platform, "platform", 30);
  const language = typeof data.language === "string" ? data.language.slice(0, 20) : "en";
  const timeZone = typeof data.timeZone === "string" ? data.timeZone.slice(0, 100) : "UTC";
  const reminderBucket = Math.max(0, Math.min(95, Number(data.reminderBucket ?? 76)));

  // Only overwrite optional fields that were sent, so a bare token refresh
  // does not erase the exam or study state recorded by an earlier call.
  const optional: Record<string, unknown> = {};
  if (typeof data.examId === "string") optional.examId = data.examId.slice(0, 100);
  if (typeof data.examName === "string") optional.examName = data.examName.slice(0, 100);
  if (typeof data.streak === "number") optional.streak = Math.max(0, Math.floor(data.streak));
  if (typeof data.dueReviews === "number") optional.dueReviews = Math.max(0, Math.floor(data.dueReviews));
  if (typeof data.lastStudyDay === "string" && /^\d{4}-\d{2}-\d{2}$/.test(data.lastStudyDay)) {
    optional.lastStudyDay = data.lastStudyDay;
  }

  await db.doc(`pushTokens/${tokenId(token)}`).set({
    uid,
    token,
    platform,
    language,
    timeZone,
    reminderBucket,
    ...optional,
    enabled: true,
    updatedAt: FieldValue.serverTimestamp()
  }, { merge: true });

  return { registered: true };
});

function currentUtcQuarter(): number {
  const now = new Date();
  return now.getUTCHours() * 4 + Math.floor(now.getUTCMinutes() / 15);
}

const COMEBACK_DAYS = new Set([3, 7, 14, 30]);

function localDay(timeZone: string, date = new Date()): string {
  try {
    return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(date);
  } catch {
    return date.toISOString().slice(0, 10);
  }
}

function daysBetween(fromDay: string, toDay: string): number {
  return Math.round((Date.parse(toDay) - Date.parse(fromDay)) / 86_400_000);
}

async function expiringOffer(uid: string): Promise<{ id: string; percent: number } | null> {
  const now = Date.now();
  const offers = await db.collection(`users/${uid}/offers`).get();
  for (const doc of offers.docs) {
    const data = doc.data();
    const expiresAt = (data.expiresAt as Timestamp | undefined)?.toMillis() ?? 0;
    if (expiresAt > now && expiresAt - now <= 24 * 3_600_000 && !data.reminderSentAt) {
      const percent = Number(data.discountPercent ?? 0);
      if (!percent) continue;
      return { id: doc.id, percent };
    }
  }
  return null;
}

/**
 * Picks the most useful reminder for this device, or null to stay quiet.
 * Learners who already studied today are never nudged to study again.
 */
async function reminderFor(doc: QueryDocumentSnapshot): Promise<{ kind: ReminderKind; vars: Record<string, string>; offerId?: string } | null> {
  const data = doc.data();
  const today = localDay(String(data.timeZone ?? "UTC"));
  const lastStudyDay = typeof data.lastStudyDay === "string" ? data.lastStudyDay : null;
  const daysSince = lastStudyDay ? daysBetween(lastStudyDay, today) : null;
  const streak = Number(data.streak ?? 0);
  const dueReviews = Number(data.dueReviews ?? 0);
  const vars = {
    exam: typeof data.examName === "string" && data.examName ? data.examName : "Exam",
    streak: String(streak),
    count: String(dueReviews)
  };

  const offer = data.uid ? await expiringOffer(String(data.uid)) : null;
  if (offer) {
    return { kind: "offer_expiring", vars: { ...vars, count: String(offer.percent) }, offerId: offer.id };
  }

  if (daysSince === 0) return null;
  if (daysSince !== null && daysSince >= 3) {
    return COMEBACK_DAYS.has(daysSince) ? { kind: "comeback", vars } : null;
  }
  if (daysSince === 1 && streak >= 2) return { kind: "streak_at_risk", vars };
  if (dueReviews > 0) return { kind: "review_due", vars };
  return { kind: "daily", vars };
}

function buildMessage(token: string, kind: ReminderKind, title: string, body: string): Message {
  const imageUrl = REMINDER_IMAGE_URL.value().trim();
  const route = REMINDER_ROUTE[kind];

  return {
    token,
    notification: {
      title,
      body,
      ...(imageUrl ? { imageUrl } : {})
    },
    data: {
      type: kind,
      route,
      title,
      body,
      ...(imageUrl ? { imageUrl } : {})
    },
    android: {
      priority: "high",
      notification: {
        channelId: "study_updates",
        ...(imageUrl ? { imageUrl } : {})
      }
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          mutableContent: imageUrl ? true : false
        }
      },
      ...(imageUrl ? { fcmOptions: { imageUrl } } : {})
    }
  };
}

export const sendStudyReminders = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "UTC",
    timeoutSeconds: 120,
    memory: "512MiB"
  },
  async () => {
    const bucket = currentUtcQuarter();
    let last: QueryDocumentSnapshot | undefined;

    while (true) {
      let query = db.collection("pushTokens")
        .where("reminderBucket", "==", bucket)
        .orderBy(FieldPath.documentId())
        .limit(500);

      if (last) query = query.startAfter(last);

      const snapshot = await query.get();
      if (snapshot.empty) return;

      const candidates = snapshot.docs.filter(doc => doc.data().enabled !== false);
      const picks = await Promise.all(candidates.map(reminderFor));
      const docs: QueryDocumentSnapshot[] = [];
      const messages: Message[] = [];
      const offerMarks: Promise<WriteResult>[] = [];
      candidates.forEach((doc, index) => {
        const pick = picks[index];
        if (!pick) return;
        const data = doc.data();
        const text = reminderText(pick.kind, String(data.language ?? "en"), pick.vars);
        docs.push(doc);
        messages.push(buildMessage(String(data.token), pick.kind, text.title, text.body));
        if (pick.offerId) {
          offerMarks.push(db.doc(`users/${data.uid}/offers/${pick.offerId}`).set(
            { reminderSentAt: FieldValue.serverTimestamp() },
            { merge: true }
          ));
        }
      });
      await Promise.all(offerMarks);

      if (messages.length > 0) {
        const response = await getMessaging().sendEach(messages);

        const deletes: Promise<WriteResult>[] = [];
        response.responses.forEach((result, index) => {
          if (result.success) return;
          const code = result.error?.code ?? "";
          if (
            code.includes("registration-token-not-registered") ||
            code.includes("invalid-registration-token")
          ) {
            deletes.push(docs[index].ref.delete());
          }
        });
        await Promise.all(deletes);
      }

      last = snapshot.docs.at(-1);
      if (snapshot.size < 500 || !last) return;
    }
  }
);
