# Firebase Analytics Implementation Plan

**Status**: Completed  
**Created**: 2026-07-04  
**Last Updated**: 2026-07-04

## Objective

Wire Firebase GA4 into `flutter_base_06` with compile-time config from `.env.dart.defines.*`, master `FIREBASE_SWITCH`, platform bootstrap events, and auth funnel events (guest bootstrap, login, guest→full conversion).

## Implementation Steps

- [x] `firebase_options.dart` + `firebase.json` (dart-define SSOT)
- [x] `firebase_core` / `firebase_analytics` pins; Android Gradle + iOS Podfile
- [x] `lib/core/analytics/` (FirebaseRuntimeConfig + AnalyticsService)
- [x] Firebase init + platform bootstrap events in `app_init.dart`
- [x] `FIREBASE_*` keys in env samples; web disable in `launch_chrome.sh`
- [x] Unit tests, `FIREBASE_IMPLEMENTATION.md`, `wfsecrets.md`
- [x] Auth funnel events in `lib/modules/auth/auth_analytics.dart`

## Current Progress

Firebase GA4 is wired with platform bootstrap and auth conversion events. Enable analytics by setting `FIREBASE_SWITCH=true` and using real native configs.

## Next Steps

- Verify auth events in Firebase DebugView (cold start, sign in, create account, guest convert).
- Add further module-specific events via `*_analytics.dart` helpers when product needs them.

## Files Modified

- `app_codebase/flutter_base_06/lib/firebase_options.dart`
- `app_codebase/flutter_base_06/firebase.json`
- `app_codebase/flutter_base_06/lib/core/analytics/firebase_runtime_config.dart`
- `app_codebase/flutter_base_06/lib/core/analytics/analytics_service.dart`
- `app_codebase/flutter_base_06/lib/app_init.dart`
- `app_codebase/flutter_base_06/pubspec.yaml`
- `app_codebase/flutter_base_06/android/settings.gradle.kts`
- `app_codebase/flutter_base_06/android/app/build.gradle.kts`
- `app_codebase/flutter_base_06/ios/Podfile`
- `app_codebase/flutter_base_06/ios/Runner/GoogleService-Info.plist.sample`
- `app_codebase/flutter_base_06/.gitignore`
- `app_codebase/flutter_base_06/test/core/analytics/analytics_service_test.dart`
- `.env.dart.defines.local.sample`
- `.env.dart.defines.prod.sample`
- `automation/frontend/launch_chrome.sh`
- `Documentation/03_Base/FIREBASE_IMPLEMENTATION.md`
- `app_codebase/flutter_base_06/lib/modules/auth/auth_analytics.dart`
- `app_codebase/flutter_base_06/lib/core/state/auth/auth_providers.dart`
- `app_codebase/flutter_base_06/lib/modules/auth/widgets/register_form.dart`

## Notes

- Native `google-services.json` / `GoogleService-Info.plist` are gitignored; copy from samples before Android/iOS builds.
- Web analytics intentionally disabled via `launch_chrome.sh`.
