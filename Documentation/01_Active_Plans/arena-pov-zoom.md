# Arena background locked to stack POV

**Status**: Completed  
**Created**: 2026-09-06  
**Last Updated**: 2026-09-06 (damped zoom follow)

Related: [match-arena-from-arcori.md](match-arena-from-arcori.md) · [3d-slam-physics.md](3d-slam-physics.md)

## Objective

When the stack zooms out to keep scattered discs on screen, the Velora arena mural follows the same camera. Zoom-out stops when the whole image is visible (`BoxFit.contain`). HUD stays unzoomed.

## Rule

- Rest is **zoomed in** on the table (crop around the stack). Max zoom-out is contain.
- The mural is laid out at `viewport / kStackPovFitMin` and decoded at that size. Camera scale is **1 at rest** and `kStackPovFitMin` at contain — only ever scales **down**. Upscaling a screen-fitted bitmap (old `1 / min` transform + `FilterQuality.medium`) made the table and Arcori look pixelated.
- Arcori paint at rest Ø (`worldScale` 1). They share the camera; rims stay vector-sharp.
- Arena art is **100% opaque** and **under** the discs (no dim scrim).
- HUD (hints, gauge, lock, aim hit-target) stays unzoomed.

## Architecture

| Layer | Owns |
|-------|------|
| `ArcoriStackSurface` | Emits `onPovScale`; with an arena, `applyFitZoom: false` and rest-sized paint |
| `ArenaPovBackdrop` | Oversized contain mural under the stack; camera = stack `fit` (1 → `kStackPovFitMin`) |
| Match HUD | Untransformed overlay (aim/lock sit in the 220px slot) |

## Implementation Steps

- [x] Active plan + App Dev checklist
- [x] Stack `onPovScale` + arena backdrop widget
- [x] Rest zoom-in so max stack zoom-out is contain (not cover)
- [x] Disc size in contain-space so mural and Arcori share one camera
- [x] Rest camera paints at 1:1 (no upscale); mural opaque under the stack
- [x] Zoom follow is critically damped (~0.75s); does not restart a short tween every fit tick

## Current Progress

Shipped: mural starts zoomed in on the table; slam pullback reaches contain at the stack’s fit floor. Rest view is sharp (oversized decode + scale-down only); table art is fully opaque under the discs. Camera eases with SmoothDamp so scatter pullback is not stepped.

## Next Steps

None for this pass.

## Files Modified

- `app_codebase/flutter_base_06/lib/modules/match/widgets/arena_pov_backdrop.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/arcori_stack_surface.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/practice_match_surface.dart`
- `app_codebase/flutter_base_06/test/modules/match/arena_pov_backdrop_test.dart`

## Notes

HUD (hints, gauge, lock, seats) does not share the camera. Zoom uses SmoothDamp (`kPovZoomSmoothTime` 0.75s) so fit ticks do not restart a 200ms tween.

## Task Manager

App Dev (`32`) checklist `245` / `249` / `251` (done) + notes `246` / `250` / `253`.

## Case study

Arena mural is the stack camera’s world plane: zoomed in at rest, contain at max zoom-out. Do not rasterize a contain-fitted screen bitmap and scale it up — layout the mural large, camera 1→min, discs at rest Ø, no scrim.
