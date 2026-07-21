# DOCVA — iOS bring-up & TestFlight

This is the **Flutter** app (cross-platform). The iOS project lives in `ios/`.
All the app logic and the whole **Sharp Tech** UI (theme, Manrope font, DOCVA
logo, status palette) live in shared Dart under `lib/`, so an iOS build picks
up everything automatically — there is **no iOS-specific UI work to redo**.

- Bundle id: `health.docva.app` · Display name: **DOCVA**
- iOS export compliance, mic / Face ID / background-audio, and App Transport
  Security are already declared in `ios/Runner/Info.plist`.
- App icons for iOS are generated (`flutter_launcher_icons`, DOCVA mark).

> You have **no Mac**, so the primary path is **Codemagic** (cloud macOS CI).
> `codemagic.yaml` in the repo root already defines both workflows below.
> The Mac-local instructions in §4 are only if you ever borrow a Mac.

---

## 1. What Codemagic already does (no edits needed)
`codemagic.yaml` has two workflows, both building whatever is on `main`:
1. **`ios-simulator-appetize`** — unsigned iOS Simulator build on every push to
   `main`. **No Apple account needed.** Produces `Runner-simulator.app.zip` you
   can drag into https://appetize.io to preview the DOCVA UI in a browser.
2. **`ios-release`** — signed App Store / TestFlight build (manual trigger).

## 2. One-time Apple + Codemagic setup (only YOU can do these)
The signed workflow needs an Apple Developer account and two values wired in.

1. **Apple Developer Program** — enroll ($99/yr) at https://developer.apple.com
   if you haven't. (A free Apple ID only allows 7-day on-device installs, not
   TestFlight.)
2. **App Store Connect → create the app record**
   - https://appstoreconnect.apple.com → Apps → **+** → New App
   - Platform iOS, Bundle ID `health.docva.app` (register it under
     Certificates, Identifiers & Profiles first if it isn't in the dropdown),
     name **DOCVA**, your primary language, SKU (any unique string).
   - Open the created app → **App Information** → copy the numeric **Apple ID**
     (a ~10-digit number).
3. **App Store Connect API key**
   - App Store Connect → Users and Access → **Integrations / Keys** → App Store
     Connect API → generate a key with **App Manager** role. Download the
     `.p8` (one-time), note the **Key ID** and **Issuer ID**.
4. **Add the key to Codemagic**
   - Codemagic → Teams → your team → **Integrations → App Store Connect** →
     add the key (upload `.p8`, paste Key ID + Issuer ID). Give the integration
     a **name** (e.g. `docva-asc`).
5. **Fill the two placeholders in `codemagic.yaml`** (then commit + push):
   - line ~79: `app_store_connect: CODEMAGIC_ASC_KEY_NAME` → your integration
     name from step 4 (e.g. `docva-asc`).
   - line ~88: `APP_STORE_APPLE_ID: 0000000000` → the numeric Apple ID from
     step 2.

## 3. Ship a TestFlight build
- Connect this repo (`docva-scribe`) as an app in Codemagic.
- Run the **`ios-release`** workflow (manual start). Codemagic fetches/creates
  the distribution cert + provisioning profile from the API key, builds a
  signed IPA, auto-increments the build number, and uploads to **TestFlight**.
- Add yourself/testers in App Store Connect → TestFlight; install via the
  **TestFlight** app on the iPhone. Real mic/recording, background audio, and
  Face ID only work on a **real device** (see §5), not the simulator.

## 4. (Optional) Mac-local run
```bash
cd docva
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace     # WORKSPACE, not .xcodeproj
```
In Xcode → Runner target → **Signing & Capabilities** → set your **Team**
(auto-managed profile). Then `flutter run` on a booted Simulator or a wired
iPhone.

## 5. Simulator CAN vs CANNOT test
- ✅ UI, navigation, layout, login/vault flow, most logic.
- ❌ **Real microphone / recording**, **background audio**, **Face ID hardware**
  — these need a **real iPhone** (TestFlight or a wired device). Don't sign off
  the recording engine on the simulator alone.

## 6. Capabilities already configured (verify they survive signing)
- `Info.plist`: `NSMicrophoneUsageDescription`, `NSFaceIDUsageDescription`,
  App Transport Security (no cleartext), **`UIBackgroundModes: audio`**, and
  `ITSAppUsesNonExemptEncryption=false` (standard AES/TLS only → TestFlight
  processes uploads without asking the export question each time).
- `SceneDelegate.swift`: privacy **blur overlay** when backgrounded (iOS has no
  Android `FLAG_SECURE`).
- Plugins pulling iOS pods: `record`, `flutter_foreground_task`, `just_audio`,
  `local_auth`, `flutter_secure_storage`, `sqflite_sqlcipher`,
  `connectivity_plus`, `path_provider`, `wakelock_plus`, `encrypt`.

## 7. Common fixes
- Pod errors: `cd ios && pod repo update && pod install`
- Stale build: `flutter clean && flutter pub get && (cd ios && pod install)`
- Min iOS floor: bump `ios/Podfile` `platform :ios` if a pod requires a higher
  version (the build error will name it).
