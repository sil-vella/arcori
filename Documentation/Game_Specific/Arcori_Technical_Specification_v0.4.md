# Arcori Technical Specification

Working Draft v0.4  
**Last aligned:** 2026-07-24 (Velora / Trove / Standings / mastery vs mint)

## Arcori Model

Fields: internalId, themeCode, designCode, designFamily, design, regionCode, affinity[], hostility[], generation{roman,number,creator}, type, theme, subtheme, style, finish, effect, printedRarity, series, worldState, seasonState, artworkPrompt, loreDescription.

## Architecture

| Layer | Role |
|-------|------|
| **Arcori Catalog** | Immutable design definitions (+ media); JSON under `modules/catalog/data/`; served authuser via mtime-cached loader (see [catalog-hot-reload.md](../01_Active_Plans/catalog-hot-reload.md)) |
| **Region Catalog** | Politics and geography |
| **Standings** | Live per-design community state for the **active** generation (mastery ranks, generation fill, leader window) |
| **Museum** | World historical snapshots of **closed** generations (factual archive) |
| **Chronicle** | Mythology |
| **Trove (player)** | Durable record of **minted** closed Arcori belonging to a player — out of circulation |
| **Mastery (player×design)** | Circulating progress; **not ownership** |

## Player ↔ design semantics

```text
Circulating (Velora)                 Closed / out of circulation
────────────────────────────────     ────────────────────────────
Play + Mastery                       Mint → player's Trove
Live Standings                       Standings inactive; Museum snapshot
Not owned                            Minted legacy piece
```

- Starter unlocks / pack grants = **play/mastery access**, not Trove mints.
- `generation.creator`: System for launch content; Player when a preserved/minted generation attributes a creator.

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

## Relationships

Designs have affinity/hostility. Regions have allies/enemies. Regions are orthogonal to Themes.

## Generation Creator

Stored within generation.creator. System for launch content; Player for subsequent preserved / minted generations.
