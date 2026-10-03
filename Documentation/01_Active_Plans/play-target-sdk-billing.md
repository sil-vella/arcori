# Play target SDK and Billing Library alignment

**Status**: Completed  
**Created**: 2026-09-26  
**Last Updated**: 2026-09-26

## Objective

Match the Dutch Android release fixes that Google Play started enforcing on 31 Aug 2026: target API 36, and Billing Library 9.1.0 if `in_app_purchase_android` 0.4.0+5 is on the classpath. Flutter on this machine stays 3.32.8 / Dart 3.8.1.

## Implementation Steps

- [x] Floor `compileSdk` and `targetSdk` at 36, and `minSdk` at 23, in the app Gradle file
- [x] Opt the application into Android 16 restricted-resizability compatibility
- [x] Force `com.android.billingclient:billing*` to 9.1.0 and stage the Billing 8 callback patch without editing the Pub cache
- [x] Leave `in_app_purchase` out of `pubspec.yaml` — Arcori does not ship Play purchases yet
- [x] Portrait-lock the activity, iOS (including iPad full screen), and Flutter `portraitUp`

## Current Progress

Gradle and the manifest match the Dutch Play compliance setup. `platforms;android-36` and `build-tools;36.0.0` are already installed in the local Android SDK.

The billing plugin is not a dependency of this app, so the staged `MethodCallHandlerImpl.java` is not compiled into the current bundle. The Gradle hook runs only when an `in_app_purchase_android` Android library project is present, and it refuses any version other than `0.4.0+5`.

No store version bump. `pubspec.yaml` is still `1.0.0+1`. Dutch’s `2.1.27` bump stays in that repo.

## Next Steps

When Play purchases are added, pin `in_app_purchase_android: 0.4.0+5` in `pubspec.yaml` (0.5.x needs Dart 3.10+). Do not upgrade Flutter just to take the newer plugin. Restore must keep using `queryPurchasesAsync`; `queryPurchaseHistoryAsync` returns an error under Billing 8+.

## Files Modified

- `app_codebase/flutter_base_06/android/app/build.gradle.kts`
- `app_codebase/flutter_base_06/android/build.gradle.kts`
- `app_codebase/flutter_base_06/android/app/src/main/AndroidManifest.xml`
- `app_codebase/flutter_base_06/android/patches/in_app_purchase_android/MethodCallHandlerImpl.java`
- `app_codebase/flutter_base_06/lib/app_init.dart`
- `app_codebase/flutter_base_06/ios/Runner/Info.plist`

## Notes

Play’s target-API rule applies to the next Arcori App Bundle. The Billing Library rule applies only once the app actually ships `com.android.billingclient`. `minSdk` 23 drops Android 5.0 and 5.1 (API 21–22), the same device cut Dutch accepted for Billing 9.1.0. Android 6.0+ (API 23+) stays supported.

The patch copies plugin Java into the project build directory and replaces `queryProductDetailsAsync` so it reads `QueryProductDetailsResult.getProductDetailsList()`. The Pub cache file is not modified.

Portrait lock matches Dutch: `MainActivity` `screenOrientation="portrait"`, iPhone and iPad Info.plist portrait only with `UIRequiresFullScreen`, and `SystemChrome` `portraitUp` at startup (skipped on web). The Android 16 compat property keeps that lock on large screens until the layout can resize.

## Case study

n/a — store SDK floor, not a game-logic or architecture change.

## Task Manager

App Dev checklist: Play target API 36 + Billing 9.1.0 Gradle alignment. Portrait lock added on the same card.
