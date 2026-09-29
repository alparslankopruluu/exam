# Examly Privacy Policy

_Last updated: 2026-09-29_

Examly is a study and exam-preparation application operated by {OPERATOR_NAME} ("we"). This policy describes the data the app processes and why.

## Data the app processes

The app may process:
- account and anonymous authentication identifiers, and — if you choose to save your progress — the email address and sign-in provider (Sign in with Apple, Google or email and password);
- selected country, exam, optional exam date, app language, study goal and daily study preference;
- learning activity such as answers, mastery, mistakes, sessions, streak and XP;
- files the user intentionally uploads, including PDFs, images, text, audio and video;
- questions and prompts sent to AI tutoring features;
- purchase entitlement and credit state;
- push-notification token, language, time zone, exam context, reminder preference and study state used to choose reminders (current streak, last study day and number of topics due for review);
- offer eligibility records (which offer was shown to you and when it expires);
- diagnostic, product and reliability analytics events;
- crash diagnostics.

## Study files and AI

Uploaded study materials are stored under the authenticated user's account. Material text may be extracted or transcribed, chunked and indexed so the user can search it, ask questions from it and create practice.

AI requests are sent through the application's server-side gateway. Provider API credentials are not shipped in the mobile applications. Depending on the feature, the gateway may send the user's prompt, selected question image, extracted study text, audio or generated-media prompt to configured AI providers for processing.

Generated image/video features use credits because they have higher external processing cost.

## Analytics and crash reporting

The app is designed to send product events and technical diagnostics, not raw study notes, uploaded file contents or voice transcripts, to analytics.

Firebase Analytics may be used for product events. Firebase Crashlytics may be used for crash and non-fatal diagnostics after Firebase is configured.

## Purchases

Subscription and consumable purchases are processed by Apple App Store or Google Play. The server verifies store transactions before granting Premium or credits. The app does not store full payment-card information.

## Notifications

If the user grants permission, the app may send study reminders, streak/progress reminders and relevant product messages. Notification tokens and reminder settings are associated with the authenticated account. Users can disable notifications through device settings and change the study reminder preference in the app.

## Sign-in

You can use Examly without an account; an anonymous identifier keeps your data together. If you choose Sign in with Apple, Google or email, that identity is linked to the same account so your progress is kept across devices. With Sign in with Apple you may hide your email address. We receive only the name and email the provider shares.

## Home-screen widgets

Widgets show your streak, today's plan and a question of the day. Their data is prepared by the app and stays on your device.

## Retention and deletion

The app includes an in-app Delete Account action. When used, the backend is designed to delete the authenticated account, user Firestore subtree, user Storage files, registered push tokens and user-owned AI jobs. Store transaction records may be subject to legal/accounting retention requirements in production and should be handled according to the operator's applicable obligations.

## Children and education use

The product must be published with an age rating and data practices appropriate to the actual target audience. If the operator intentionally offers the service to children in a jurisdiction with parental-consent requirements, additional consent and compliance work may be required before launch.

## Security

Provider keys and purchase verification credentials are server-side. Firestore and Storage rules scope user-accessible study data to the authenticated user, while entitlement, usage and purchase-ledger writes are server controlled.

## Changes

This policy should be updated whenever the application's providers, data uses, retention rules or target audience materially change.

## Contact

{OPERATOR_NAME} — privacy questions and deletion requests: {CONTACT_EMAIL}
