# Flutter intro video

**Status**: Completed  
**Created**: 2026-09-27  
**Last Updated**: 2026-09-27

## Objective
Replace the startup intro (bounce text / `intro.json`) with playback of `assets/videos/intro.mp4`. Keep the `lottie` package for later use.

## Implementation Steps
- [x] Add `video_player` and bundle `intro.mp4`
- [x] Play that asset from the startup intro and close when it ends or fails
- [x] Keep `lottie` and `SHOW_INTRO_LOTTIE`
- [x] Widget tests for play-through and playback failure ✅

## Current Progress
Intro screen plays `assets/videos/intro.mp4` full screen after the native splash when `SHOW_INTRO_LOTTIE` is truthy. Chrome playback is muted so autoplay is allowed. A failed load closes the intro instead of blocking startup. `intro.json` and the bounce screen are removed. The lottie package and `assets/lottie/` stay for later.

## Next Steps
None. Replace `assets/videos/intro.mp4` to change what plays.

## Files Modified
- `app_codebase/flutter_base_06/lib/core/intro/intro_video_screen.dart`
- `app_codebase/flutter_base_06/lib/core/config/app_config.dart`
- `app_codebase/flutter_base_06/lib/app_init.dart`
- `app_codebase/flutter_base_06/pubspec.yaml`
- `app_codebase/flutter_base_06/assets/videos/intro.mp4`
- `app_codebase/flutter_base_06/test/core/intro/intro_video_screen_test.dart`
- `.gitignore`
- `.env.dart.defines.local.sample`
- `.env.dart.defines.prod.sample`

## Notes
`SHOW_INTRO_LOTTIE` is unchanged so existing dart-defines still gate the intro. Samples still default it to off. The bundled clip is the existing `assets/videos/intro.mp4` (H.264, 720×1280). `*.mp4` stays gitignored, including this asset.

## Case study
n/a — startup intro, no architecture or game-logic change.

## Task Manager
App Dev checklist: Flutter intro video (intro.mp4)
