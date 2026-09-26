type ResponseInput = string | Array<Record<string, unknown>>;

export async function openAIResponse(args: {
  apiKey: string;
  model: string;
  input: ResponseInput;
}): Promise<string> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${args.apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ model: args.model, input: args.input })
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI Responses API failed: ${response.status} ${body}`);
  }

  const json = await response.json() as any;
  if (typeof json.output_text === "string" && json.output_text.length > 0) {
    return json.output_text;
  }

  const chunks: string[] = [];
  for (const item of json.output ?? []) {
    if (item?.type !== "message") continue;
    for (const content of item.content ?? []) {
      if (content?.type === "output_text" && typeof content.text === "string") {
        chunks.push(content.text);
      }
    }
  }
  return chunks.join("\n").trim();
}

export async function embedTexts(args: {
  apiKey: string;
  model: string;
  input: string[];
}): Promise<number[][]> {
  const response = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${args.apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ model: args.model, input: args.input })
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI embeddings failed: ${response.status} ${body}`);
  }

  const json = await response.json() as any;
  return (json.data ?? []).map((item: any) => item.embedding as number[]);
}

export function parseJsonObject(text: string): any {
  const cleaned = text.replace(/^\s*```(?:json)?/i, "").replace(/```\s*$/i, "").trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start >= 0 && end > start) return JSON.parse(cleaned.slice(start, end + 1));
    throw new Error("Model did not return valid JSON.");
  }
}

export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length || a.length === 0) return 0;
  let dot = 0;
  let aa = 0;
  let bb = 0;
  for (let i = 0; i < a.length; i += 1) {
    dot += a[i] * b[i];
    aa += a[i] * a[i];
    bb += b[i] * b[i];
  }
  if (aa === 0 || bb === 0) return 0;
  return dot / (Math.sqrt(aa) * Math.sqrt(bb));
}

export function chunkText(text: string, target = 1200, overlap = 150): string[] {
  const normalized = text.replace(/\r/g, "").trim();
  if (!normalized) return [];
  const chunks: string[] = [];
  let start = 0;
  while (start < normalized.length) {
    let end = Math.min(normalized.length, start + target);
    if (end < normalized.length) {
      const nextBreak = normalized.lastIndexOf("\n", end);
      if (nextBreak > start + Math.floor(target * 0.6)) end = nextBreak;
    }
    chunks.push(normalized.slice(start, end).trim());
    if (end >= normalized.length) break;
    start = Math.max(end - overlap, start + 1);
  }
  return chunks.filter(Boolean);
}
