# iOS App Store release — end-to-end guide (Xcode Cloud)

Full path from Apple Developer enrollment through **production IPA**, **TestFlight**, **in-app purchases** (catalog SSOT), and App Store submission.

This guide uses the **self-contained Xcode Cloud pipeline**: four scripts (two Cloud hooks + two sourced libraries), with **no** `playbooks/frontend/` dependency.

**Related docs (this folder):**

| Doc | Purpose |
|-----|---------|
| [IOS_RELEASE_CHECKLIST.md](../flutter_base_05/IOS_RELEASE_CHECKLIST.md) | Short operational checklist |
| [IOS_IN_APP_PURCHASES_SETUP.md](IOS_IN_APP_PURCHASES_SETUP.md) | Coin packs + Premium in App Store Connect |
| [COIN_CATALOG_SSOT.md](COIN_CATALOG_SSOT.md) | Product IDs shared with Android/backend |
| [README.md](README.md) | Xcode 15.2 SDK pins |

**Project:** `flutter_base_05`  
**Reference build:** version **2.0.20**, build **20020** (May 2026)

**Script staging (`app_dev`):** edit scripts in repo-root [`ci_scripts/`](../../ci_scripts/). Copy the **entire directory** into `flutter_base_05/ios/ci_scripts/` (or your Flutter app’s `ios/ci_scripts/`) before pushing to the dedicated iOS repo. Xcode Cloud only auto-runs hooks in `ios/ci_scripts/` next to the workspace.

---

## Table of contents

1. [Identifiers](#1-identifiers--what-is-what)
2. [Prerequisites](#2-prerequisites)
3. [Apple Developer Program](#3-apple-developer-program)
4. [Register App ID](#4-register-the-app-id-bundle-id)
5. [App Store Connect — app record](#5-app-store-connect--create-the-app)
6. [Business — Paid Apps, tax, bank, DSA](#6-business--paid-apps-tax-bank-dsa)
7. [Coin catalog SSOT](#7-coin-catalog-ssot-product-ids)
8. [Repo and Xcode configuration](#8-repo-and-xcode-configuration)
9. [Xcode signing](#9-xcode-signing-one-time)
10. [Build the IPA — GitHub / Xcode Cloud](#10-build-the-ipa--github--xcode-cloud)
11. [Upload](#11-upload-to-app-store-connect)
12. [TestFlight and review](#12-after-upload--testflight-and-review)
13. [In-app purchases](#13-in-app-purchases)
14. [Android vs iOS release](#14-android-vs-ios-release)
15. [What automation exists in the repo](#15-what-automation-exists-in-the-repo)
16. [Troubleshooting and issues we hit](#16-troubleshooting-and-issues-we-hit)
17. [Official Apple links](#17-official-apple-references)
18. [Process timeline](#18-process-timeline)

---

## 1. Identifiers — what is what

| Name | Dutch value | Used for |
|------|-------------|----------|
| **Dart package** (`pubspec.yaml`) | `dutch` | Imports only |
| **Bundle ID** | `com.reignofplay.dutch` | Signing, Firebase, ASC |
| **SKU** | `dutch-card-game` | Internal ASC only |
| **Team ID** | `D6J4Y6ZQGV` | Xcode `DEVELOPMENT_TEAM` |
| **Apple ID** (listing) | `6772967073` | `https://apps.apple.com/app/id6772967073` |
| **Developer ID** (UUID) | membership UUID | Account only — **not** store URL |

**Rule:** Bundle ID ≠ Apple ID ≠ Team ID.  
`APP_STORE_URL=https://apps.apple.com/app/id6772967073` in `.env.dart.defines.prod`.

---

## 2. Prerequisites

- Mac + **Xcode 15.2** (see [README.md](README.md) for dependency pins)
- **Flutter** + CocoaPods (`flutter doctor`)
- **Apple Developer Program** (paid)
- Local env (not in git): `.env.dart.defines.prod` (and optionally `.env.prod`)

---

## 3. Apple Developer Program

1. [Enroll](https://developer.apple.com/programs/)
2. [App Store Connect](https://appstoreconnect.apple.com/) + [Developer account](https://developer.apple.com/account)
3. Note **Team ID** `D6J4Y6ZQGV`
4. **Xcode → Settings → Accounts** → Apple ID

---

## 4. Register the App ID (bundle ID)

[Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** → App → Explicit **`com.reignofplay.dutch`**.

Enable **In-App Purchase** on this App ID (required for coin packs + Premium). Do **not** add a `Runner.entitlements` entry for `com.apple.developer.in-app-payments` — that key is **Apple Pay**, not StoreKit, and breaks Xcode Cloud export (see [§16.4](#164-export-archive-exit-code-70-after-archive-succeeds)).

[Register an App ID](https://developer.apple.com/help/account/manage-identifiers/register-an-app-id/)

---

## 5. App Store Connect — create the app

| Field | Value |
|-------|--------|
| Name | Dutch Card Game |
| Bundle ID | `com.reignofplay.dutch` |
| SKU | `dutch-card-game` |
| User Access | Full Access (typical) |

**General Information:** Apple ID **6772967073**.

---

## 6. Business — Paid Apps, tax, bank, DSA

Required before **Monetization → In-App Purchases** works.

### 6.1 Order of operations

1. **Edit Legal Entity** (if prompted)
2. **DSA trader** declaration — [EU trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)  
   - Selling IAP + ads in EU → usually declare **trader** (contact info shown on EU store page)  
   - Not “trader” only if you truly qualify and accept EU consumer-law notice
3. **Paid Apps Agreement** — [Sign agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/) → **Business** → **View and Agree to Terms**
4. **Tax** — W-8BEN + Certificate of Foreign Status (Malta individual)
5. **Bank** — e.g. BOV Malta; status **Processing** ~24h

### 6.2 Status targets

| Item | Target |
|------|--------|
| Paid Apps Agreement | **Active** (not Processing / Pending User Info) |
| Tax forms | **Active** |
| Bank | Active (not Processing) |
| DSA compliance | Approved (not In Review) |

Until **Paid Apps = Active**, IAP creation in Connect may be blocked.

---

## 7. Coin catalog SSOT (product IDs)

**Do not invent IDs in App Store Connect** — copy from:

[`flutter_base_05/assets/dutch_coin_catalog.json`](../../flutter_base_05/assets/dutch_coin_catalog.json)

Full reference: [COIN_CATALOG_SSOT.md](COIN_CATALOG_SSOT.md)

### Consumables (App Store type: Consumable)

```
coins_100, coins_300, coin_500, coins_700, coins_1500, coins_3500
```

### Subscriptions (one group, two products)

Apple subscription **Product IDs cannot contain hyphens**. Use the SSOT values under `premium_subscription.apple_product_ids`:

```
premium_auto_renew_monthly   (1 month)
premium_auto_renew_yearly    (1 year)
```

Play also uses parent SKU `premium_subscription` (Android only).

### Code / backend

| Layer | Uses catalog? |
|-------|----------------|
| Flutter `CoinCatalog` | Yes — bundled JSON |
| Python `utils/coin_catalog.py` | Yes — same file path |
| Play verify | Yes — unknown `product_id` → 400 |
| iOS StoreKit in app | **Wired** — App Store coin packs + Premium via `in_app_purchase` |
| Apple server verify | **Implemented** — `apple_billing_module` (`/userauth/apple/*`) |

Setup in Connect: [IOS_IN_APP_PURCHASES_SETUP.md](IOS_IN_APP_PURCHASES_SETUP.md)

---

## 8. Repo and Xcode configuration

| Item | Location |
|------|----------|
| Bundle ID | `ios/Runner.xcodeproj` → `com.reignofplay.dutch` |
| Team + signing | `DEVELOPMENT_TEAM = D6J4Y6ZQGV`, automatic signing |
| Display name | `Info.plist` → Dutch Card Game |
| Firebase | `GoogleService-Info.plist` |
| AdMob app ID (native) | `ios/Flutter/Debug.xcconfig` / `Release.xcconfig` → `GAD_APPLICATION_ID` |
| AdMob unit IDs (Dart) | `.env.dart.defines.prod` (`ADMOBS_*` keys) |
| Coin catalog | `assets/dutch_coin_catalog.json` |
| CI scripts (staging) | [`ci_scripts/`](../../ci_scripts/) at repo root — copy to `ios/ci_scripts/` |
| Xcode Cloud CI hooks | `ios/ci_scripts/ci_post_clone.sh`, `ci_pre_xcodebuild.sh` |
| Shared prebuild lib | `ios/ci_scripts/ios_release_prebuild.sh` |
| Repo-specific pre-build | `ios/ci_scripts/pre_build_config_adjust_ios.sh` (`LOGGING_SWITCH` off, etc.) |
| ASC build floor | `ios/xcode_cloud_build_number.txt` |
| Env materialize (Cloud) | `ios_release_prebuild.sh` (decode `DUTCH_DART_DEFINES_PROD_B64`) |

Open: `flutter_base_05/ios/Runner.xcworkspace`

**Gitignored locally (not on GitHub):** `.env.dart.defines.prod`, optional `.env.prod`, `secrets/apple-iap-key.p8`. Xcode Cloud recreates dart-defines from workflow secrets (below).

**Repo layout:** scripts assume `repo_root/flutter_base_05/` (Flutter app one level below repo root).

---

## 9. Xcode signing (one-time)

1. **Settings → Accounts** → Apple ID (team D6J4Y6ZQGV)
2. Runner → **Signing & Capabilities** → automatic signing, no red errors

CLI `flutter build ipa` fails with *No Accounts* until step 1 is done.

---

## 10. Build the IPA — GitHub / Xcode Cloud

Production TestFlight builds: **commit + push to GitHub** → Xcode Cloud archives, exports, and (when configured) uploads to App Store Connect.

### 10.1 CI scripts

**Staging:** `ci_scripts/` at repo root (`app_dev/ci_scripts/`).  
**Deployed:** copy the whole folder to `flutter_base_05/ios/ci_scripts/` (paths below are relative to that `ios/ci_scripts/` directory).

| Script | Xcode Cloud hook? | Role |
|--------|-------------------|------|
| `ci_post_clone.sh` | **Yes** (auto-run) | Flutter install, `pub get`, `precache --ios`, `pod install` |
| `ci_pre_xcodebuild.sh` | **Yes** (auto-run) | Orchestrates prebuild, repo config, `config-only` |
| `ios_release_prebuild.sh` | No (sourced) | Env materialize, version sync, dart-defines JSON, `API_URL` validation |
| `pre_build_config_adjust_ios.sh` | No (sourced) | Repo-specific release prep on the CI runner (currently `LOGGING_SWITCH` → `false`) |

**Pre-xcodebuild steps** (`ci_pre_xcodebuild.sh` sources the two libraries):

1. Decode **`DUTCH_DART_DEFINES_PROD_B64`** → repo-root `.env.dart.defines.prod`
2. **Version sync** — read `pubspec.yaml`, align build number with ASC floor (`xcode_cloud_build_number.txt` + `project.pbxproj`)
3. **`pre_build_config_adjust_ios()`** — disable `LOGGING_SWITCH` in Dart sources on the build machine (does not change your git commit)
4. Build **dart-define JSON** from `.env.dart.defines.prod` + validate **`API_URL`** (production, not localhost)
5. **`flutter build ios --config-only --no-codesign`** — bakes defines into `Generated.xcconfig`

Add more repo-specific steps in `pre_build_config_adjust_ios.sh` inside `pre_build_config_adjust_ios()`.

```mermaid
flowchart LR
  dev[Mac: edit code + pubspec version]
  git[git push GitHub]
  xc[Xcode Cloud workflow]
  post[ci_post_clone.sh]
  pre[ci_pre_xcodebuild.sh]
  lib[ios_release_prebuild.sh]
  adj[pre_build_config_adjust_ios.sh]
  arch[xcodebuild archive]
  exp[exportArchive]
  asc[TestFlight / App Store Connect]

  dev --> git --> xc --> post --> pre
  pre --> lib
  pre --> adj
  pre --> arch --> exp --> asc
```

| Step | What happens |
|------|----------------|
| 1 | **Push to GitHub** — triggers Xcode Cloud. `.env*` files are **not** in the repo. |
| 2 | `ci_post_clone.sh` — Flutter + CocoaPods under `ios/`. |
| 3 | `ios_release_prebuild.sh` — materialize env, version sync. |
| 4 | `pre_build_config_adjust_ios.sh` — `LOGGING_SWITCH` off (and future repo tweaks). |
| 5 | `ci_pre_xcodebuild.sh` — dart-defines JSON, `flutter build ios --config-only --dart-define-from-file`. |
| 6 | Xcode Cloud — `xcodebuild archive` then `exportArchive` (app-store / ad-hoc / development). |
| 7 | Distribution — if workflow includes **Distribute to App Store Connect**, build appears under **TestFlight → Build Uploads**. |

### 10.2 Xcode Cloud workflow secrets

App Store Connect → **Xcode Cloud** → workflow → **Environment** — **not** GitHub Secrets:

| Secret | Required | Contents |
|--------|----------|----------|
| `DUTCH_DART_DEFINES_PROD_B64` | **Yes** | Base64 of repo-root `.env.dart.defines.prod` (`API_URL`, `WS_URL`, Firebase client keys, `APP_STORE_URL`, `ADMOBS_*`, etc.) |
| `DUTCH_ENV_PROD_B64` | No | Base64 of `.env.prod` — **not used** in practice for this pipeline |

> **Note — dart-defines only:** Xcode Cloud builds in this repo use **only** `DUTCH_DART_DEFINES_PROD_B64`. You do **not** need to paste `.env.prod` (`DUTCH_ENV_PROD_B64`). Version and build number come from **committed `pubspec.yaml`** on each push, not from `.env.prod`. There is no script that encodes secrets for you — edit `.env.dart.defines.prod` locally, then base64 it and paste into App Store Connect.

Refresh whenever you change API URLs, Firebase, AdMob dart-defines, `APP_STORE_URL`, etc. in `.env.dart.defines.prod` (a `pubspec.yaml` bump alone does **not** require re-pasting):

```bash
cd /path/to/repo
base64 -i .env.dart.defines.prod | pbcopy
# Paste into App Store Connect → Xcode Cloud → Environment → DUTCH_DART_DEFINES_PROD_B64
```

Do **not** run `base64 -i .env.prod` for Cloud unless you have a specific reason to add the optional `DUTCH_ENV_PROD_B64` secret.

### 10.3 Each release

1. Bump `flutter_base_05/pubspec.yaml` `version:` (e.g. `2.0.86+20086`)
2. Commit and **push to GitHub**
3. Xcode Cloud runs post-clone → pre-xcodebuild → archive → export
4. Confirm pre-xcodebuild logs (see [§16.2](#162-no-env-files-on-github--cloud-login--api-failures))
5. Check **TestFlight → Build Uploads** before manual upload

**Apple IAP server keys** (`APPLE_IAP_*`, `.p8`) are **not** in dart-defines — they deploy to the VPS via Ansible, not Xcode Cloud.

### 10.4 Local dry-run (optional)

After copying `ci_scripts/` to `flutter_base_05/ios/ci_scripts/` (or run from staging with paths adjusted):

```bash
export REPO_ROOT=/path/to/app_dev
# Optional: export DUTCH_DART_DEFINES_PROD_B64="$(base64 -i .env.dart.defines.prod)"
./flutter_base_05/ios/ci_scripts/ci_post_clone.sh
./flutter_base_05/ios/ci_scripts/ci_pre_xcodebuild.sh
```

Pre-xcodebuild logs should include `🔇 Disabling LOGGING_SWITCH`, `✅ API_URL validated`, and `Pre-xcodebuild complete`.

### 10.5 Local IPA build (optional)

On a Mac with Xcode and signing configured, after the pre-xcodebuild dry-run (or with local `.env.dart.defines.prod`):

```bash
cd flutter_base_05
# Build dart-define JSON locally (same keys as .env.dart.defines.prod), then:
flutter build ipa --dart-define-from-file=/path/to/dart-defines.json
```

Output: `flutter_base_05/build/ios/ipa/*.ipa` — upload via Transporter if not using Cloud distribution.

---

## 11. Upload to App Store Connect

### Check TestFlight first (required)

**Before** using Transporter or Organizer, open App Store Connect → **TestFlight** → **Build Uploads**.

| What you see | What to do |
|--------------|------------|
| Your build number already listed (**Complete** or **Processing**) | **Do not upload again.** Xcode Cloud (or an earlier Transporter run) already delivered it. Use that build for testing or **Distribution**. |
| Build number **not** listed | Upload once via Transporter or Organizer (see below). |

Duplicate uploads fail with `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE` / `previousBundleVersion` — e.g. *“bundle version must be higher than the previously uploaded version: ‘20068’”* while you are uploading **20068** again.

**Xcode Cloud:** If the workflow includes **Distribute to App Store Connect** / TestFlight, builds appear in **Build Uploads** automatically. Skip Transporter for those builds.

### Upload manually (only when TestFlight does not already have the build)

- [Transporter](https://apps.apple.com/us/app/transporter/id1450874784) — drag IPA  
- Or **Organizer → Distribute App → App Store Connect**

Wait for **Processing** in TestFlight.

---

## 12. After upload — TestFlight and review

- Internal TestFlight → smoke-test (use the build already in **Build Uploads** if present)
- **Distribution → 1.0**: screenshots, privacy, description, attach build → **Add for Review**

---

## 13. In-app purchases

1. **App Store Connect** — follow [IOS_IN_APP_PURCHASES_SETUP.md](IOS_IN_APP_PURCHASES_SETUP.md): six **consumables** + subscription group (`premium_auto_renew_monthly` / `premium_auto_renew_yearly`) from [§7](#7-coin-catalog-ssot-product-ids).
2. **App ID** — **In-App Purchase** enabled on `com.reignofplay.dutch` in Developer Portal (no Apple Pay entitlements file).
3. **Flutter** — StoreKit via `in_app_purchase` (coins + Premium); no Stripe redirect on iOS.
4. **Backend** — `apple_billing_module` on Flask (`/userauth/apple/*`); secrets in `.env.prod` + VPS deploy.

Server setup: [APPLE_APP_STORE_BILLING.md](../python_base_04/APPLE_APP_STORE_BILLING.md)

**App Review:** Attach IAPs to the app version; note that digital coins and Premium are sold only via Apple IAP on iOS (rewarded ads optional).

---

## 14. Android vs iOS release

| | Android | iOS |
|--|---------|-----|
| Build | `build_apk.sh` / `build_appbundle.sh` (separate repo/playbooks) | **GitHub push → Xcode Cloud** (`ci_post_clone` + `ci_pre_xcodebuild` + `ios_release_prebuild` + `pre_build_config_adjust_ios`) or local `flutter build ipa` |
| Store IDs | Package = bundle ID | Bundle ID + Apple ID `6772967073` |
| IAP SSOT | `dutch_coin_catalog.json` | Same file |
| IAP live | Play + server verify | App Store IAP + `apple_billing_module` server verify |
| Upload | Play Console | TestFlight / Transporter |

[GOOGLE_PLAY_BILLING.md](../python_base_04/GOOGLE_PLAY_BILLING.md)

---

## 15. What automation exists in the repo

| In repo (GitHub) | Manual / secrets outside git |
|------------------|------------------------------|
| `ci_scripts/` → `ios/ci_scripts/` (4 scripts) | Xcode Cloud workflow + Apple signing |
| `pre_build_config_adjust_ios.sh` — edit per repo | **`DUTCH_DART_DEFINES_PROD_B64`** in App Store Connect (dart-defines only; not `.env.prod`) |
| `xcode_cloud_build_number.txt` | Refresh base64 secret when dart-defines change |
| `dutch_coin_catalog.json` + loaders | Create IAPs in Connect (match JSON) |
| `apple_billing_module` + deploy playbook (backend repo) | `APPLE_IAP_*` + `secrets/apple-iap-key.p8` on VPS |
| `APP_STORE_URL` in dart-defines | Business agreements, tax, bank, DSA |
| `IOS_*` docs in `Documentation/Android_V_ios/` | TestFlight on device, metadata, **Add for Review** |

---

## 16. Troubleshooting and issues we hit

### 16.1 App Store rejection — “billing not enabled” / Stripe message

**Symptom:** Review showed *“App Store billing is not enabled in this build. Use the web app (Stripe)…”* on the coin screen.

**Cause:** iOS had Android Play + web Stripe only; StoreKit IAP was not wired after RevenueCat removal.

**Fix:** Flutter native store bootstrap for iOS, `apple_billing_module` server verify, remove Stripe stub UI. Resubmit with IAPs attached to the version and App Review notes explaining coins/Premium via Apple IAP only.

### 16.2 No `.env` files on GitHub — Cloud login / API failures

**Symptom:** TestFlight build archives but app cannot reach API, or login spins forever.

**Cause:** Xcode Cloud clone has no `.env.dart.defines.prod`; missing or stale **`DUTCH_DART_DEFINES_PROD_B64`**.

**Fix:**

1. Edit local `.env.dart.defines.prod` (`API_URL`, `WS_URL`, etc.).
2. `base64 -i .env.dart.defines.prod | pbcopy` → update secret in **App Store Connect → Xcode Cloud → Environment** (not GitHub repo settings).
3. Re-run workflow; confirm pre-xcodebuild log:

```
🔇 Disabling LOGGING_SWITCH in Flutter sources...
✅ API_URL validated: https://dutch.reignofplay.com
✅ Generated.xcconfig includes API_URL
===> Pre-xcodebuild complete
```

### 16.3 AdMob on iOS

**Symptom:** Ads fail to load on iOS TestFlight, or wrong creatives during review.

**Cause:** iOS `GAD_APPLICATION_ID` lives in `ios/Flutter/*.xcconfig` (not Gradle). Android demo unit IDs (`ca-app-pub-3940256099942544/6300978111`, app id `~3347511713`) do **not** work on iOS — iOS uses different [Google demo IDs](https://developers.google.com/admob/ios/test-ads) (e.g. banner `/2934735716`, app id `~1458002511`).

**Fix:** Set the correct values in:

- `ios/Flutter/Debug.xcconfig` / `Release.xcconfig` → `GAD_APPLICATION_ID`
- `.env.dart.defines.prod` → `ADMOBS_*` dart-defines for Dart-side unit IDs

Use Google’s iOS test IDs for TestFlight and App Review; switch to production Dutch ad units when shipping live ads. Re-base64 `DUTCH_DART_DEFINES_PROD_B64` when you change dart-define keys.

### 16.4 Export archive exit code 70 (after archive succeeds)

**Symptom:** Xcode Cloud: **Run xcodebuild archive** ✅, then all three **Export archive** steps fail with **exit code 70** (ad-hoc, development, app-store).

**Cause (our case):** `Runner.entitlements` contained `com.apple.developer.in-app-payments` with an empty array — that is **Apple Pay**, not StoreKit IAP. Xcode Cloud managed provisioning profiles did not include it → export signing failed.

**Fix:**

1. Remove bogus `Runner.entitlements` (StoreKit IAP does not need an entitlements plist entry).
2. Enable **In-App Purchase** on the App ID in [Developer Portal](https://developer.apple.com/account/resources/identifiers/list) only.
3. Commit, push, re-run Cloud workflow.

**If still failing:** Download build artifact **`app-store-export-archive-logs/xcodebuild-export-archive.log`** and search `error: exportArchive`. Certificate issues: revoke stale **Xcode Cloud managed** distribution certificates in Developer Portal, then rebuild.

### 16.5 General troubleshooting

| Symptom | Fix |
|---------|-----|
| IAP **+** disabled in Connect | Wait for Paid Apps **Active** + tax + bank |
| No Accounts on `flutter build ipa` | Xcode → Settings → Accounts |
| CocoaPods UTF-8 | `LANG=en_US.UTF-8` in shell / Cloud scripts |
| Duplicate build / `previousBundleVersion` | **TestFlight → Build Uploads** first — Cloud may have uploaded already; bump build number for new bits |
| Share link empty | `APP_STORE_URL=https://apps.apple.com/app/id6772967073` in dart-defines + refresh secret |
| SDK compile errors | [README.md](README.md) pins |
| Unknown product on Play verify | Add ID to `in_app_products` in catalog |
| `Missing DUTCH_DART_DEFINES_PROD_B64` | Add workflow secret in App Store Connect |
| `Generated.xcconfig DART_DEFINES is empty` | Re-run pre-xcodebuild; check `flutter build ios --config-only` logs |

---

## 17. Official Apple references

- [Sign agreements (Paid Apps)](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)
- [DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [Tax information](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/)
- [Banking](https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information/)
- [Configure IAP overview](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)
- [Create consumable IAP](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/)
- [Auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [Preparing for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
- [Distributing / TestFlight](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

---

## 18. Process timeline

```mermaid
flowchart TD
  enroll[Developer Program]
  appId[App ID + In-App Purchase capability]
  ascApp[ASC app record]
  business[Paid Apps tax bank DSA]
  catalog[Coin catalog SSOT]
  iapConnect[IAPs in App Store Connect]
  gitPush[git push GitHub]
  xcCloud[Xcode Cloud: post-clone + pre-xcodebuild]
  secret[DUTCH_DART_DEFINES_PROD_B64]
  arch[archive + export]
  checkTf[TestFlight Build Uploads]
  upload[Transporter only if missing]
  tf[TestFlight smoke test]
  appleSrv[apple_billing_module on VPS]
  review[Add for Review]

  enroll --> appId --> ascApp --> business
  business --> iapConnect
  catalog --> iapConnect
  secret --> xcCloud
  ascApp --> gitPush --> xcCloud --> arch --> checkTf
  checkTf -->|already listed| tf
  checkTf -->|not listed| upload --> tf
  iapConnect --> appleSrv
  tf --> review
```

---

*Last updated: 2026-06-22 — Xcode Cloud 4-script pipeline (`pre_build_config_adjust_ios`), `ci_scripts/` staging, dart-defines-only secret, AdMob via xcconfig + dart-defines, export exit 70 / entitlements fix, StoreKit IAP + Apple server verify.*
