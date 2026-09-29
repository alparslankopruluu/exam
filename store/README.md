# Store assets

Everything here is generated from the app and scripts in this folder.

## Listings (App Store + Google Play, 20 languages)

```bash
python3 store/listing.py
```

Writes `store/ios/metadata/<locale>/` and `store/android/metadata/android/<locale>/` (fastlane layout) and fails if a field exceeds its store limit.

## Screenshots

1. Build the Debug apps (iOS simulator build into `ios/build`, Android `assembleDebug`) and install the Android APK on a running emulator.
2. Capture raw screens in every language using the debug-only screenshot mode:

   ```bash
   store/capture_ios.sh        # "Examly Shots" simulator, 6.9" (1320x2868)
   store/capture_android.sh    # the connected emulator
   ```

   Pass languages to capture a subset (`store/capture_ios.sh tr de`), or `SCREENS="practice"` for specific screens. Blank frames are retried automatically.
3. Frame them with localized headlines:

   ```bash
   python3 store/frame.py
   ```

   Output: `store/ios/screenshots/<locale>/` (1320x2868) and `.../images/phoneScreenshots/` (1080x1920). Screenshots are git-ignored; regenerate them before uploading.

## Legal pages

Fill `store/legal/operator.json`, then `python3 store/legal/build.py` writes the privacy, terms and support pages to `backend/hosting/`; publish with `cd backend && firebase deploy --only hosting`.
