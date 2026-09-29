# Libraries (Firebase, Play Billing, ML Kit, Compose, Glance) ship their own
# consumer rules; these cover what the app itself relies on at runtime.

# Glance instantiates ActionCallback implementations by class name.
-keep class * implements androidx.glance.appwidget.action.ActionCallback { <init>(); }

# Credential Manager loads the Play Services provider reflectively.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }

# Keep line numbers for readable Crashlytics stack traces.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Room (used by WorkManager, which Glance schedules through) instantiates the
# generated *_Impl database class reflectively via its no-arg constructor.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
