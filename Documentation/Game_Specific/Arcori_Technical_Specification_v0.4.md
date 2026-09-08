# Arcori Technical Specification

Working Draft v0.4  
**Last aligned:** 2026-09-06 (Quick Start / Invite arena from seated Arcori)

## Arcori Model

Fields: internalId, themeCode, designCode, designFamily, design, inspiration, regionCode, affinity[], hostility[], generation{roman,number,creator}, type, theme, subtheme, style, finish, effect, printedRarity, selectionWeight, series, worldState, seasonState, artworkPrompt, loreDescription, legacy{preservationRequirement, closureMilestone}.

**Natural selection (catalog / circulation):** `03_printed_rarity.json` maps printedRarity → default `selectionWeight` (Common 3.0 … Legendary 0.5; Unique is custom / null). If a design sets `selectionWeight` to a number, that value **overrides** the printed-rarity default for circulation-style uses. Omit or `null` → use the table. Launch catalog: all designs `printedRarity: Common`, with per-design `selectionWeight` copied from their previous rarity so selection spread is unchanged.

**Match Arcori pairing SSOT:** after players are seated, `04_selection_weights.json` is the sole table for picking one design per seat (`printedRarity` weight × region standing multiplier; hostility boosts match chance). Design-level `selectionWeight` is **not** used for match pairing. Service: `POST /service/catalog/select_arcori`. Candidates = that player's `player_design_access` ids that are still circulating. Weight/parse failures → random among **those** candidates only — never the global circulating catalog. Empty player access → empty pick (client/Dart stub may fill Tiger).

**Match arena (Quick Start / Invite):** after those Arcori ids exist, `POST /service/catalog/select_arena` counts `location.regionCode`. Two or more from the same region → random arena in that region. All different (or no majority) → random catalog region that has arenas, then a random arena. Snapshot fields: `arenaId` + `arenaImageUrl` (`/catalog-media/velora/arenas/{slug}/{arenaId}.webp`). Fail closed to stub `arena_velora_plaza` with no image. **Special Event** does not use this pick (separate rules later). Practice stays on the stub arena.

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
| **Mastery (player×design)** | Circulating progress; **not ownership** |

## Avari (player) titles

Product voice: players are **Avari**. Auth / API / account models may still say `player` / `user`.

| Title | Kind | System hook (concept) |
|-------|------|------------------------|
| **Avari** | Identity | Every authenticated player account in product copy |
| **Master** | Competitive title | Mastery / Standings standing (per design or aggregate — TBD) |
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

| Series | JSON folder | `internalId` token | preservationRequirement | closureMilestone | Why |
|--------|-------------|--------------------|-------------------------|------------------|-----|
| **Genesis** | `series/genesis/` | `GEN001` | 500 | 1000 | Main launch catalog |
| **Pioneers** | `series/pioneers/` | `GEN002` | 100 | 200 | **Exists so these designs can mint earlier** than Genesis |

`GEN002` marks the Pioneers series, not generation number (`generation.number` is still 1 / roman I at launch). Pioneers is the original ten seed designs; it is not a second full catalog.

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

Match arenas live on the region. Quick Start / Invite stamp a chosen `arenaId` + `arenaImageUrl` on the match snapshot. Art: `assets/images/velora/arenas/{slug}/{arenaId}.webp` (`ARN-{regionCode}-{place}001-0001`), served at `/catalog-media/velora/arenas/{slug}/{arenaId}.webp`. Host layout sits beside disc art (`assets/images/arcori`); Docker binds Velora to `/data/catalog-velora`, not nested inside the `:ro` Arcori volume.

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
