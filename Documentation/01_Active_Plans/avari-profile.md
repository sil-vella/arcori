# Avari Profile

**Status:** Implemented (read API + Profile screen + drawer avatar header + Wallet + link to Trove)  
**Created:** 2026-07-26  
**Last Updated:** 2026-09-20

Related: [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md) · [first-time-player-flow.md](first-time-player-flow.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [mastery.md](mastery.md) · [legacy-preserve.md](legacy-preserve.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md)

## Objective

Separate **Avari Profile** (`/avari`) from **Account** (`/account`). Account stays auth + avatar upload; Avari is product identity + Rank/Titles/Kin/Mastery/Stats (stubs until gameplay).

## Shared avatar

One `avatarUrl` on the user profile. Account uploads; Avari screen + drawer header display the same image.

## Surfaces

| Surface | Path | Role |
|---------|------|------|
| Drawer header | — | Center-top circle avatar → `/avari` |
| Avari Profile | `/avari` | Identity + circulating inventory |
| Trove | `/trove` | Legacy mints + closed gens / preservation windows |
| Account | `/account` | Sign in / Create / avatar upload |

## API

`GET /authuser/avari/profile` — identity from user row; `rank` / `titles` / `kin` / `mastery` / `stats` / **`economy`** (`goldArcori`, `goldFragments`); **`access`** = circulating `player_design_access` with catalog face fields + **`masteryPoints`** + **`mintReach`**; **`kin`** includes the same **`masteryPoints` / `mintReach`** for the Genesis Kin design; **`slammers`** = owned `player_slammers`; **`trove`** = Legacy mints; **`closedGenerations`** = closed gens this player had mastery on (`masteryPoints` at close, `echoMasterySeeded`, `echoGenerationNumber`, Preserved/Lost).

**Profile UI:** Wallet, Titles, Achievements, Kin, Stats, Mastery Value, link to **Trove**, circulating **Arcori**, Slammers.  
**Trove screen:** Legacy mints + Closed Generations + Preservation Windows (not circulating play stock — GDD).

## Module files

- Python: `bin/modules/avari/`
- Flutter: `lib/modules/avari/`, `lib/modules/trove/`
- Drawer chrome: `AppShell` / `AvariDrawerHeader`

## Out of scope

Account auth flows, Market packs UI, My Mastery tab on Arcori Detail.
