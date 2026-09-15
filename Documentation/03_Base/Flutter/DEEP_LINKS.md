# Deep links (email verify + Legacy preserve return)

**Status**: Template stubs — replace domain / Team ID / signing cert before production.

## Purpose

Open the **native Android/iOS app** from HTTPS App Links or custom-scheme URLs. There is **no** Flutter web UI for these paths.

### Email verify

Mail link (server):

```text
{ARCORI_PUBLIC_APP_URL}/arcori-verify-email?token=…
```

Custom scheme (secondary / Safari same-site):

```text
arcori://arcori-verify-email?token=…
```

App calls `POST /public/auth/verify-email` then navigates to Account.

### Legacy preserve complete (post-checkout)

Website redirects after **service fulfill** succeeds:

```text
arcori://legacy-preserve-complete?intentId=…&orderId=…
```

HTTPS App Link twin (when host claimed):

```text
{ARCORI_PUBLIC_APP_URL}/legacy-preserve-complete?intentId=…&orderId=…
```

App calls `POST /authuser/legacy/preserve/complete` (authenticated) — **does not mint**; surfaces fulfill ledger + celebration. Website contract: [arcori-website-legacy-checkout.md](../../00_System_Wide/arcori-website-legacy-checkout.md).

## Path reservation (future browser refs)

| Path | Opens |
|------|--------|
| `/arcori-verify-email` | **App only** (claimed in AASA + Android intent-filter) |
| `/legacy-preserve-complete` | **App only** (claimed alongside verify-email) |
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

- Android: `flutter_deeplinking_enabled`, App Link `pathPrefix` for `/arcori-verify-email` and `/legacy-preserve-complete`, scheme `arcori` hosts `arcori-verify-email` + `legacy-preserve-complete`
- iOS: `FlutterDeepLinkingEnabled`, URL scheme `arcori`, `Runner.entitlements` associated domains

## Branding rename

After [`rename_arcori_branding.py`](../../../automation/local/rename_arcori_branding.py):

- Scheme `arcori` → product flat name
- Path `arcori-verify-email` → `{kebab}-verify-email`
- Path `legacy-preserve-complete` stays descriptive (or brand-prefix if desired)
- Update AndroidManifest host, entitlements, and deployed `.well-known` files

## Local debug

```bash
# Android — email verify
adb shell am start -a android.intent.action.VIEW \
  -d 'arcori://arcori-verify-email?token=TEST_TOKEN'

# Android — legacy return
adb shell am start -a android.intent.action.VIEW \
  -d 'arcori://legacy-preserve-complete?intentId=TEST&orderId=TEST'

# iOS Simulator
xcrun simctl openurl booted \
  'arcori://arcori-verify-email?token=TEST_TOKEN'
xcrun simctl openurl booted \
  'arcori://legacy-preserve-complete?intentId=TEST&orderId=TEST'
```

Set `ARCORI_PUBLIC_APP_URL` to the real App Link domain in prod (not Flutter web `localhost:3002`).
