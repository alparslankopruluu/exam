import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

export function requireUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return uid;
}

export function asString(value: unknown, field: string, maxLength = 20_000): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  if (value.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} is too long.`);
  }
  return value;
}
