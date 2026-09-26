import { createHash } from "crypto";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging, Message } from "firebase-admin/messaging";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { REMINDER_IMAGE_URL } from "./config.js";
import { asString, requireUid } from "./auth.js";

const db = getFirestore();

const copy: Record<string, { title: string; body: string }> = {
  en: { title: "Your study plan is ready", body: "A short session today keeps your progress moving." },
  tr: { title: "Bugünkü çalışma planın hazır", body: "Kısa bir çalışma bile ilerlemeni sürdürür." },
  de: { title: "Dein Lernplan ist bereit", body: "Eine kurze Einheit hält deinen Fortschritt auf Kurs." },
  es: { title: "Tu plan de estudio está listo", body: "Una sesión corta mantiene tu progreso." },
  fr: { title: "Ton plan d’étude est prêt", body: "Une courte session suffit pour continuer à progresser." },
  pt: { title: "Seu plano de estudo está pronto", body: "Uma sessão curta mantém seu progresso." },
  ko: { title: "오늘의 학습 계획이 준비됐어요", body: "짧게라도 공부하면 흐름을 이어갈 수 있어요." },
  ja: { title: "今日の学習プランができました", body: "短い学習でも進歩を続けられます。" },
  hi: { title: "आज का स्टडी प्लान तैयार है", body: "एक छोटा सत्र भी आपकी प्रगति बनाए रखता है।" }
};

function tokenId(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export const registerPushToken = onCall(async request => {
  const uid = requireUid(request);
  const data = request.data as any;
  const token = asString(data.token, "token", 8_000);
  const platform = asString(data.platform, "platform", 30);
  const language = typeof data.language === "string" ? data.language.slice(0, 20) : "en";
  const timeZone = typeof data.timeZone === "string" ? data.timeZone.slice(0, 100) : "UTC";
  const reminderBucket = Math.max(0, Math.min(95, Number(data.reminderBucket ?? 76)));
  const examId = typeof data.examId === "string" ? data.examId.slice(0, 100) : null;
  const examName = typeof data.examName === "string" ? data.examName.slice(0, 100) : null;

  await db.doc(`pushTokens/${tokenId(token)}`).set({
    uid,
    token,
    platform,
    language,
    timeZone,
    reminderBucket,
    examId,
    examName,
    enabled: true,
    updatedAt: FieldValue.serverTimestamp()
  }, { merge: true });

  return { registered: true };
});

function currentUtcQuarter(): number {
  const now = new Date();
  return now.getUTCHours() * 4 + Math.floor(now.getUTCMinutes() / 15);
}

function messageFor(doc: FirebaseFirestore.QueryDocumentSnapshot): Message {
  const data = doc.data();
  const lang = String(data.language ?? "en").split("-")[0].toLowerCase();
  const localized = copy[lang] ?? copy.en;
  const examName = typeof data.examName === "string" && data.examName
    ? ` · ${data.examName}`
    : "";
  const imageUrl = REMINDER_IMAGE_URL.value().trim();

  return {
    token: String(data.token),
    notification: {
      title: localized.title + examName,
      body: localized.body,
      ...(imageUrl ? { imageUrl } : {})
    },
    data: {
      type: "daily_study_reminder",
      title: localized.title + examName,
      body: localized.body,
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
    let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;

    while (true) {
      let query = db.collection("pushTokens")
        .where("reminderBucket", "==", bucket)
        .orderBy(FieldValue.documentId())
        .limit(500);

      if (last) query = query.startAfter(last);

      const snapshot = await query.get();
      if (snapshot.empty) return;

      const docs = snapshot.docs.filter(doc => doc.data().enabled !== false);
      const messages = docs.map(messageFor);

      if (messages.length > 0) {
        const response = await getMessaging().sendEach(messages);

        const deletes: Promise<FirebaseFirestore.WriteResult>[] = [];
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
