# Inventory Slammer + Disc Face Art

**Status**: Completed  
**Created**: 2026-09-05  
**Last Updated**: 2026-09-05

Related: [slam-aim-game-controls.md](slam-aim-game-controls.md) · [stub-match-arcori-selection.md](stub-match-arcori-selection.md) · [avari-profile.md](avari-profile.md)

## Objective

Game Controls and practice list **owned slammers** (`player_slammers`). Avari Profile shows that player's circulating Arcori (`player_design_access`) and owned slammers, with catalog art + color. Online Dart verifies the equipped slammer and freezes catalog values. Match discs show catalog `imageUrl` on the face with a slightly thick border from catalog `color`.

## Implementation Steps

- [x] Avari profile `access` / `slammers` enriched with catalog face fields; Profile UI lists them
- [x] Game Controls + practice slammer/arcori dropdowns use that inventory (not Velora index)
- [x] `POST /service/avari/verify_slammers` — owned id or fallback to permanent/first owned
- [x] Dart `startFromLobby` verifies then freezes catalog for slam values
- [x] Stamp `imageUrl` + `color` on table pieces from catalog freeze
- [x] Flutter disc: face art + catalog-color border
- [x] Stack: inset art so rim is not covered; back face inner hairline at rim
- [x] Back-face inner line auto-colors from fill (same hue; lighten dark backs, darken light backs)
- [x] Prefetch circulating Arcori art on Play screen load (not on flip)
- [x] Tests + tech spec / case study
- [x] Velora browse + Detail use `ArcoriCylinder` (catalog rim, not a plain crop)

## Current Progress

Complete. Stack discs inset the face so the catalog rim shows. Back-face inner hairline uses `arcoriBackInnerLineColor`. Play screen precaches circulating + practice art into `ImageCache`; face-down discs still mount `Image.network` so a flip does not start the download. Velora theme tiles and Arcori Detail hero use the same `ArcoriCylinder` as match / Avari.

## Next Steps

Celebration / Match Summary (master plan).

## Files Modified

- Python: `avari_service.py`, `avari_app.py`, catalog `design_summary` color, tests
- Dart: `match_avari_client.dart`, `match_service.dart`, `table_pieces.dart`, match tests
- Flutter: Avari models/profile/chip, Game Controls, practice loadout, disc, snapshot pieces, `arcori_look.dart`, `arcori_cylinder.dart`, `arcori_palette.dart`, `arcori_image_prefetch.dart`, `play_screen.dart`, Velora theme/detail

## Notes

- Online Arcori pick is unchanged: weighted/random among that seat’s circulating `player_design_access`.
- Unowned equipped slammer is not used; FastAPI returns an owned fallback (starter if present).
- Catalog freeze stays server-private; face fields ride on `table.pieces`.
- Velora was still a plain `ClipOval` crop; it now parses catalog `color` and paints `ArcoriCylinder` like the stack.
- `DecoratedBox` default paints behind the child, so a full-size `ClipOval` image hid the rim on the anim stack.
- Back inner line is not white/black: it stays the catalog hue and auto-shifts lightness (and a little saturation) from the fill.
- Catalog art is precached when Play opens (`collectArcoriArtUrls` + `precacheImage`). Face-down discs keep `Image.network` mounted under the back fill so flip is a cache hit.

## Case study

`03_CASE_STUDY.md` — owned slammer + circulating Arcori on profile; disc SSOT (art, rim, back, auto inner hairline).

## Task Manager

App Dev (task `32`): checklist **Inventory slammer + disc face** — item `238` checked. New line for stack rim + back inner line.
