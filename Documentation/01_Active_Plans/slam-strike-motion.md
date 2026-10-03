# Slam strike wind-up and hit

**Status**: Completed  
**Created**: 2026-10-03  
**Last Updated**: 2026-10-03

## Objective

Give the play-screen slam a two-phase wind-up (slow approach while growing, then a fast hit that returns to rest size), vibrate on stack contact, and play the hit through a client audio module ported from Dutch’s keyed one-shot player onto this app’s module registry.

## Implementation Steps

- [x] Two-phase travel/scale pure functions + 800ms strike hold (Flutter + Dart turn pacing)
- [x] Wire fly-in clock to raw `AnimationController` (no easeInCubic / squash)
- [x] Client `audio` module (catalog, playback outcomes, `registerAudioModule`)
- [x] `just_audio` dependency; `slam_hit` registered with no clip yet
- [x] On fly-in complete: `HapticFeedback.heavyImpact` + `play('slam_hit')`
- [x] Unit tests for motion midpoint/end and mute / no-clip / unknown cue

## Current Progress

Shipped. Stack hit still drives scatter via `onFlyInComplete`. Filling `kAudioCueAssets['slam_hit']` with an asset path is the only change needed to hear a clip.

## Next Steps

- Choose and ship a slam-hit mp3 under `assets/audio/` and set the catalog path.

## Files Modified

- `app_codebase/flutter_base_06/lib/modules/match/widgets/slam_strike_motion.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/slammer_strike_overlay.dart`
- `app_codebase/flutter_base_06/lib/modules/match/input/turn_pacing.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/turn_pacing.dart`
- `app_codebase/flutter_base_06/lib/modules/audio/*`
- `app_codebase/flutter_base_06/lib/modules/module_registry.dart`
- `app_codebase/flutter_base_06/pubspec.yaml` / `pubspec.lock`
- `app_codebase/flutter_base_06/test/modules/match/slam_strike_motion_test.dart`
- `app_codebase/flutter_base_06/test/modules/audio/audio_playback_test.dart`

## Notes

- Dutch `AudioModule` API (keyed assets, overlapping one-shots, mute) kept; host is Riverpod + `registerApplicationModules`, not Provider `ModuleBase`.
- Playback returns `{module}/{reason}` codes (`audio/no_clip`, `audio/muted`, …). Missing clips log and return; they do not throw into the slam path.
- Task Manager: App Dev checklist.

## Case study

Major decisions: client audio module + two-phase slam strike — [03_CASE_STUDY.md](03_CASE_STUDY.md) §18.

## Task Manager

App Dev checklist item `357`: Slam strike wind-up + client audio module (done)
