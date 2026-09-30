# Release / external configuration checklist

Everything in this list is intentionally external to source code. The app should not require provider secrets to compile.

## 1. Firebase

Android:
- Add `android/app/google-services.json`.

iOS:
- Add `ios/Exam/GoogleService-Info.plist`.

Firebase console:
- Enable Anonymous Authentication.
- Create Firestore database.
- Create Storage bucket.
- Deploy `backend/firestore.rules`.
- Deploy `backend/storage.rules`.
- Deploy Functions from `backend/functions`.
- Configure Remote Config values from `docs/SETUP_FIREBASE.md`.
- Enable Cloud Messaging.

## 2. Backend AI secrets

Set with Firebase Secret Manager:
- `OPENAI_API_KEY`
- `FAL_KEY`
- `APPLE_IAP_PRIVATE_KEY`
- `APPLE_ROOT_CERTS_B64_JSON`

Configure non-secret parameters from `backend/functions/.env.example`.

No provider secret belongs in Android/iOS source, plist, BuildConfig, Info.plist or Remote Config.

## 3. Apple purchases

Create products with these exact IDs:
- `premium_annual`
- `premium_monthly`
- `ai_credits_small`

Then configure:
- App Store Connect subscription group;
- annual/monthly prices by storefront;
- optional introductory offer/trial for the annual product;
- App Store Server API key;
- Apple root certificates for signed-data verification;
- App Store Server Notifications V2 URL pointing to `appleStoreNotifications`;
- bundle ID `com.techtactoe.examly` or change it consistently in source/config before release.

The UI never hardcodes display price. StoreKit supplies the localized price and eligibility.

## 4. Google Play purchases

Create products with these exact IDs:
- subscription `premium_annual`
- subscription `premium_monthly`
- one-time product `ai_credits_small`

Then:
- enable Google Play Developer API access for the Functions service account;
- configure base plans/offers/trials in Play Console;
- create Pub/Sub topic `play-billing`;
- connect Google Play Real-time Developer Notifications to that topic;
- grant the runtime service account permission to consume the Pub/Sub subscription/event source used by Functions.

The UI never hardcodes display price.

## 5. Apple push

- Enable Push Notifications capability for the app identifier.
- Enable Background Modes / Remote notifications where required by the chosen signing setup.
- Upload APNs key/certificate to Firebase Cloud Messaging.
- Keep the Notification Service Extension enabled for rich-image notifications.

## 6. Google push

- Firebase Cloud Messaging configuration comes from `google-services.json`.
- Android 13+ notification permission is requested after onboarding value is shown, not immediately at cold launch.

## 7. Scheduled reminders

Deploy `sendStudyReminders`.

The app registers:
- FCM token;
- platform;
- selected exam;
- UI language;
- time zone;
- reminder-hour bucket.

Optional rich reminder image:
- set `REMINDER_IMAGE_URL`.

## 8. Remote Config

Seed keys:
- `onboarding_paywall_enabled`
- `voice_tutor_enabled`
- `scan_question_enabled`
- `image_explanations_enabled`
- `video_explanations_enabled`
- `free_ai_messages_per_day`
- `free_materials_limit`
- `default_daily_goal_minutes`
- `limited_offer_expiry_epoch_seconds`

The limited-offer countdown is rendered only when the server timestamp is genuinely in the future.

Recommended launch default:
- image explanations: enabled after FAL key is configured;
- video explanations: disabled until cost/latency is validated;
- limited offer expiry: 0 until a real campaign is scheduled.

## 9. Store metadata / legal URLs

Host:
- `docs/PRIVACY_POLICY.md`
- `docs/TERMS.md`

Before hosting, add:
- publisher/legal entity;
- support/privacy contact;
- jurisdiction-specific legal text if required.

Then add public HTTPS URLs to App Store Connect / Play Console.

## 10. Final production validation

Before submission:
- Android CI green.
- iOS CI green.
- Backend TypeScript CI green.
- Test anonymous sign-in.
- Test one fresh and one returning onboarding path.
- Test annual/monthly purchase, restore, cancellation/renewal webhook and consumable credit purchase.
- Test AI daily quota -> contextual paywall.
- Test free-material limit -> contextual paywall.
- Test question photo OCR + vision.
- Test Library PDF, image, audio and video import.
- Test material Q&A and material quiz.
- Test Voice Tutor microphone -> STT -> tutor -> TTS.
- Test image generation and, only if enabled, video generation.
- Test rich push on a real iPhone and real Android device.
- Test account deletion and verify cloud records/storage are gone.
- Test all 9 supported UI languages for clipping and RTL-like long-copy pressure even though current languages are LTR/CJK/Devanagari.
- Verify current official exam blueprint data before promoting a baseline content pack to fully verified status.
