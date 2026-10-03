# Kin Creation (start to finish)

**Status:** In Progress — client wizard + `POST /authuser/avari/kin` Genesis claim  
**Created:** 2026-09-05  
**Last Updated:** 2026-09-28

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

**Authoring split:** Lottie JSON is authored outside this app, stored under `assets/lottie/kin/ser001/{type}/` (e.g. `guardians`, `entelairs`, `walkies`) → public `/catalog-media/kin/ser001/{type}/{serial}.json` (`CATALOG_KIN_MEDIA_ROOT`). Serials are Arcori-style `KIN-{CODE}-SER001-{seq}` (e.g. `KIN-DRP-SER001-0011`). Client catalogs use `lottieUrl`. Local `KSAVE` copies are downloaded at save time. **Claimed** Kin writes **one design JSON + one Lottie per id** under uploads (`/media/kin/designs/{id}.json`, `/media/kin/players/{id}.json`) — never a shared category file. Velora theme `KIN` indexes those design files.

### Claim background bake (locked 2026-09-25)

Selectable claim backgrounds (solid / gradient / `00backgrounds` images) are **baked into the player Lottie** as the bottom `background` image layer (`asset_background`). They are **not** Flutter-overlaid at display time (Velora, Profile, match discs, inventory).

- **Entelairs:** template copper plate is layer `metallic_plate` (`asset_metallic_plate`). Claim BG sits under it. Legacy templates that still name the plate `background` are promoted on first bake.
- **Guardians / walkies / others:** claim BG is injected; no metallic plate.
- **Write path:** Flutter `bakeKinBackgroundIntoLottie` on human claim (client SSOT,
  no square-pad) and local KSAVE; server `bake_claim_background_into_lottie` only
  when no client Lottie (AI `feed_ai_players`). Metadata also stored on
  `player_kin.customization.background`.
- **Preview only:** customize screen may still use `KinSceneStack(scene: …)` as a live overlay on the **template** URL; save/claim produce the baked file.
- **Legacy claimed Lotties** without a baked BG need refeed/reclaim to pick up the bake.

### Claim payload (locked 2026-09-28 — client Lottie SSOT)

Human claim must match customize preview. Server rebuild (square-pad Entelair
canvas + re-tint) was cutting eyes / dropping arms relative to live preview.

1. **Client bakes** the claim face (embeds → part styles → background) with
   **no square pad** (`expandBackgroundToSquare: false`) — same geometry as
   customize preview.
2. **POST multipart**: `payload` (metadata JSON) + `lottie.gz` (gzipped baked
   JSON). Server **WebP-optimizes + uniform max-edge scale only**.
3. **AI feed** still omits Lottie → server loads catalog template and bakes
   embeds/styles/BG (server SSOT for that path only).
4. **nginx** `client_max_body_size 20m` on `api.arcori.app`.
5. Local KSAVE draft may still square-pad for disc fill; claim upload does not.

Authored templates are pre-shrunk (`automation/backend/shrink_kin_lottie_templates.py`).
Inline claim rasters end as **WebP** (`data:image/webp;base64,…`).


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
| `embeds.json` | Bundled fallback embed pool (`KEMB-*`) |

Parts list `allowedCustomSerials` and `embedPoolSerials`. UI and save filter reject anything not allowed.

### Hot additions (locked 2026-09-27)

Same posture as claim backgrounds: **no Flutter rebuild and no API container restart** to ship a new addition after the hot-fetch client is installed once.

| Piece | Location |
|-------|----------|
| Art + catalog | `assets/lottie/kin/ser001/00embeds/` → `/data/catalog-kin` (`CATALOG_KIN_MEDIA_ROOT`) |
| Specs | `00embeds/embeds.json` (read on every `GET /authuser/avari/kin/embeds`) |
| Public art URL | `/catalog-media/kin/ser001/00embeds/{fileName}` |

Each catalog row: `serial`, `displayName`, `fileName`, `attachments[]` with `kinSerial`, `partSerial`, and `placement` (`inFrontOf` **or** `behindLayer`, optional `p`/`s`). Client merges onto the bundled Kin catalog (injects pool + placement + `imageUrl`). Bake loads PNG bytes from that URL.

**Hue / lightDark** are not catalog fields — they are the existing per-selection tint UI (`CUS-0009` / `CUS-0010` inside the embedImage value map). New remote additions automatically get those sliders when selected.

**Authoring a new addition:** drop PNG under `00embeds/`, append a row to `embeds.json` (with attachments). Next Customize open refetches the list. Bundled `assets/kin/embeds*` remains offline fallback only.

**Image embeds (`CUS-0006` / `KEMB-*`):** each part that offers embeds also lists `embedPlacements` keyed by embed serial (bundled and/or hot-merged). Exactly one of `inFrontOf` or `behindLayer` (Lottie layer `nm`):

```json
"embedPlacements": {
  "KEMB-0001": { "inFrontOf": "metallic_plate", "p": [320, 400, 0], "s": [40, 40, 100] },
  "KEMB-0008": { "behindLayer": "body" }
}
```

Optional `p` / `s` default to composition center and 100% scale. Bake inserts a `ty=2` layer named `embed_<serial>`: **in front** = at target list index; **behind** = after target (`targetIdx + 1`). Lower list index = on top. Examples: Entelair wings → `inFrontOf: metallic_plate`; guardian halo/lightning/ball → `inFrontOf` frontmost eye; guardian spear → `behindLayer` body (rearmost). Without a valid placement, the embed is rejected.

**Additions (character-wide):** Customize UI has a dedicated **Additions** section (not under Head/Body tabs). Thumbnails in a **3-column equal grid** (image, not title). Multi-select any mix of `KEMB-*`; **only the focused (last-tapped) selected addition** shows hue / lightDark sliders. Each selected addition stores its own tint inside the `CUS-0006` value map on the catalog part that owns placement. Tint applies only to `embed_<serial>` layers. Part metal/eye hue/sat/lightDark stay on character layers and never retarget to additions.

**Guardians (`KEMB-0003`–`0014`):** primary art under `assets/lottie/kin/ser001/00embeds/guardians/{BRZ,GLD,IVY,SLV}/` (+ `embeds.json` attachments). Flutter `assets/kin/embeds/...` kept as fallback.

**Entelairs (`KEMB-0015`–`0027`):** hot + bundled pools on Head (`inFrontOf: metallic_plate`); art under `00embeds/entelairs/{ALC,ASP,HGD,HMG}/`.

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
       + **Save draft** (local KSAVE upsert; Continue reloads it)
  → Claim Kin → POST /authuser/avari/kin (also refreshes local KSAVE)
  → Profile shows server Kin (Lottie + disc)

Avari Profile → Continue Kin draft
  → /kin/customize?kin=<template>&resume=1
  → restore applied customs, name, region, color, background from active KSAVE
```

**Catalog JSON lock:** `catalog_design` uses the **same keys** as a regular Genesis design (e.g. Tiger in `animals.json`). Kin-only runtime stays in `customization`. Gen/series from catalog [`current_series.py`](../../app_codebase/python_base_05/bin/modules/catalog/current_series.py) (`CURRENT_SERIES`: Genesis / `SER001` / gen I) — bump that one dict for future minted designs.

## Live today (do not regress)

- Tables: `player_kin` (+ `catalog_design` JSONB) + onboarding flags
- `POST /authuser/avari/kin` claim; `GET /authuser/avari/profile` returns enriched kin
- Catalog `get_design` overlays player `KIN-*` from `player_kin.catalog_design`
- Flutter: customize region/color/name; claim; gate Create Kin when server kin present
- Test stub Lottie: `assets/lottie/kin/ser001/guardians/KIN-BRZ-SER001-0001.json` → `/catalog-media/kin/ser001/guardians/KIN-BRZ-SER001-0001.json`

## Implementation Steps

- [x] Bundled Kin creation catalogs (types, kins+parts, customs, embeds)
- [x] Flutter module `kin` routes: `/kin/types` → `/kin/kins` → `/kin/customize`
- [x] Avari Profile **Create Kin** + local draft / server Kin readout
- [x] Local save `KSAVE-*` (sidecar + lottie file via path_provider)
- [x] Unit tests: type filter, allow-list, save, style/bake
- [x] Drop in stub Kin Lottie on **backend** catalog-media (`assets/lottie/kin/ser001/guardians/KIN-BRZ-SER001-0001.json`)
- [x] LottieDelegates live preview (hue/sat/color)
- [x] Region + Arcori color + name on customize; claim `POST /authuser/avari/kin`
- [x] `catalog_design` key parity with regular Arcori; `02_kin.json` aligned
- [x] Claimed Kin is circulating catalog stock (`selectionWeight` 3.0) + creator `player_design_access` (`source=kin`)
- [x] Claim background baked into player Lottie (solid/gradient/image); Entelair `metallic_plate`; no Flutter scene overlay on display
- [x] Embed image additions: per-part `embedPlacements` (`inFrontOf` or `behindLayer`) + bake insert (preview + save)
- [x] Guardian addition PNGs as `KEMB-0003`–`0014`; non-spear in front of eye, spear behind body
- [x] Addition tint: `CUS-0009` / `CUS-0010` (embedHue / embedLightDark) on selected embed layer
- [x] Hot-add additions: `00embeds/embeds.json` + `GET /avari/kin/embeds` + client merge/bake from `imageUrl`
- [x] Customize preview perf: embed-only compose + PNG cache + signature; tint via delegates
- [x] Entelair additions `KEMB-0015`–`0027` in hot + bundled catalogs (`metallic_plate`)
- [x] Additions UI: image thumbs, 3-col grid, focused-only hue/light sliders
- [x] Claim payload slim: server bake + template shrink + bake downscale + gzip/multipart + nginx 20m
- [x] Save draft on customize + Continue Kin draft restores session (`resume=1`)
- [x] Addition bake: keep full authored canvas (no independent 512 shrink / no opacity trim); uniform scale only
- [ ] Replace stub with externally authored Bronze Genie Lottie (same backend path)
- [ ] Adjustments + predefined animations on designated layers
- [ ] Gate Create Kin when server Kin already claimed (UI done; product polish)
- [ ] First-time starter grants (separate: [first-time-player-flow.md](first-time-player-flow.md))

## Current Progress

Client wizard + server Genesis claim shipped. Per-Kin design + Lottie files under `/media/kin/`. Velora theme `KIN` lists claimed Kins. Catalog design mirrors regular Arcori field-for-field. Claim grants the creator circulating play/mastery access so the Kin is selectable match stock. **Claim backgrounds are baked into the player Lottie** (not overlaid in Flutter); Entelair copper is `metallic_plate`.

**Claim size:** client no longer POSTs the Lottie; server `build_claim_lottie` loads the catalog template, applies embeds/styles/BG, and optimizes. Catalog templates were pre-shrunk (~47%). nginx edge needs `client_max_body_size 20m` (repo conf updated — rewrite on next deploy).

**Embed additions (`CUS-0006`):** parts may list `embedPlacements` with exactly one of `inFrontOf` / `behindLayer` (+ optional `p`/`s`). Bake inserts `embed_<serial>` as a `ty=2` layer on the chosen side of the target; save + live customize preview share that bake. Missing placement → reject. Guardians (`KEMB-0003`–`0014`) and Entelairs (`KEMB-0015`–`0027`) live in hot catalog `00embeds/` (API merge) with Flutter `assets/kin/embeds` fallback. Entelair placement: `inFrontOf: metallic_plate`.

## Next Steps

Deploy API image + **rewrite nginx** (20m body). Redeploy Flutter so claim uses gzip metadata-only. Designated-layer idle animations. Alembic `013` in target envs. Do not block Celebration / Match Summary.

## Files Modified

- `app_codebase/flutter_base_06/lib/modules/kin/**`
- `app_codebase/flutter_base_06/assets/kin/embeds.json`
- `app_codebase/flutter_base_06/assets/kin/kins.json`
- `app_codebase/flutter_base_06/assets/kin/embeds/ser001/guardians/**` (fallback)
- `assets/lottie/kin/ser001/00embeds/**` (hot catalog)
- `app_codebase/flutter_base_06/lib/modules/kin/kin_embed_catalog.dart`
- `app_codebase/python_base_05/bin/modules/avari/kin_embeds.py`
- `app_codebase/flutter_base_06/test/modules/kin/kin_lottie_embed_test.dart`
- `app_codebase/flutter_base_06/test/modules/kin/kin_embed_catalog_test.dart`
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

## Case study

`03_CASE_STUDY.md` — Kin additions hot-catalog like backgrounds (decision table).

## Task Manager

Skipped this turn — credentialed TM sync blocked by auto-review; local plan/case study updated.

## Notes

- **Hot additions:** after one Flutter deploy with fetch/merge, new rows in `00embeds/embeds.json` + PNGs appear on next Customize open (no rebuild/restart). Hue/lightDark are selection tint, not catalog defaults.
- **Not in this plan:** 10 circulating starter access, permanent slammer grant, guided practice, intros, Home sink.
- Claimed Kin **is** match stock: Active catalog design + `player_design_access` for the creator (`source=kin`). Select resolves via `get_design` (design file / DB), not static JSON only. Other players still need grants (starter / packs) to select it.
- Local saves: documents `kin_saves/` + secure-storage active `KSAVE` serial.
- Customize preview: embed insert only (compact JSON) + live `LottieDelegates` for part/addition tint; recomposes when selected addition serials change (PNG bytes cached). Save/claim still full pixel bake of styles + claim background.
- Disc rim/back = catalog `color` from the 10 predefined Arcori accents (same as inventory discs).
