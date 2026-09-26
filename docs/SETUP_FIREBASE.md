# Firebase setup

The codebase compiles without Firebase project files.

## Android

Place:

`android/app/google-services.json`

When the file exists, Gradle automatically applies:
- Google Services plugin
- Crashlytics plugin

Configured SDKs:
- Analytics
- Crashlytics
- Remote Config
- Cloud Messaging
- Anonymous Auth
- Cloud Functions
- Cloud Storage
- Firestore

## iOS

Place:

`ios/Exam/GoogleService-Info.plist`

The app checks for the plist at runtime. If missing, Firebase services stay in safe no-op mode.

Configured SDKs:
- Analytics
- Crashlytics
- Remote Config
- Messaging
- Anonymous Auth
- Functions
- Storage
- Firestore

For production push notifications, enable Push Notifications + Background Modes / Remote notifications in the Apple target and upload your APNs key to Firebase.

## Remote Config seed keys

- onboarding_paywall_enabled
- voice_tutor_enabled
- scan_question_enabled
- image_explanations_enabled
- video_explanations_enabled
- free_ai_messages_per_day
- free_materials_limit
- default_daily_goal_minutes
- limited_offer_expiry_epoch_seconds

A limited offer timer is shown only when `limited_offer_expiry_epoch_seconds` contains a real server-controlled future timestamp.
