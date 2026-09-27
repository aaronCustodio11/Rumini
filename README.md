# rumini

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Setup after clone

These files contain app credentials and are intentionally **not** in git. Restore them locally:

1. `lib/firebase_options.dart` — run `flutterfire configure`, or copy the file from another machine.
2. `android/app/google-services.json` — download from Firebase Console → Project settings → Your apps (Android app).
3. Then run `flutter pub get` and `flutter run`.

## Cloud Functions

```sh
cd functions
npm install
firebase functions:secrets:set GMAIL_APP_PASSWORD   # Gmail app password — never commit it
firebase deploy --only functions
```
