# 3D Slam Physics

**Status:** Completed  
**Created:** 2026-09-04  
**Last Updated:** 2026-09-04

Related: [2d-slam-physics.md](2d-slam-physics.md) · [arcori-slam-impact.md](arcori-slam-impact.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Replace the Forge2D side-view (2D) slam sim with a **pure-Dart 3D thin-cylinder** world so discs move in `x/y/z` with full quaternion orientation. Keep the match SSOT pattern: Dart resolves → `outcome.sim` pose timeline → all clients replay. Flutter practice mirrors the same world.

## Decision

| Option | Result |
|--------|--------|
| Keep Forge2D + richer 2.5D paint | Rejected — not true 3D physics |
| `cannon_physics` 0.0.3 | Rejected — pubspec requires Flutter SDK (Docker Dart backend cannot depend on it) |
| FFI engines (Rapier / Glint Box3D) | Rejected — same Docker/FFI constraint as forge2d 0.15 |
| **Owned pure-Dart thin-cylinder / OBB solver** | **Chosen** — `vector_math` only; deterministic; Docker-safe |

## Implementation Steps

- [x] Spike: headless Dart world (no Flutter) — cylinders on table, seeded kicks, face-normal
- [x] Replace `slam_physics_world.dart` (Dart + Flutter mirror); wire `space: "xyzq"` frames `[id,x,y,z,qx,qy,qz,qw]`
- [x] Map swipe `dx/dy` → world X / −Y / −Z kick + angular tumble on X/Z
- [x] Face-up = local +Y · world +Y ≥ threshold (or tumble ≥ ¾π); already-up stays up
- [x] `ArcoriStackSurface` nlerp quaternions; dead-above (XZ→screen, pitch 0); ignore legacy 2D frames
- [x] `ArcoriDisc` full-circle face + rear thickness; no pitch foreshortening when settled
- [x] Tests + tech spec + case study + master plan

## Current Progress

Completed. Soft miss / restack / result modal / turn pacing unchanged. Flip outcomes differ from Forge2D (expected).

## Next Steps

Celebration / Match Summary / rewards. Aim + Game Controls shipped separately — [slam-aim-game-controls.md](slam-aim-game-controls.md).

**Feel pass (2026-09-04):** softer continuous kicks (no micro-nudge); score **only** settled face normal after hemisphere snap (`kFaceUpDot ≈ 0.18`); stronger angular tumble; punch-through shoves face-up tops aside; soft-miss `0.005`; easier swipe/shake commit; softer AI speeds.

**Default feel (2026-09-05):** `kDefaultSlamFeelProfile` = **`balanced`** (prior high/`flippy` values; `flippy` remains the higher lever).

**Scatter / settle (2026-09-04):** wider fan-out + higher linear kick; lower angular kick + mid-step face assist (less edge linger); near-zero restitution / stronger damping; quiet exit sooner (`maxSteps=110`); settleHold `1600ms` + pad `300ms`.

**Anim timing (2026-09-04):** server `postSlamAnimHold` = `steps×dt + settleHold + pad` from `outcome.sim.animHoldMs`. Client replays sim 1:1 with steps then holds `settleHoldMs` before snap.

## Files Modified

- `app_codebase/dart_bkend_base_02/pubspec.yaml` (forge2d → vector_math)
- `app_codebase/dart_bkend_base_02/bin/modules/match/slam_physics_world.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/slam_resolver.dart`
- `app_codebase/dart_bkend_base_02/test/slam_resolver_test.dart`
- `app_codebase/flutter_base_06/pubspec.yaml` (forge2d → vector_math)
- `app_codebase/flutter_base_06/lib/modules/match/input/slam_physics_world.dart`
- `app_codebase/flutter_base_06/lib/modules/match/input/slam_resolver.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/arcori_disc.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/arcori_stack_surface.dart`
- `Documentation/Game_Specific/Arcori_Technical_Specification_v0.4.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/03_CASE_STUDY.md`

## Notes

- Pose wire: `sim.space = "xyzq"`; clients ignore non-xyzq / short legacy poses.
- Table: XZ ground, Y up; stack along Y; soft walls ±3.5.
- Disc size: Ø50mm × 3mm (`kDiscRadius=0.025`, `kDiscHalfHeight=0.0015`); `pxPerMeter=1440`.
- Flutter POV: dead-above (`viewPitch=0`), round table pad, settled discs as full circles.
- No three_js / Glint / Flutter GPU in the match HUD.

## Case study

Recorded in [03_CASE_STUDY.md](03_CASE_STUDY.md) — §4.6 + major decisions (Forge2D → 3D SSOT).

## Task Manager

Synced 2026-09-04 on **App Dev**: checked off 3D slam / POV / anim-lock / modal+replay fixes / feel profiles; open checklist **slam direction miss-stack**; updated Next note.
