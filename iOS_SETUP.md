# Anot.Health — iOS bring-up (on a Mac)

This is the **Flutter** app (cross-platform). The iOS project lives in `ios/`.
Everything below runs on **macOS only** (Xcode + iOS Simulator are macOS-only).

> ⚠️ Do **not** use the old native Android app at `Anot Android App/` for iOS —
> that's Kotlin/Jetpack Compose and is Android-only. This Flutter project is the
> cross-platform one.

App bundle id: `com.anothealth.anot_scribe` · Display name: **Anot.Health**

---

## 1. Prerequisites (install on the Mac)
- **Xcode** (from the App Store) + command-line tools: `xcode-select --install`
- **CocoaPods**: `sudo gem install cocoapods`
- **Flutter SDK**: https://docs.flutter.dev/get-started/install/macos
- Verify: `flutter doctor` (all green for iOS)

## 2. Run on the iOS Simulator (fastest, no Apple account)
```bash
cd anot_scribe
flutter pub get
cd ios && pod install && cd ..
open -a Simulator          # boots an iOS Simulator
flutter run                # builds + installs on the simulator
```

## 3. Run on a real iPhone (needs signing)
```bash
open ios/Runner.xcworkspace   # open the WORKSPACE, not the .xcodeproj
```
In Xcode → select the **Runner** target → **Signing & Capabilities** →
- set your **Team** (a free Apple ID gives 7-day device installs; the $99/yr
  Apple Developer Program is needed for TestFlight / App Store).
- Xcode auto-manages the provisioning profile.
Then plug in the iPhone and `flutter run` (or press ▶ in Xcode).

## 4. Home-screen widget (WidgetKit) — manual one-time step
The Android widget is done; iOS needs a **Widget Extension target** added in Xcode:
1. Xcode → File → New → Target → **Widget Extension** (name e.g. `AnotWidget`).
2. Add it to an **App Group** `group.com.anothealth.anot_scribe` (Signing &
   Capabilities → + App Groups) on **both** the Runner and the widget target.
3. Use the SwiftUI in `ios/AnotWidget/AnotWidget.swift` (already scaffolded) +
   `home_widget`'s shared storage. See that file's README for the deep-link
   scheme `anotscribe://record?patientId=<id>`.

## 5. Capabilities already configured in this repo (verify they survive signing)
- `Info.plist`: `NSMicrophoneUsageDescription`, `NSFaceIDUsageDescription`,
  App Transport Security (no cleartext), **`UIBackgroundModes: audio`**.
- `SceneDelegate.swift`: privacy **blur overlay** when backgrounded (iOS has no
  `FLAG_SECURE`).
- Plugins pulling iOS pods: `record`, `flutter_foreground_task`, `just_audio`,
  `local_auth`, `flutter_secure_storage`, `sqflite_sqlcipher`, `connectivity_plus`,
  `path_provider`, `home_widget`, `wakelock_plus`, `encrypt`.

## 6. What the Simulator CAN vs CANNOT test
- ✅ UI, navigation, layout, most logic, login/vault flow.
- ❌ **Real microphone / recording**, **background audio**, **Face ID hardware**,
  push — these need a **real iPhone** (TestFlight or a wired device). Don't sign
  off the recording engine on the simulator alone.

## 7. Production build (no demo logins)
```bash
flutter build ipa --release --dart-define=DEMO_ACCOUNTS=false
```
(omitting the flag keeps the seeded demo accounts for testing).

## 8. Common fixes
- Pod errors: `cd ios && pod repo update && pod install`
- Stale build: `flutter clean && flutter pub get && (cd ios && pod install)`
- Min iOS: this project targets a modern iOS; bump `ios/Podfile` `platform :ios`
  if a pod requires a higher floor (the error will name it).
