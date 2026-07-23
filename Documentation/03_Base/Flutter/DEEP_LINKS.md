# Deep links (email verify)

**Status**: Template stubs — replace domain / Team ID / signing cert before production.

## Purpose

Open the **native Android/iOS app** from the email verification HTTPS link. There is **no** Flutter web verify UI.

Mail link (server):

```text
{ARCORI_PUBLIC_APP_URL}/wf-template-verify-email?token=…
```

Custom scheme (secondary / Safari same-site):

```text
arcori://wf-template-verify-email?token=…
```

App calls `POST /public/auth/verify-email` then navigates to Account.

## Path reservation (future browser refs)

| Path | Opens |
|------|--------|
| `/wf-template-verify-email` | **App only** (claimed in AASA + Android intent-filter) |
| Future `/rl/…` or marketing | **Browser** — do **not** add to AASA / App Links |
| Future `/gotoapp/…` | App — add a **separate** claim when referrals land |

## Hosting `.well-known`

Copy stubs from this folder to the App Link host (same host as `ARCORI_PUBLIC_APP_URL`):

- [`well-known/apple-app-site-association`](well-known/apple-app-site-association)
- [`well-known/assetlinks.json`](well-known/assetlinks.json)

Requirements:

- HTTPS, **no redirects**
- Correct `Content-Type` (Apple: `application/json`)
- Replace `TEAMID`, package name, and Play App Signing SHA-256
- AndroidManifest host + iOS `applinks:` must match that host

## Flutter / OS flags

- Android: `flutter_deeplinking_enabled`, App Link `pathPrefix="/wf-template-verify-email"`, scheme `arcori`
- iOS: `FlutterDeepLinkingEnabled`, URL scheme `arcori`, `Runner.entitlements` associated domains

## Branding rename

After [`rename_arcori_branding.py`](../../../automation/local/rename_arcori_branding.py):

- Scheme `arcori` → product flat name
- Path `wf-template-verify-email` → `{kebab}-verify-email`
- Update AndroidManifest host, entitlements, and deployed `.well-known` files

## Local debug

```bash
# Android
adb shell am start -a android.intent.action.VIEW \
  -d 'arcori://wf-template-verify-email?token=TEST_TOKEN'

# iOS Simulator
xcrun simctl openurl booted \
  'arcori://wf-template-verify-email?token=TEST_TOKEN'
```

Set `ARCORI_PUBLIC_APP_URL` to the real App Link domain in prod (not Flutter web `localhost:3002`).
