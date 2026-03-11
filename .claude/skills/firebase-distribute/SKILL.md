---
name: firebase-distribute
description: "Firebase App Distribution for Android builds. Use whenever deploying, uploading, or distributing an Android APK to Firebase for testing. Covers build, upload, and tester configuration."
---

# Firebase App Distribution (Android)

Upload a new Android build to Firebase App Distribution.

## Single-step build + upload

```bash
cd "$(git rev-parse --show-toplevel)"

# JDK 17 configured globally via `flutter config --jdk-dir` — no JAVA_HOME export needed
flutter build apk --release

firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --project boardcastsurf \
  --app 1:169704801434:android:d4d49f1361609bc87b8b23 \
  --release-notes "Description of changes"
```

## Notes
- `--project boardcastsurf` is required (no .firebaserc in this repo)
- APK is ~64MB (release build with tree-shaking)
- JDK 17 at `/opt/homebrew/opt/openjdk@17` configured via `flutter config --jdk-dir`
- No Firebase SDK or `google-services.json` needed in the app — Firebase is just the distribution channel
- Android minSdk is 26 (Android 8.0)
- To add testers: `firebase appdistribution:testers:add --emails "email@example.com" --project boardcastsurf`
