# Backend setup

The backend is Firebase Functions + Firestore + Storage.

Provider API keys never ship in Android or iOS.

## Secret Manager

Configure:

- OPENAI_API_KEY
- FAL_KEY
- APPLE_IAP_PRIVATE_KEY
- APPLE_ROOT_CERTS_B64_JSON

`APPLE_ROOT_CERTS_B64_JSON` is a JSON array of base64-encoded Apple root certificate bytes for App Store signed-data verification.

## Non-secret function parameters

See `backend/functions/.env.example`.

## Google Play

Cloud Functions uses Application Default Credentials for the Android Publisher API. Give the Functions service account Play Console / Android Publisher access.

## Callable functions

- aiTutor
- solveQuestion
- generatePractice
- indexMaterial
- askMaterial
- mediaGenerate
- mediaStatus
- synthesizeSpeech
- verifyStorePurchase

All require Firebase Auth. Mobile signs in anonymously when Firebase is configured.

## Material RAG

1. App uploads material under `users/{uid}/materials/`.
2. Backend extracts text or transcribes audio/video.
3. Text is chunked.
4. Embeddings are generated.
5. Vectors/chunks are server-only Firestore data.
6. Questions embed the user query and retrieve the most relevant chunks.
7. Tutor answers only from those chunks.

## Cost control

Standard AI calls use a server-side daily free quota unless Premium is active.

Image/video generation spends server-side credits before a FAL job is submitted.

## Purchases

The mobile app does not grant entitlement by itself.

Google Play purchases are checked against Android Publisher API.

Apple transactions are checked using App Store Server API + signed-data verification.

Only the backend writes Premium entitlement / credit balance.
