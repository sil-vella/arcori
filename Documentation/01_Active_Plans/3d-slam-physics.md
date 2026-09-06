# 3D Slam Physics

**Status:** Completed  
**Created:** 2026-09-04  
**Last Updated:** 2026-09-06

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
- [x] Tumble / rest yaw — `restingOrientationFrom`; kick rolls ⟂ slam; client keeps spin
- [x] Rest/stack lie flat in view — physics Y-up yaw conjugated to screen Z (in-plane spin, not tip)
- [x] Flat rest keeps painted face toward camera (yaw-only view; art vs back from faceUp)
- [x] Restack uses table face-down (client settle); physics pulls off the rim mid-sim
- [x] More air tumble before land — delayed flatten + higher kick/hop
- [x] Full-stack kick — every face-down disc gets a direct hit; ~5% less per layer

**Tumble / rest yaw (2026-09-06):** settle keeps in-plane spin (`restingOrientationFrom`); kick rolls ⟂ slam + yaw; no world-X edge assist. Client no longer nlerps to identity / π-X after replay.

**Flat rest in view (2026-09-06):** applying physics yaw around Y directly to the disc widget tipped coins on edge (widget face is Z). `physicsToViewQuat` conjugates by +90° around X so rest and stack stay full circles; heading from just before flatten is kept. Last sim frame is exact rest.

**Rim linger (2026-09-06):** `_assistFaceSettle` now pulls toward the nearer face after flatten starts (not only damping). Snap blend 28 frames. Restack leftover face-up was **client**: settle ORed live slam quat with restacked `faceUp:false`. Backend `restackFaceDown` was already clean (next slam starts ny=-1).

**Air tumble (2026-09-06):** flatten used to start ~step 14 and ate mid-air flips. Strong slams now free-tumble until step 38, then ramp flatten over 22 steps. Balanced kick is hotter (`angularKickScale` 1.65, `tipMul` 2.55, `maxAngSpeed` 11, extra hop) so flips read before land; late pull still kills rim stands.

**Full-stack kick (2026-09-06):** every face-down disc gets the same kind of slam as the top (`affectBudget` no longer 1–2). Falloff is ~5% per layer (`kStackDepthKickFade`). `spread` still fans pieces; it no longer gates who gets a flip impulse. Weak taps still rarely wipe because power itself is tiny.

## Current Progress

Completed. Soft miss / restack / result modal / turn pacing unchanged. Flip outcomes differ from Forge2D (expected).

## Next Steps

Celebration / Match Summary / rewards. Aim + Game Controls shipped separately — [slam-aim-game-controls.md](slam-aim-game-controls.md).

**Feel pass (2026-09-04):** softer continuous kicks (no micro-nudge); score **only** settled face normal after hemisphere snap (`kFaceUpDot ≈ 0.18`); stronger angular tumble; punch-through shoves face-up tops aside; soft-miss `0.005`; easier swipe/shake commit; softer AI speeds.

**Default feel (2026-09-05):** `kDefaultSlamFeelProfile` = **`balanced`** (prior high/`flippy` values; `flippy` remains the higher lever).

**Scatter / settle (2026-09-04):** wider fan-out + higher linear kick; lower angular kick + mid-step face assist (less edge linger); near-zero restitution / stronger damping; quiet exit sooner (`maxSteps=110`); settleHold `1600ms` + pad `300ms`.

**Anim timing (2026-09-04):** server `postSlamAnimHold` = `steps×dt + settleHold + pad` from `outcome.sim.animHoldMs`. Client replays sim 1:1 with steps then holds `settleHoldMs` before snap.

**Tumble / rest yaw (2026-09-06):** settle keeps in-plane spin (`restingOrientationFrom`); kick rolls ⟂ slam + yaw; no world-X edge assist. Client no longer nlerps to identity / π-X after replay. Dead-above view conjugates physics Y-up into screen Z so rest/stack stay flat circles.

## Files Modified

- `app_codebase/dart_bkend_base_02/pubspec.yaml` (forge2d → vector_math)
- `app_codebase/dart_bkend_base_02/bin/modules/match/slam_physics_world.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/slam_resolver.dart`
- `app_codebase/dart_bkend_base_02/test/slam_resolver_test.dart`
- `app_codebase/flutter_base_06/pubspec.yaml` (forge2d → vector_math)
- `app_codebase/flutter_base_06/lib/modules/match/input/slam_physics_world.dart`
- `app_codebase/flutter_base_06/lib/modules/match/input/slam_resolver.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/arcori_disc.dart`
- `app_codebase/flutter_base_06/test/modules/match/arcori_disc_test.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/arcori_stack_surface.dart`
- `Documentation/Game_Specific/Arcori_Technical_Specification_v0.4.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/03_CASE_STUDY.md`

## Notes

- Pose wire: `sim.space = "xyzq"`; clients ignore non-xyzq / short legacy poses.
- Table: XZ ground, Y up; stack along Y; soft walls ±3.5.
- Disc size: Ø50mm × 3mm (`kDiscRadius=0.025`, `kDiscHalfHeight=0.0015`); `pxPerMeter=1440`.
- Flutter POV: dead-above (`viewPitch=0`); when flat, `discViewQuat` is yaw-only so catalog art stays on camera.
- No three_js / Glint / Flutter GPU in the match HUD.

## Case study

Recorded in [03_CASE_STUDY.md](03_CASE_STUDY.md) — §4.6 + major decisions (Forge2D → 3D SSOT).

## Task Manager

Synced 2026-09-06 on **App Dev** (`32`): restack-client `256` + rim pull `257`; notes `258`. Air tumble `259`/`260`. Full-stack kick checklist `261` + note `262`.
