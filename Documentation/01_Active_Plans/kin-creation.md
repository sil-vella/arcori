# Kin Creation (start to finish)

**Status:** In Progress — client wizard + `POST /authuser/avari/kin` Genesis claim  
**Created:** 2026-09-05  
**Last Updated:** 2026-09-07

Related: [first-time-player-flow.md](first-time-player-flow.md) · [avari-profile.md](avari-profile.md) · [player-profile-schema.md](player-profile-schema.md) · [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Visual / Lottie contract (locked 2026-09-07)

Kin is a **layered, editable character**, not a single baked PNG. Flattened catalog art remains the **reference** the layers must reconstruct. Runtime presentation is an **editable Lottie composition** built from those layers.

### Pipeline (source art → runtime)

1. **Separate** each character into complete **transparent PNG body-part layers**.
2. **Align** those layers so they recreate the original flattened character as closely as possible.
3. **Host** template Lotties on the **backend** (`/catalog-media/kin/…`). Flutter never bundles template Lotties.
4. **Customize at runtime:** colors, hue/saturation, embedded images, interchangeable parts.
5. **Animate only designated layers**, using **predefined movements** (no freeform motion on arbitrary layers).

Flutter already ships `lottie` for playback. Kin uses `Lottie.network` via `resolveMediaUrl` — do not add a second animation stack. Template Lotties live on the **host** under repo `assets/lottie/kin/` (Docker → `/data/catalog-kin`); do **not** put them under Flutter’s `app_codebase/flutter_base_06/assets/lottie/` (that would bundle them into the app).

**Authoring split:** Lottie JSON is authored outside this app, stored under `assets/lottie/kin/gen001/{type}/` (e.g. `guardians`, `entelairs`, `walkies`) → public `/catalog-media/kin/gen001/{type}/{serial}.json` (`CATALOG_KIN_MEDIA_ROOT`). Serials are Arcori-style `KIN-{CODE}-GEN001-{seq}` (e.g. `KIN-DRP-GEN001-0011`). Client catalogs use `lottieUrl`. Local `KSAVE` copies are downloaded at save time. **Claimed** Kin writes **one design JSON + one Lottie per id** under uploads (`/media/kin/designs/{id}.json`, `/media/kin/players/{id}.json`) — never a shared category file. Velora theme `KIN` indexes those design files.

Runtime knobs live on `player_kin.customization` (JSONB). Mirrored catalog design lives on `player_kin.catalog_design` (same keys as a regular Genesis Arcori).

### Asset rules (all future separated Kin parts)

Every new separated asset must:

- Use the **same scale and orientation** as the original character.
- Include **complete concealed joints** so limbs can move without gaps.
- Keep **consistent anchor / joint positions** across parts and variants.
- **Avoid baked-in overlapping body parts** (overlap comes from layer order in the rig, not from pixels on a part).
- Keep **transparent padding** where rotation needs it.
- Preserve **identical lighting, outlines, and shadows**.
- Be labeled by **anatomical left/right** (the character’s left/right, not screen left/right).
- **Reassemble cleanly** into a near-identical copy of the original flattened image.

If a part cannot sit back on the flattened original at the same scale, it is not ready to import.

## Client creation catalog (serials)

Bundled under `app_codebase/flutter_base_06/assets/kin/`:

| File | Contents |
|------|----------|
| `types.json` | Kin types / lineages (`KTYPE-*`) |
| `kins.json` | Template Kins + parts (`KIN-*`, `KPART-*`) |
| `customs.json` | Customs (`CUS-*`) with `customType` |
| `custom_types.json` | Enum docs: hue, saturation, color, embedImage, swapPart |
| `embeds.json` | Embed / swap pool (`KEMB-*`) |

Parts list `allowedCustomSerials` and `embedPoolSerials`. UI and save filter reject anything not allowed.

## Objective

Ship Kin creation end to end: Flutter wizard → claim Genesis Kin Arcori (region + disc color + customs) → `player_kin` + mirrored `catalog_design` → Avari profile refresh.

## Flow

```text
Avari Profile → Create Kin
  → Kin types (KTYPE-*)
  → Kins of that type (KIN-*)
  → Customize:
       name + region (no RBY) + Arcori palette color (rim/back)
       + allowed parts / CUS-*
  → Local KSAVE (optimistic) + POST /authuser/avari/kin
  → Profile shows server Kin (Lottie + disc)
```

**Catalog JSON lock:** `catalog_design` uses the **same keys** as a regular Genesis design (e.g. Tiger in `animals.json`). Kin-only runtime stays in `customization`. Gen/series from catalog [`current_series.py`](../../app_codebase/python_base_05/bin/modules/catalog/current_series.py) (`CURRENT_SERIES`: Genesis / `GEN001` / gen I) — bump that one dict for future minted designs.

## Live today (do not regress)

- Tables: `player_kin` (+ `catalog_design` JSONB) + onboarding flags
- `POST /authuser/avari/kin` claim; `GET /authuser/avari/profile` returns enriched kin
- Catalog `get_design` overlays player `KIN-*` from `player_kin.catalog_design`
- Flutter: customize region/color/name; claim; gate Create Kin when server kin present
- Test stub Lottie: `assets/lottie/kin/gen001/guardians/KIN-BRZ-GEN001-0001.json` → `/catalog-media/kin/gen001/guardians/KIN-BRZ-GEN001-0001.json`

## Implementation Steps

- [x] Bundled Kin creation catalogs (types, kins+parts, customs, embeds)
- [x] Flutter module `kin` routes: `/kin/types` → `/kin/kins` → `/kin/customize`
- [x] Avari Profile **Create Kin** + local draft / server Kin readout
- [x] Local save `KSAVE-*` (sidecar + lottie file via path_provider)
- [x] Unit tests: type filter, allow-list, save, style/bake
- [x] Drop in stub Kin Lottie on **backend** catalog-media (`assets/lottie/kin/gen001/guardians/KIN-BRZ-GEN001-0001.json`)
- [x] LottieDelegates live preview (hue/sat/color)
- [x] Region + Arcori color + name on customize; claim `POST /authuser/avari/kin`
- [x] `catalog_design` key parity with regular Arcori; `02_kin.json` aligned
- [x] Claimed Kin is circulating catalog stock (`selectionWeight` 3.0) + creator `player_design_access` (`source=kin`)
- [ ] Replace stub with externally authored Bronze Genie Lottie (same backend path)
- [ ] Adjustments + predefined animations on designated layers
- [ ] Gate Create Kin when server Kin already claimed (UI done; product polish)
- [ ] First-time starter grants (separate: [first-time-player-flow.md](first-time-player-flow.md))

## Current Progress

Client wizard + server Genesis claim shipped. Per-Kin design + Lottie files under `/media/kin/`. Velora theme `KIN` lists claimed Kins. Catalog design mirrors regular Arcori field-for-field. Claim grants the creator circulating play/mastery access so the Kin is selectable match stock.

## Next Steps

Production Bronze Genie Lottie drop-in. Designated-layer idle animations. Alembic `013` in target envs. Do not block Celebration / Match Summary.

## Files Modified

- `app_codebase/flutter_base_06/lib/modules/kin/**`
- `app_codebase/flutter_base_06/lib/modules/avari/**`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/arcori_palette.dart`
- `app_codebase/python_base_05/bin/modules/avari/**`
- `app_codebase/python_base_05/bin/modules/catalog/catalog_service.py`
- `app_codebase/python_base_05/bin/modules/catalog/data/02_kin.json`
- `app_codebase/python_base_05/bin/models/player_progress.py`
- `app_codebase/python_base_05/alembic/versions/013_player_kin_catalog_design.py`
- `Documentation/01_Active_Plans/kin-creation.md`
- `Documentation/01_Active_Plans/03_CASE_STUDY.md`
- `Documentation/01_Active_Plans/player-profile-schema.md`

## Notes

- **Not in this plan:** 10 circulating starter access, permanent slammer grant, guided practice, intros, Home sink.
- Claimed Kin **is** match stock: Active catalog design + `player_design_access` for the creator (`source=kin`). Other players still need grants (starter / packs) to select it.
- Local saves: documents `kin_saves/` + secure-storage active `KSAVE` serial.
- Customize preview applies live `LottieDelegates`; save bakes fills; claim posts baked Lottie JSON.
- Disc rim/back = catalog `color` from the 10 predefined Arcori accents (same as inventory discs).
