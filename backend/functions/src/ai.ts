import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { fal } from "@fal-ai/client";
import { randomUUID } from "crypto";
import {
  FAL_IMAGE_MODEL,
  FAL_KEY,
  FAL_STT_MODEL,
  FAL_VIDEO_MODEL,
  OPENAI_API_KEY,
  OPENAI_EMBED_MODEL,
  OPENAI_TEXT_MODEL,
  OPENAI_TTS_MODEL,
  OPENAI_TTS_VOICE,
  FREE_MATERIALS_LIMIT
} from "./config.js";
import { asString, requireUid } from "./auth.js";
import {
  chunkText,
  cosineSimilarity,
  embedTexts,
  openAIResponse,
  parseJsonObject
} from "./openai.js";
import { consumeCredits, consumeStandardAiQuota, isPremium } from "./usage.js";

const db = getFirestore();
const bucket = getStorage().bucket();

function tutorPrompt(examId: string, packId: string, language: string): string {
  return [
    "You are an exam preparation tutor.",
    `Exam: ${examId}`,
    `Content pack: ${packId}`,
    `Coach language: ${language}`,
    "Be concise, pedagogical and exam-specific.",
    "Never invent official exam rules, dates, scoring rules, or eligibility requirements.",
    "If an official rule is uncertain, explicitly say it should be checked against the official exam authority.",
    "When solving a question, explain the smallest useful reasoning and end with one transfer tip."
  ].join("\n");
}

export const aiTutor = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 60, memory: "512MiB" },
  async request => {
    const uid = requireUid(request);
    await consumeStandardAiQuota(uid);

    const data = request.data as any;
    const message = asString(data.message, "message");
    const examId = asString(data.examId, "examId", 100);
    const packId = asString(data.contentPackId, "contentPackId", 150);
    const language = typeof data.language === "string" ? data.language : "en";

    const answer = await openAIResponse({
      apiKey: OPENAI_API_KEY.value(),
      model: OPENAI_TEXT_MODEL.value(),
      input: [
        {
          role: "developer",
          content: [{ type: "input_text", text: tutorPrompt(examId, packId, language) }]
        },
        {
          role: "user",
          content: [{ type: "input_text", text: message }]
        }
      ]
    });

    return { text: answer };
  }
);

export const solveQuestion = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 90, memory: "1GiB" },
  async request => {
    const uid = requireUid(request);
    await consumeStandardAiQuota(uid);

    const data = request.data as any;
    const examId = asString(data.examId, "examId", 100);
    const packId = asString(data.contentPackId, "contentPackId", 150);
    const language = typeof data.language === "string" ? data.language : "en";
    const image = typeof data.imageDataUrl === "string"
      ? data.imageDataUrl
      : (typeof data.imageUrl === "string" ? data.imageUrl : null);
    const extractedText = typeof data.extractedText === "string" ? data.extractedText : "";

    if (!image && !extractedText) {
      throw new HttpsError("invalid-argument", "imageDataUrl, imageUrl or extractedText is required.");
    }

    const content: any[] = [{
      type: "input_text",
      text: [
        tutorPrompt(examId, packId, language),
        "Solve the supplied question.",
        "Return a clear answer, explanation, topic, likely mistake pattern, and one similar mini-practice prompt."
      ].join("\n")
    }];

    if (extractedText) {
      content.push({ type: "input_text", text: `OCR text:\n${extractedText}` });
    }

    if (image) {
      content.push({ type: "input_image", image_url: image, detail: "high" });
    }

    const answer = await openAIResponse({
      apiKey: OPENAI_API_KEY.value(),
      model: OPENAI_TEXT_MODEL.value(),
      input: [{ role: "user", content }]
    });

    return { text: answer };
  }
);

export const generatePractice = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 90, memory: "1GiB" },
  async request => {
    const uid = requireUid(request);
    await consumeStandardAiQuota(uid);

    const data = request.data as any;
    const examId = asString(data.examId, "examId", 100);
    const packId = asString(data.contentPackId, "contentPackId", 150);
    const topic = asString(data.topic, "topic", 500);
    const count = Math.min(Math.max(Number(data.count ?? 5), 1), 20);
    const language = typeof data.language === "string" ? data.language : "en";

    const answer = await openAIResponse({
      apiKey: OPENAI_API_KEY.value(),
      model: OPENAI_TEXT_MODEL.value(),
      input: [
        {
          role: "developer",
          content: [{
            type: "input_text",
            text: [
              tutorPrompt(examId, packId, language),
              "Create exam-style questions, not generic trivia.",
              "Output VALID JSON ONLY using this exact shape:",
              '{"questions":[{"id":"string","topic":"string","prompt":"string","options":["a","b","c","d"],"correctIndex":0,"explanation":"string","difficulty":"easy|medium|hard"}]}'
            ].join("\n")
          }]
        },
        {
          role: "user",
          content: [{
            type: "input_text",
            text: `Topic: ${topic}\nQuestion count: ${count}`
          }]
        }
      ]
    });

    return parseJsonObject(answer);
  }
);

async function storageUrl(storagePath: string): Promise<string> {
  const [url] = await bucket.file(storagePath).getSignedUrl({
    action: "read",
    expires: Date.now() + 15 * 60 * 1000
  });
  return url;
}

async function extractText(args: {
  mimeType: string;
  storagePath?: string;
  extractedText?: string;
}): Promise<string> {
  if (args.extractedText?.trim()) return args.extractedText.trim();
  if (!args.storagePath) {
    throw new HttpsError("invalid-argument", "storagePath or extractedText is required.");
  }

  const url = await storageUrl(args.storagePath);

  if (args.mimeType.startsWith("audio/") || args.mimeType.startsWith("video/")) {
    fal.config({ credentials: FAL_KEY.value() });
    const result = await fal.subscribe(FAL_STT_MODEL.value(), {
      input: { audio_url: url },
      logs: false
    });
    const data: any = result.data;
    return String(data?.text ?? data?.transcript ?? "").trim();
  }

  return openAIResponse({
    apiKey: OPENAI_API_KEY.value(),
    model: OPENAI_TEXT_MODEL.value(),
    input: [{
      role: "user",
      content: [
        {
          type: "input_text",
          text: "Extract the study-relevant text from this file. Preserve headings, formulas, lists and definitions. Return extracted text only."
        },
        {
          type: "input_file",
          file_url: url,
          filename: args.storagePath.split("/").pop() ?? "material"
        }
      ]
    }]
  });
}

async function storeChunks(
  uid: string,
  materialId: string,
  chunks: string[],
  embeddings: number[][]
): Promise<void> {
  const materialRef = db.doc(`users/${uid}/materials/${materialId}`);
  for (let offset = 0; offset < chunks.length; offset += 400) {
    const batch = db.batch();
    const slice = chunks.slice(offset, offset + 400);
    slice.forEach((chunk, localIndex) => {
      const index = offset + localIndex;
      batch.set(
        materialRef.collection("chunks").doc(String(index).padStart(4, "0")),
        {
          text: chunk,
          embedding: embeddings[index] ?? [],
          index
        }
      );
    });
    await batch.commit();
  }
}

export const indexMaterial = onCall(
  { secrets: [OPENAI_API_KEY, FAL_KEY], timeoutSeconds: 540, memory: "1GiB" },
  async request => {
    const uid = requireUid(request);
    await consumeStandardAiQuota(uid);

    const data = request.data as any;
    const materialId = typeof data.materialId === "string" ? data.materialId : randomUUID();

    if (!(await isPremium(uid))) {
      const existingMaterial = await db.doc(`users/${uid}/materials/${materialId}`).get();
      if (!existingMaterial.exists) {
        const materialCount = await db.collection(`users/${uid}/materials`).count().get();
        const maxMaterials = Math.max(1, Number(FREE_MATERIALS_LIMIT.value()) || 3);
        if (materialCount.data().count >= maxMaterials) {
          throw new HttpsError(
            "resource-exhausted",
            "Free material limit reached.",
            { reason: "free_material_limit", max: maxMaterials }
          );
        }
      }
    }

    const title = typeof data.title === "string" ? data.title.slice(0, 200) : "Study material";
    const mimeType = typeof data.mimeType === "string" ? data.mimeType : "text/plain";
    const storagePath = typeof data.storagePath === "string" ? data.storagePath : undefined;
    const extractedText = typeof data.extractedText === "string" ? data.extractedText : undefined;

    if (storagePath && !storagePath.startsWith(`users/${uid}/materials/`)) {
      throw new HttpsError("permission-denied", "Invalid material path.");
    }

    const text = await extractText({ mimeType, storagePath, extractedText });
    if (!text.trim()) {
      throw new HttpsError("failed-precondition", "No text could be extracted.");
    }

    const chunks = chunkText(text).slice(0, 1600);
    const embeddings = await embedTexts({
      apiKey: OPENAI_API_KEY.value(),
      model: OPENAI_EMBED_MODEL.value(),
      input: chunks
    });

    const summary = await openAIResponse({
      apiKey: OPENAI_API_KEY.value(),
      model: OPENAI_TEXT_MODEL.value(),
      input: `Summarize these study notes in a compact, exam-useful way. Keep formulas and key facts.\n\n${text.slice(0, 40_000)}`
    });

    const materialRef = db.doc(`users/${uid}/materials/${materialId}`);
    await materialRef.set({
      title,
      mimeType,
      storagePath: storagePath ?? null,
      summary,
      chunkCount: chunks.length,
      indexedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    await storeChunks(uid, materialId, chunks, embeddings);

    return { materialId, summary, chunkCount: chunks.length };
  }
);

export const askMaterial = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 90, memory: "1GiB" },
  async request => {
    const uid = requireUid(request);
    await consumeStandardAiQuota(uid);

    const data = request.data as any;
    const materialId = asString(data.materialId, "materialId", 200);
    const question = asString(data.question, "question");
    const language = typeof data.language === "string" ? data.language : "en";
    const materialRef = db.doc(`users/${uid}/materials/${materialId}`);

    const material = await materialRef.get();
    if (!material.exists) throw new HttpsError("not-found", "Material not found.");

    const [queryEmbedding] = await embedTexts({
      apiKey: OPENAI_API_KEY.value(),
      model: OPENAI_EMBED_MODEL.value(),
      input: [question]
    });

    const chunkSnapshot = await materialRef.collection("chunks").limit(250).get();
    const ranked = chunkSnapshot.docs
      .map(doc => {
        const row = doc.data();
        const embedding = Array.isArray(row.embedding) ? row.embedding.map(Number) : [];
        return {
          text: String(row.text ?? ""),
          score: cosineSimilarity(queryEmbedding, embedding)
        };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, 6);

    const context = ranked
      .map((item, index) => `[Context ${index + 1}]\n${item.text}`)
      .join("\n\n");

    const answer = await openAIResponse({
      apiKey: OPENAI_API_KEY.value(),
      model: OPENAI_TEXT_MODEL.value(),
      input: [
        {
          role: "developer",
          content: [{
            type: "input_text",
            text: `Answer using ONLY the retrieved study context. Coach language: ${language}. If context is insufficient, say so.`
          }]
        },
        {
          role: "user",
          content: [{
            type: "input_text",
            text: `${context}\n\nQuestion: ${question}`
          }]
        }
      ]
    });

    return { text: answer, usedChunks: ranked.length };
  }
);

export const generateMaterialPractice = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 90, memory: "1GiB" },
  async request => {
    const uid = requireUid(request);
    await consumeStandardAiQuota(uid);

    const data = request.data as any;
    const materialId = asString(data.materialId, "materialId", 200);
    const count = Math.min(Math.max(Number(data.count ?? 5), 1), 20);
    const language = typeof data.language === "string" ? data.language : "en";
    const materialRef = db.doc(`users/${uid}/materials/${materialId}`);

    const material = await materialRef.get();
    if (!material.exists) {
      throw new HttpsError("not-found", "Material not found.");
    }

    const chunks = await materialRef.collection("chunks").orderBy("index").limit(16).get();
    const context = chunks.docs.map(doc => String(doc.data().text ?? "")).join("\n\n");

    if (!context.trim()) {
      throw new HttpsError("failed-precondition", "Material has no indexed content.");
    }

    const answer = await openAIResponse({
      apiKey: OPENAI_API_KEY.value(),
      model: OPENAI_TEXT_MODEL.value(),
      input: [
        {
          role: "developer",
          content: [{
            type: "input_text",
            text: [
              `Coach language: ${language}`,
              "Create study questions using ONLY the supplied material.",
              "Do not introduce facts that are not supported by the material.",
              "Output VALID JSON ONLY:",
              '{"questions":[{"id":"string","topic":"string","prompt":"string","options":["a","b","c","d"],"correctIndex":0,"explanation":"string","difficulty":"easy|medium|hard"}]}'
            ].join("\n")
          }]
        },
        {
          role: "user",
          content: [{
            type: "input_text",
            text: `Create ${count} questions from this material:\n\n${context.slice(0, 50_000)}`
          }]
        }
      ]
    });

    return parseJsonObject(answer);
  }
);

function findFirstAssetUrl(value: unknown): string | null {
  if (typeof value === "string" && /^https?:\/\//i.test(value)) return value;
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findFirstAssetUrl(item);
      if (found) return found;
    }
  } else if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    for (const key of ["url", "video", "image", "file", "images", "videos", "output"]) {
      if (key in record) {
        const found = findFirstAssetUrl(record[key]);
        if (found) return found;
      }
    }
    for (const child of Object.values(record)) {
      const found = findFirstAssetUrl(child);
      if (found) return found;
    }
  }
  return null;
}

export const mediaGenerate = onCall(
  { secrets: [FAL_KEY], timeoutSeconds: 60, memory: "512MiB" },
  async request => {
    const uid = requireUid(request);
    const data = request.data as any;
    const kind = asString(data.kind, "kind", 100);
    const prompt = asString(data.prompt, "prompt", 10_000);

    const model = kind === "video_explainer"
      ? FAL_VIDEO_MODEL.value()
      : kind === "image_explainer"
        ? FAL_IMAGE_MODEL.value()
        : null;

    if (!model) throw new HttpsError("invalid-argument", "Unsupported media kind.");

    const creditCost = kind === "video_explainer" ? 5 : 1;
    await consumeCredits(uid, creditCost);

    fal.config({ credentials: FAL_KEY.value() });
    const submitted = await fal.queue.submit(model, { input: { prompt } });

    await db.doc(`aiJobs/${submitted.request_id}`).set({
      uid,
      kind,
      model,
      creditCost,
      status: "submitted",
      createdAt: FieldValue.serverTimestamp()
    });

    return { requestId: submitted.request_id, creditCost };
  }
);

export const mediaStatus = onCall(
  { secrets: [FAL_KEY], timeoutSeconds: 60, memory: "512MiB" },
  async request => {
    const uid = requireUid(request);
    const data = request.data as any;
    const requestId = asString(data.requestId, "requestId", 200);
    const jobRef = db.doc(`aiJobs/${requestId}`);
    const job = await jobRef.get();

    if (!job.exists || job.data()?.uid !== uid) {
      throw new HttpsError("not-found", "Job not found.");
    }

    const model = String(job.data()?.model ?? "");
    fal.config({ credentials: FAL_KEY.value() });
    const status: any = await fal.queue.status(model, { requestId, logs: false });

    if (status.status === "COMPLETED") {
      const result: any = await fal.queue.result(model, { requestId });
      await jobRef.set({
        status: "completed",
        completedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      return {
        status: "completed",
        assetUrl: findFirstAssetUrl(result.data),
        data: result.data
      };
    }

    return { status: String(status.status ?? "unknown").toLowerCase() };
  }
);


export const transcribeAudio = onCall(
  { secrets: [FAL_KEY], timeoutSeconds: 180, memory: "1GiB" },
  async request => {
    const uid = requireUid(request);
    await consumeStandardAiQuota(uid);

    const data = request.data as any;
    const storagePath = asString(data.storagePath, "storagePath", 1_000);

    if (!storagePath.startsWith(`users/${uid}/voice/`)) {
      throw new HttpsError("permission-denied", "Invalid voice recording path.");
    }

    const url = await storageUrl(storagePath);

    fal.config({ credentials: FAL_KEY.value() });
    const result = await fal.subscribe(FAL_STT_MODEL.value(), {
      input: { audio_url: url },
      logs: false
    });

    const response: any = result.data;
    const text = String(response?.text ?? response?.transcript ?? "").trim();

    if (!text) {
      throw new HttpsError("failed-precondition", "No speech could be transcribed.");
    }

    return { text };
  }
);

export const synthesizeSpeech = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 120, memory: "1GiB" },
  async request => {
    const uid = requireUid(request);
    await consumeStandardAiQuota(uid);

    const data = request.data as any;
    const text = asString(data.text, "text", 4_096);

    const response = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY.value()}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: OPENAI_TTS_MODEL.value(),
        voice: OPENAI_TTS_VOICE.value(),
        input: text
      })
    });

    if (!response.ok) {
      throw new HttpsError("internal", "Speech generation failed.");
    }

    const bytes = Buffer.from(await response.arrayBuffer());
    const path = `users/${uid}/generated/speech/${randomUUID()}.mp3`;
    await bucket.file(path).save(bytes, {
      contentType: "audio/mpeg",
      resumable: false
    });

    return { storagePath: path };
  }
);
