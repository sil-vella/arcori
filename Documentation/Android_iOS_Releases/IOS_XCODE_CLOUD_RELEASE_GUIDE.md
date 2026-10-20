# iOS App Store release — Arcori (Xcode Cloud + Transporter)

Path used to get **Arcori 1.0.8** into TestFlight (October 2026). Xcode Cloud archives the IPA. Apple’s “prepare build for App Store Connect” step on Cloud failed after a successful export, so the IPA was delivered with **Transporter**.

This app has **no in-app purchases**. Do not enable StoreKit or Apple Pay for this release.

Scripts that Cloud runs live next to the iOS project:

`app_codebase/flutter_base_06/ios/ci_scripts/`

Cloud clones `https://github.com/sil-vella/arcori.git`, branch `main`.

---

## Identifiers

| Name | Arcori value | Used for |
|------|----------------|----------|
| Dart package | `arcori` | Imports |
| Flutter app dir | `app_codebase/flutter_base_06` | Workspace, scripts |
| Bundle ID | `com.reignofplay.arcori` | Signing, App ID |
| SKU | `arcori` | App Store Connect only |
| Team ID | `D6J4Y6ZQGV` | `DEVELOPMENT_TEAM` in `project.pbxproj` |
| Apple ID (listing) | `6821932832` | Store URL `https://apps.apple.com/app/id6821932832` |
| Seller name | Reign of Play | Store listing |
| Name in Xcode Accounts | **Silvester Vella** (Admin) | The individual membership for this Team ID |

Bundle ID, SKU, Team ID, and Apple ID are different values. Do not reuse Dutch’s Apple ID `6772967073`.

Xcode → Settings → Accounts shows the person (**Silvester Vella**), not the seller name. That account is the right team.

---

## One-time setup (already done)

1. **App ID** — [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → explicit `com.reignofplay.arcori`. Associated Domains only. Leave **In-App Purchase** off. Do not add `com.apple.developer.in-app-payments` (that is Apple Pay and breaks Cloud export).
2. **App Store Connect app** — name Arcori, bundle `com.reignofplay.arcori`, SKU `arcori`. Apple ID **6821932832**.
3. **Business** — Paid Apps, tax, bank, and DSA were already **Active** on this team from Dutch. A second app on the same membership does not sign them again.
4. **Local signing** — open `app_codebase/flutter_base_06/ios/Runner.xcworkspace` (the Arcori workspace, not Dutch `flutter_base_05`). Runner target → Signing & Capabilities → Automatically manage signing → team **Silvester Vella**. That writes `DEVELOPMENT_TEAM = D6J4Y6ZQGV`.
5. **Xcode Cloud** — there is no Product → Xcode Cloud item. Report navigator (⌘9) → Cloud → Get Started. Product: app `arcori` / `com.reignofplay.arcori` / iOS / Silvester Vella.
6. **Workflow** — start condition **Branch Changes** on `main` (this auto-starts a build on every push to `main`; Dutch’s workflow does not). Archive action → Distribution Preparation → **App Store** / **App Store Connect**. Clean on. Post-actions: only **Notify** is selectable until Cloud setup finishes; that is expected.
7. **Environment** — Cloud does not use this Mac’s Xcode 15.2. Pin a released Cloud image (26.x or 27). The prepare failure below happened on 26.3, 26.6, and 27, so the image pin is not what blocked TestFlight.
8. **Secret** — workflow environment variable `ARCORI_DART_DEFINES_PROD_B64` = base64 of repo-root `.env.dart.defines.prod`. The script still accepts `DUTCH_DART_DEFINES_PROD_B64` if the Arcori secret is absent.

```bash
base64 -i .env.dart.defines.prod | pbcopy
```

Paste into App Store Connect → Xcode Cloud → the workflow → Environment. Re-paste when production URLs or Firebase keys change. A pubspec bump alone does not require it.

---

## What the Cloud scripts must match

`ci_pre_xcodebuild.sh` sets `FLUTTER_APP_DIR` to `app_codebase/flutter_base_06` and `REPO_ROOT` to `app_codebase` (the parent of the Flutter app, not the git root). `ios_release_prebuild.sh` then:

1. Decodes `ARCORI_DART_DEFINES_PROD_B64` into `app_codebase/.env.dart.defines.prod`.
2. Reads `app_codebase/flutter_base_06/pubspec.yaml`.
3. Rejects a build whose dart-defines lack `ARCORI_API_REST_URL`, or whose REST URL contains `localhost`, `127.0.0.1`, or `10.0.2.2`.
4. Runs `flutter build ios --config-only` so `ios/Flutter/Generated.xcconfig` contains that URL.

The first Cloud runs failed because the script was still the Dutch copy: it looked for `flutter_base_05/pubspec.yaml`, then required `API_URL`. Both are fixed on `main`.

---

## Each release

1. Confirm `Info.plist` still has the photo, camera, and microphone purpose strings (see [issue 4](#4-processing-failed-missing-nsmicrophoneusagedescription)).
2. Confirm App Icon and Launch pngs are in git (see [issue 3](#3-app-icon-pngs-missing-on-cloud)).
3. Push to `main`. Branch Changes starts Cloud. The Mac can be off while the build is queued; the queue is Apple’s, not this machine.
4. Open the build. **Export succeeded** is not the same as **the build is in TestFlight**.
5. App Store Connect → Arcori → **TestFlight → Build Uploads**.
   - New build number listed → do not upload again.
   - Export succeeded and the build number is absent → download the **app-store** artifact and deliver that IPA with Transporter (see [issue 2](#2-export-succeeded-prepare-for-app-store-connect-failed)).
6. When the upload is **Complete**, clear **Missing Compliance** on that build (see [issue 5](#5-missing-compliance-after-a-successful-upload)).
7. Install from **Internal Testing**. **Ready to Submit** is an external beta review, not the install step.

Do not upload a `CFBundleVersion` that is already in Build Uploads. Apple rejects the duplicate with `previousBundleVersion`.

The IPA Apple accepted for this app used the **Xcode Cloud build number** as `CFBundleVersion` (build **8**, then **9**) and pubspec’s marketing version **1.0.8**. That is not pubspec’s `+9` and not the script’s `10008` formula (`major * 10000 + minor * 100 + patch`). Read the new artifact’s version before a Transporter delivery.

Transporter is `/Applications/Transporter.app`. Sign in as `silvestervella@icloud.com`. Leave any older Dutch row alone.

---

## Issues we hit

### 1. First Cloud runs died in `ci_pre_xcodebuild.sh`

**Build 1:** `read_pubspec_app_version: pubspec not found` at `app_codebase/flutter_base_05/pubspec.yaml`.

**Build 2:** secret decoded, then `API_URL is missing`. This app’s key is `ARCORI_API_REST_URL` (also `ARCORI_API_WS_URL`, `ARCORI_DART_WS_URL`). There is no `API_URL`.

**Fix:** point the script at `FLUTTER_APP_DIR` (`flutter_base_06`) and validate `ARCORI_API_REST_URL`. Name the workflow secret `ARCORI_DART_DEFINES_PROD_B64`.

### 2. Export succeeded, “Preparing build for App Store Connect” failed

**Builds 3–8.** Archive and app-store export finished (`** EXPORT SUCCEEDED **`, ~25MB IPA artifact). The later action **Preparing build for App Store Connect failed**. Build 4’s `DVTITunesSoftwareService.log` contained `DVTServicesSessionProviderCredentialITunesAuthenticationContextError.proxy` / `App Store Connect response failed with unknown failure`.

TestFlight → Build Uploads stayed **No Builds**.

What it was not:

- This Mac’s Xcode 15.2 (Cloud uses its own Xcode image).
- Public wifi (the upload runs on Apple’s network).
- Missing icons (those were warnings; export still succeeded).
- A second workflow, or switching Cloud Xcode between 26.3, 26.6, and 27.
- The Errors tab. That tab can say **There are no Errors** while the prepare action is red. Read the action list.

**Fix:** stop rebuilding. Download the **app-store** zip from the build that exported, unzip `arcori.ipa`, and deliver it with Transporter. Build **8** uploaded that way (Delivery UUID `21400884-2462-413f-9e93-a0f265bc8e13`) and then failed processing for [issue 4](#4-processing-failed-missing-nsmicrophoneusagedescription). Build **9** (plist fix, same Transporter path) reached **Complete**.

### 3. App Icon pngs missing on Cloud

`.gitignore` ignores `*.png`. Cloud only builds what is in git, so App Icon and Launch images were absent and the log warned about them.

**Fix:** keep this exception under the `*.png` rule:

```
!app_codebase/flutter_base_06/ios/Runner/Assets.xcassets/**/*.png
```

Force-add the pngs if they were already ignored. This cleared the warnings. It did not fix the prepare failure.

### 4. Processing failed: missing `NSMicrophoneUsageDescription`

Build **8** reached Apple and processing returned **90683**: `Runner.app` must have `NSMicrophoneUsageDescription` because the binary references microphone APIs.

The profile screen only opens the photo library (`image_picker`, gallery). The plugin is still compiled in, so Apple requires the purpose string anyway. The same plugin references the camera.

`ios/Runner/Info.plist` now has:

- `NSPhotoLibraryUsageDescription` — choose a profile photo
- `NSCameraUsageDescription` — take a profile photo
- `NSMicrophoneUsageDescription` — photo picker includes microphone access; Arcori uses still photos

Build **8** cannot be patched. Build **9** is the upload that included these keys.

### 5. Missing Compliance after a successful upload

Build **9** showed **Complete** in Build Uploads and **Missing Compliance** on the version row.

**Manage** is not in the Build Uploads table. It is the blue link on the lower **Version 1.0.8** row, next to **Missing Compliance**.

In **App Encryption Documentation**, select **None of the algorithms mentioned above**, then **Save**. Arcori only uses HTTPS provided by iOS. That cleared compliance. Status then became **Ready to Submit**.

**Ready to Submit** starts an external TestFlight beta review. It is not required to install the build yourself. Use the left sidebar **Internal Testing**.

### 6. Do not copy these Dutch fixes onto Arcori unless the symptom matches

| Dutch lesson | Arcori |
|--------------|--------|
| `Runner.entitlements` with `com.apple.developer.in-app-payments` breaks Cloud **export** (exit 70) | Do not add it. This app does not sell anything. Associated Domains may stay. A placeholder `applinks:your-domain.example` was present during the failed prepare step and was not the cause. |
| Re-uploading a build already in TestFlight fails with `previousBundleVersion` | Same rule. Build 8 is in the list as **Failed**. Do not deliver that IPA again. |
| IAP, coin catalog, AdMob, `apple_billing_module` | Not part of this app. |

---

## Where this release stopped

| Item | State on 14 Oct 2026 |
|------|----------------------|
| TestFlight build | **1.0.8 (9)** Complete, compliance saved |
| Build 8 | Uploaded, processing **Failed** (missing microphone string) |
| Cloud prepare/upload | Still fails after a good export. Transporter is the delivery step. |
| Internal install | Not done. Next click is **Internal Testing**, not Submit. |
| App Store listing (screenshots, privacy, age rating, Add for Review) | Not started |
| `applinks:your-domain.example` | Still a placeholder. Not a TestFlight blocker. |
| iOS Firebase keys in `.env.dart.defines.prod` | Still placeholders while `FIREBASE_SWITCH` is on. Not what blocked upload. Replace them and re-base64 the secret before a build that should report analytics. |

---

*Last updated: 2026-10-14 — Arcori 1.0.8 (9) in TestFlight via Xcode Cloud export + Transporter. Script paths and `ARCORI_API_REST_URL`, icon gitignore, microphone/camera purpose strings, export-compliance answer, Cloud prepare/proxy failure.*
