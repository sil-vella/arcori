# Avari Profile

**Status:** Implemented (read API + Profile screen + drawer avatar header)  
**Created:** 2026-07-26  
**Last Updated:** 2026-07-26

Related: [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md) · [first-time-player-flow.md](first-time-player-flow.md) · [arcori-standings-surface.md](arcori-standings-surface.md)

## Objective

Separate **Avari Profile** (`/avari`) from **Account** (`/account`). Account stays auth + avatar upload; Avari is product identity + Rank/Titles/Kin/Mastery/Stats (stubs until gameplay).

## Shared avatar

One `avatarUrl` on the user profile. Account uploads; Avari screen + drawer header display the same image.

## Surfaces

| Surface | Path | Role |
|---------|------|------|
| Drawer header | — | Center-top circle avatar → `/avari` |
| Avari Profile | `/avari` | Identity + stub sections |
| Account | `/account` | Sign in / Create / avatar upload |

## API

`GET /authuser/avari/profile` — identity from user row; `rank` / `titles` / `kin` / `mastery` / `stats` stubs.

## Module files

- Python: `bin/modules/avari/`
- Flutter: `lib/modules/avari/`
- Drawer chrome: `AppShell` `_DrawerAvariHeader`

## Out of scope

Kin onboarding, mastery persistence, Rank XP grants, title earning, Avari-side avatar upload.
