# Arcori Technical Specification

Working Draft v0.4  
**Last aligned:** 2026-09-13 (Mastery Value Fair→Priceless label)

## Arcori Model

Fields: internalId, themeCode, designCode, designFamily, design, inspiration, regionCode, affinity[], hostility[], generation{roman,number,creator}, type, theme, subtheme, style, finish, effect, selectionWeight (0.01 rarest … 10.00 most common), series, worldState, seasonState, artworkPrompt, loreDescription, legacy{preservationRequirement, closureMilestone}. No printedRarity.

**Natural selection (catalog / circulation):** each design’s **`selectionWeight`** (0.01–10.00) is the sole how-often signal. Higher = more common / more often selected. There is no printed-rarity table (`03_printed_rarity.json` removed).

**Match Arcori pairing SSOT:** after players are seated, `04_selection_weights.json` supplies **region standing** multipliers only. Seat pick score = design `selectionWeight` × region multiplier (hostility boosts match chance). Service: `POST /service/catalog/select_arcori`. Candidates = that player's DB `player_design_access` ids that resolve circulating via `get_design` (static catalog + player Kin) **and** have mastery > 0 (own Kin floored at 100). **Unique ids across seats:** when assigning seat N, exclude Arcori already chosen by seats 0..N−1 (fallback random only among remaining candidates). Weight/parse failures → random among **those** candidates only — never the global circulating catalog. Empty player access → empty pick (client/Dart stub may fill Tiger). Trove mints are ownership-only and are not match stock.

**Mastery ↔ access:** gaining +mastery on another player's design grants circulating access (`source=mastery`). Hitting 0 mastery revokes access, except the creator's own Kin (starts/floors at 100). Other players treat Kin like any Arcori on the other-flip curve. On Avari profile create (guest/regular), **starter** pack = 10 designs from **Genesis + Pioneers** only (not Creation / Foundations): **9** with `selectionWeight` in **[8.0, 10.0]** and **1** with **[3.0, 4.0]**, each at **10** mastery (`source=starter`) + permanent starter slammer. All **Pioneers** seeds use weight **10.0**; **Creation** uses **0.01**. Pool still drops designs at mastery < 1.

**Match arena + Gatherer (Quick Start / Invite):** after those Arcori ids exist, `POST /service/catalog/select_arena` counts `location.regionCode`. Two or more from the same region → random arena in that region. All different (or no majority) → random catalog region that has arenas, then a random arena. In the same response, after `chosen_region` is known, pick a non-player **Gatherer** Arcori: circulating static catalog designs in that region (any series), excluding SLM/KIN/slammer and all seated `arcoriIds`, weighted by each design’s `selectionWeight`. Snapshot fields: `arenaId` + `arenaImageUrl` (`/catalog-media/velora/arenas/{slug}/{arenaId}.webp`) + optional `gathererArcoriId` (fail closed: omit if pool empty). Gatherer is frozen with seat discs; it is **not** a `MatchSeat`. **Special Event** / Practice do not use this pick. Rematch re-runs arena+Gatherer with the new seated picks.

**Match slam / table:** at start, `table.pieces` holds one face-down disc per seat (`designId` from `arcoriIds`, plus catalog `imageUrl` and `color` stamped from the freeze). Match create picks random **`firstSeatIndex`** (wire field); turn order wraps `(first + offset) % seats` every round. `match/action` slam resolves via a **pure-Dart 3D thin-cylinder** sim (Dart SSOT; Flutter practice mirrors) from **verified** frozen slammer `gameplayAttributes` + raw `input` (`speed`, `aim: {x,z}`, optional `source`) → `result: flip|miss`, `outcome.impulse`, `outcome.sim` (`space: "xyzq"` pose timeline `[id,x,y,z,qx,qy,qz,qw]`), score deltas, then **restack face-down** so the next seat always starts from a clean stack. **Aim outside** stack footprint (`kDiscRadius`, same as the slammer) → **aimMiss** (no kick, empty sim) — distinct from soft-miss (`power ≈ 0`). Kick direction is biased from aim contact when inside the footprint. Round advance still increments `round`. **All clients** replay `outcome.sim` on the stack surface (spring impulse only if sim missing/empty; legacy 2D frames ignored). Face-up discs show catalog artwork with a slightly thick rim from design `color` (art is inset so the rim is not covered). Face-down backs fill with that color; the inner hairline is the same hue with auto lightness/saturation (`arcoriBackInnerLineColor`: dark fill → lighter line, light fill → darker line). Catalog art is precached when the Play screen loads (player circulating access + slammers + practice stubs); face-down stack discs still mount `Image.network` so a flip does not start the download. **Acting player only** gets a non-blocking 3s result `AppModal` (`FLIP`/`MISS`, flip count, score delta; X or auto-close) — turn clock is not paused. Scores/faces only from authority. Face-up = local face normal · world up (or tumble ≥ ¾π).

**Game Controls / slam modes:** Flutter `/game-controls` lists **owned** slammers from Avari `player_slammers` (not the Velora catalog). Persists `equippedSlammerId` + exclusive `slamControlMode` (`accel` \| `touch`). Default: accel if motion sensors available, else touch. Online `matchmaking/find` sends `slammerId`; Dart `POST /service/avari/verify_slammers` accepts it only if owned, else the player's permanent/first slammer, then freezes catalog attrs. Practice loadout uses the same owned slammers + circulating `player_design_access`. **Accel:** XY aims hit marker, Z shake commits power. **Touch:** drag aims, swipe commits power. Hit marker shown while armed (miss-zone tint outside footprint). Match HUD shows the equipped mode with the same icon + label as Game Controls (`SlamControlModeIndicator`).

**Avari inventory:** `GET /authuser/avari/profile` `access` = circulating play/mastery designs (catalog `displayName` / `imageUrl` / `color`); `slammers` = owned slammer instances with the same face fields. Profile UI shows those lists only — not the global Velora catalog.

**Velora browse:** theme tiles and Arcori Detail hero use the same `ArcoriCylinder` as the match stack (catalog `imageUrl` inset, rim from catalog `color`).

## Architecture

| Layer | Role |
|-------|------|
| **Arcori Catalog** | Immutable design definitions (+ media); JSON under `modules/catalog/data/`; served authuser via mtime-cached loader (see [catalog-hot-reload.md](../01_Active_Plans/catalog-hot-reload.md)) |
| **Region Catalog** | Politics and geography — five launch regions in `01_regions.json` |
| **Standings** | Live per-design community state for the **active** generation (mastery ranks, generation fill, leader window) |
| **Museum** | World historical snapshots of **closed** generations (factual archive) |
| **Chronicle** | Mythology |
| **Trove (Avari / player)** | Durable record of **minted** closed Arcori belonging to a player — out of circulation |
| **Mastery (player×design)** | Circulating progress; **not ownership**. Online match deltas: **own played** design 0/−1, 1/0, 2/+2 seat flips; **other** flipped designs 0/0, 1/+1, 2/+2. Practice skips. See [mastery.md](../01_Active_Plans/mastery.md) |
| **Mastery Value (player aggregate)** | `MasteryValue = Σ points×(10/selectionWeight)`; `density = Value / N` (`N` = circulating playable catalog count). Label: Fair / Notable / Sought / Coveted / Exquisite / Priceless. Profile wire `mastery.masteryValue` + `mastery.masteryValueLabel`. Replaces Rank/XP. [mastery.md](../01_Active_Plans/mastery.md) |

## Avari (player) titles

Product voice: players are **Avari**. Auth / API / account models may still say `player` / `user`.

| Title | Kind | System hook (concept) |
|-------|------|------------------------|
| **Avari** | Identity | Every authenticated player account in product copy |
| **Master** | Competitive title | Mastery Value / Standings (aggregate uses selectionWeight-scaled Mastery Value — see Progression / mastery.md) |
| **Legacy Owner** | Preservation achievement | Minted closed Arcori in Trove |
| **Generation Creator** | Historical title | `generation.creator` attributed to a player (not System) |

## Player ↔ design semantics

```text
Circulating (Velora)                 Closed / out of circulation
────────────────────────────────     ────────────────────────────
Play + Mastery                       Mint → Avari's Trove (Legacy Owner)
Live Standings                       Standings inactive; Museum snapshot
Not owned                            Minted legacy piece
```

- Starter unlocks / pack grants = **play/mastery access**, not Trove mints.
- `generation.creator`: System for launch content; Player (**Generation Creator**) when a preserved/minted generation attributes a creator.
- `legacy.preservationRequirement` / `legacy.closureMilestone` are per-design. Launch defaults by series:

| Series | JSON folder | Art folder | `internalId` token | preservationRequirement | closureMilestone | Why |
|--------|-------------|------------|--------------------|-------------------------|------------------|-----|
| **Creation** | `series/creation/` | `assets/images/arcori/000_creation/` | `SER000` | 50 | 100 | Primordial pair (The Light / The Dark); `selectionWeight` 0.1 |
| **Genesis** | `series/genesis/` | `assets/images/arcori/001_genesis/` | `SER001` | 500 | 1000 | Main launch catalog |
| **Pioneers** | `series/pioneers/` | `assets/images/arcori/002_pioneers/` | `SER002` | 100 | 200 | **Exists so these designs can mint earlier** than Genesis |
| **Foundations** | `series/foundations/` | `assets/images/arcori/003_foundations/` | `SER003` | 250 | 500 | Civilization / society themes (40 themes × 4 designs); mints between Pioneers and Genesis |

`SER000` / `SER002` / `SER003` mark series, not generation number (`generation.number` is still 1 / roman I at launch). Series id tokens use the `SER` prefix so they are not confused with generation. Pioneers is the original ten seed designs; it is not a second full catalog. Creation is excluded from the starter unlock pool (Genesis + Pioneers only).

## UI surfaces (client)

| Surface | Backing |
|---------|---------|
| **Velora** | Catalog (+ future world entities); opens **Arcori Detail** |
| **Arcori Detail** | SSOT; submenu **Standings** + **My Mastery** |
| **Trove** | Player mint list only |
| **Museum** | Closed-generation history (world), distinct from Trove |

Transport for Standings / My Mastery: HTTP on screen enter; optional authuser WS invalidation (`standings_changed` / mint events) while Detail is open — not per-flip counter streaming.

### Catalog HTTP (FastAPI)

Read-only **authuser** routes (Bearer). Exact-match router → query params for ids:

- `GET /authuser/catalog/meta`
- `GET /authuser/catalog/index` (Velora scan of `series/**/*.json`)
- `GET /authuser/catalog/theme?code=ANM`
- `GET /authuser/catalog/design?id=…`

Hot-reload: memory cache invalidated when file mtime/size changes; new theme files appear on next index after series folder mtime updates. Responses omit `artworkPrompt`.

**Chart + plain English guide:** [catalog-hot-reload-flow](../02_FlowCharts/charts/base/catalog-hot-reload-flow.html) · [guide](../02_FlowCharts/charts/base/catalog-hot-reload-flow.guide.html)

## Region model

Launch codes: **ASH** Ashdrift Hill, **EVG** Everlight Grove, **LFR** Little Frost, **MWB** Moonwake Bay, **AMB** Amberwild. Outside the political map: **RBY** Realm Beyond (no affinity/hostility).

Fields: regionCode, name, slug, type (`region`), worldState, seasonState, allianceCode, loreDescription, identity{summary,traits[]}, location{regionCode,locationCode,latitude,longitude,radiusMeters}, arenas[{arenaId,name,imageFile}], relationships.

Match arenas live on the region. Quick Start / Invite stamp a chosen `arenaId` + `arenaImageUrl` and optional `gathererArcoriId` on the match snapshot. Art: `assets/images/velora/arenas/{slug}/{arenaId}.webp` (`ARN-{regionCode}-{place}001-0001`), served at `/catalog-media/velora/arenas/{slug}/{arenaId}.webp`. Host layout sits beside disc art (`assets/images/arcori`); Docker binds Velora to `/data/catalog-velora`, not nested inside the `:ro` Arcori volume.

`location` slots match design `location` (coords unset at launch). `allianceCode` is `VEILED_ACCORD`, `LIVING_PACT`, or null (Little Frost is independent).

## Relationships

Designs have affinity/hostility (piece-to-piece). Regions have political standing (region-to-region). Regions are orthogonal to Themes.

Regional standing is cultural/political, not a moral alignment and not a travel or collect lock:

| Label | Value | Lists on `relationships` |
|-------|-------|--------------------------|
| Affinity | +2 | `affinity` / `allies` |
| Favourable | +1 | `favourable` |
| Neutral | 0 | `neutral` |
| Tension | −1 | `tension` |
| Hostility | −2 | `hostility` / `enemies` |

Each region also has `relationships.standings[otherRegionCode]` with `value`, `label`, and `reason`. File-level `alliances` and `centralConflict` sit beside the `regions` array.

## Generation Creator

Stored within `generation.creator`. System for launch content; Player (**Generation Creator** historical title) for subsequent preserved / minted generations.
