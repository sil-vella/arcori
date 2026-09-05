# Slam Aim + Game Controls

**Status:** Completed  
**Created:** 2026-09-05  
**Last Updated:** 2026-09-05

Related: [3d-slam-physics.md](3d-slam-physics.md) · [player-slam-input.md](player-slam-input.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Add a module-aligned **Game Controls** screen (equipped slammer + exclusive Accel/Touch mode) and wire slam aim so players can miss the stack (no kick) when the hit marker is outside the footprint.

Show the **current slam control mode** on the match screen with the same icon + label used on Game Controls.

## Decisions

| Decision | Choice |
|----------|--------|
| Settings surface | Full-screen `/game-controls` under Play module (routes + drawer) |
| Prefs | `equippedSlammerId` + `slamControlMode` (`accel` \| `touch`) via secure storage |
| Default mode | `accel` if motion available, else `touch` |
| Accel | XY moves marker; Z never aims; Z shake commits power |
| Touch | Drag aims; vertical swipe/pan-down commits power |
| Aim miss | Outside `kDiscRadius` (slammer-sized footprint) → miss, empty sim, no kick |
| Online loadout | `slammerId` on `matchmaking/find` |
| Practice | Defaults to equipped slammer |
| Match HUD | `SlamControlModeIndicator` — icon + label + caption; SSOT in `slam_control_mode_ui.dart` |

## Implementation Steps

- [x] Game Controls screen + prefs + registry route/drawer
- [x] Pass equipped `slammerId` on find; practice default
- [x] `aim: {x,z}` parse + resolveSlam aimMiss / kick-at-aim (Dart + Flutter)
- [x] Mode-gated capture; freeze aim on commit
- [x] Hit marker on stack (in/out footprint)
- [x] Tests + tech spec + TM sync
- [x] Match HUD shows current slam mode with icon (same SSOT as Game Controls)

## Current Progress

Match HUD shows Phone motion (`screen_rotation`) or Touch (`swipe_down`) for the whole match, using the same labels as Game Controls.

## Next Steps

None for this plan.

## Files Modified

- Flutter: `game_controls_prefs.dart`, `game_controls_screen.dart`, `play_routes.dart`, `play_drawer.dart`, `app_paths.dart`, `play_notifier.dart`, `practice_loadout_modal.dart`, slam input/capture/resolver/physics stack widgets
- Dart: `slam_input.dart`, `slam_resolver.dart`, `slam_physics_world.dart` (feel damping), `turn_pacing.dart`, tests
- Flutter HUD: `slam_control_mode_ui.dart`, `practice_match_surface.dart`, `slam_control_mode_ui_test.dart`

## Notes

- Modes are exclusive during gameplay (no simultaneous tilt+swipe).
- Catalog art on hit marker out of scope (simple ring).
- Task Manager: App Dev checklist for slam direction + Game Controls + match HUD mode indicator.

## Case study

n/a — HUD polish; no architecture/game-logic change.

## Task Manager

App Dev (`32`) checklist item `240`: Match HUD shows slam control mode + icon — checked.
