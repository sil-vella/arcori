# Arcori Technical Specification

Working Draft v0.4  
**Last aligned:** 2026-08-21 (stub match turn stages: 2 rounds × seat slam)

## Arcori Model

Fields: internalId, themeCode, designCode, designFamily, design, inspiration, regionCode, affinity[], hostility[], generation{roman,number,creator}, type, theme, subtheme, style, finish, effect, printedRarity, selectionWeight, series, worldState, seasonState, artworkPrompt, loreDescription.

**Natural selection (catalog / circulation):** `03_printed_rarity.json` maps printedRarity → default `selectionWeight` (Common 3.0 … Legendary 0.5; Unique is custom / null). If a design sets `selectionWeight` to a number, that value **overrides** the printed-rarity default for circulation-style uses. Omit or `null` → use the table. Launch catalog: all designs `printedRarity: Common`, with per-design `selectionWeight` copied from their previous rarity so selection spread is unchanged.

**Match Arcori pairing SSOT:** after players are seated, `04_selection_weights.json` is the sole table for picking one design per seat (`printedRarity` weight × region standing multiplier; hostility boosts match chance). Design-level `selectionWeight` is **not** used for match pairing. Service: `POST /service/catalog/select_arcori`. Candidates = that player's `player_design_access` ids that are still circulating. Weight/parse failures → random among **those** candidates only — never the global circulating catalog. Empty player access → empty pick (client/Dart stub may fill Tiger).

**Online stub turns:** after `startFromLobby`, Dart runs an auto stub loop (`roundsTotal` default 2 × one `slam` per seat) using each seat’s `slammerId`, broadcasts `match/state` with enriched `lastEvent` (`seatIndex`, `round`, `slammerId`, `arcoriId`, `result: stub`), then `endMatch`. Flutter online play waits for `phase=ended` (no client auto-end). Practice Flutter loop uses the same `lastEvent` shape.

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

Fields: regionCode, name, type (`region`), worldState, seasonState, allianceCode, loreDescription, identity{summary,traits[]}, location{regionCode,locationCode,latitude,longitude,radiusMeters}, relationships.

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
