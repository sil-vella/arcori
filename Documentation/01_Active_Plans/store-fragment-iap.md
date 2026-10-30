# Store purchases — Gold Fragment packs

**Status**: In Progress  
**Created**: 2026-10-28  
**Last Updated**: 2026-10-30

## Objective

Sell Gold Fragments through Google Play and the App Store at the same pack sizes and USD prices as Dutch coin packs. The server verifies the receipt and credits the Avari wallet. Four fragments still fold into one Gold Arcori. No Premium subscription and no Stripe checkout.

## Implementation Steps

- [x] Catalog JSON (amounts and price labels match Dutch `recommended_ui_packages`)
- [x] Postgres ledger + authuser verify routes (Play token, Apple signed transaction)
- [x] Flutter Market entry and consumable purchase screen
- [x] Pin `in_app_purchase_android` 0.4.0+5 and StoreKit 0.4.0
- [x] Create matching consumable products in Play Console and App Store Connect
- [ ] Set `GOOGLE_PLAY_*` and `APPLE_IAP_*` on the API host and confirm a license-test purchase

## Current Progress

Code path is in the app. Both store catalogs exist for `fragments_100` through `fragments_3500`. A real charge still cannot credit a wallet until `GOOGLE_PLAY_*` and `APPLE_IAP_*` are set on the API host. Until then, verify returns `store/not_configured`.

The products are created, not submitted for sale. Apple reviews the first consumable together with a new app version. Play products are Active on the closed-testing app.

## Next Steps

Point the API at package and bundle `com.reignofplay.arcori` (not Dutch) and confirm a license-test purchase. Do not submit the App Store packs until that app version is ready.

## Files Modified

- `app_codebase/python_base_05/bin/modules/store/`
- `app_codebase/python_base_05/bin/models/store_fragment_purchase.py`
- `app_codebase/python_base_05/alembic/versions/034_store_fragment_purchases.py`
- `app_codebase/flutter_base_06/lib/modules/store/`
- `app_codebase/flutter_base_06/lib/modules/market/screens/market_screen.dart`

## Notes

Product IDs are `fragments_100` through `fragments_3500`, not Dutch’s `coins_*` / `coin_500` ids. Amounts and list prices match Dutch: 100/$0.99, 300/$2.49, 500/$3.99, 700/$4.99, 1500/$9.99, 3500/$19.99. The store’s localized price replaces the label when the device can query the product.

Play consume runs after the wallet credit commits. A repeated token returns the same credit without adding fragments again. Apple JWS is checked with `app-store-server-library` against the bundled Apple root certificates.

The app itself is a paid download. The requested price was **$2.59**. App Store Connect has no $2.59 point, so both stores use **$2.99**. The Play download price is not entered yet. Fragment pack prices are unchanged.

### How the catalogs were created

Same six consumable product IDs on both stores. No Premium subscription.

Use the store’s write API when the key is allowed to create products. If that call is refused, use **Manage with AI** on that store’s web console and give it the full product list. Do not invent a second set of product IDs.

| | Google Play | App Store |
|--|-------------|-----------|
| App | `com.reignofplay.arcori` | `com.reignofplay.arcori`, Apple ID `6821932832` |
| Type | One-time product, purchase option **Buy**, backwards compatible, digital content | **Consumable** |
| Write path that worked | Console. The Android Publisher `oneTimeProducts` create call returned “Can’t create product. To fix, request billing permission.” The revenue-reader key can list products and cannot create them. `fragments_100` was entered by hand. The other five were created with **Manage with AI** on the Play Console. | App Store Connect API, using the existing `ASC_ISSUER_ID` / `ASC_KEY_ID` / `ASC_PRIVATE_KEY_PATH` key. `fragments_100` was entered in the web UI. `fragments_300` through `fragments_3500` were created with `POST /v2/inAppPurchases`, then a version, an `en-US` localization, a USA price schedule, availability in every territory, and a review screenshot. |
| Fallback if the API cannot write | **Manage with AI** on Monetize with Play → Products → One-time products | **Manage with AI** on the In-App Purchases page. Not needed for this catalog. |
| Name | `N Gold Fragments` | Reference name and display name `N Gold Fragments` |
| Description | `Adds N Gold Fragments. Every 4 fragments become 1 Gold Arcori.` | `Adds N Gold Fragments. 4 fragments = 1 Gold Arcori.` |
| Price | USD list price above, applied to every region. Purchase option id `{N}-fragments` (for example `100-fragments`). | USA price at that same USD amount. Apple fills the other countries from the base price. |
| Extra gate | The One-time products page stays empty until an uploaded bundle declares `com.android.vending.BILLING`. Play automatic protection requires `minSdk` 24. Upload that bundle to the existing closed-testing track. Applying for production does not unlock products. | Paid Apps agreement is already active for this team. Do not add `com.apple.developer.in-app-payments`. The review screenshot must be an accepted iPhone size ([In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)). Phone snaps are in `automation/frontend/launch_android_assets/android/phone/` at 1080×1920. The review upload was a 1242×2208 crop of the market captures. Those extra crops are not kept. The same captures at the required listing size are `ios/iphone/wf_shot_20261030_130059_iphone.png` (`fragments_1500`, `fragments_3500`) and `ios/iphone/wf_shot_20261030_130039_iphone.png` (the other packs). |

The first App Store consumable is submitted with a new app version, not by itself. Leave **Add for Review** until that version is ready.

## Case study

Economy row and decision table in `03_CASE_STUDY.md`.

## Task Manager

App Dev checklist 407 (code, done) and 408 (store consoles and credentials, open). Note on task 32.
