# Master Plan

**Status:** Living index  
**Created:** 2026-07-20  
**Last Updated:** 2026-08-09

Index of active implementation plans. Detail lives in the linked files; Game_Specific docs remain design SSOT for content/model.

## Template / ops

| Plan | Focus |
|------|--------|
| [01_TEMPLATE_INSTALLATION.MD](01_TEMPLATE_INSTALLATION.MD) | New product install, secrets, drain, TLS, RBAC, first deploy |

## Player app flows

| Plan | Focus |
|------|--------|
| [first-time-player-flow.md](first-time-player-flow.md) | Splash → Kin/Genesis → starter access → guided practice → intros → Home |
| [returning-player-startup-flow.md](returning-player-startup-flow.md) | Auto login → sync → overnight → notification queue → Home |
| [home-and-play-hub-flow.md](home-and-play-hub-flow.md) | Home layout, Velora entry, sink Trove • PLAY • Market |
| [match-setting-core-flow.md](match-setting-core-flow.md) | Stage 1+2 practice path done; later: match UI / matching |
| [match-hot-state.md](match-hot-state.md) | Dart match module for online later; not used for Flutter practice |
| [practice-offline-routing.md](practice-offline-routing.md) | Practice = Flutter-only; embedded 10 AI pool, pick 2; non-practice = room stub |
| [practice-stub-gameplay.md](practice-stub-gameplay.md) | Auto stub loop: 2 rounds × 3 seats, then postMatch stub |
| [ws-matchmaking-modes.md](ws-matchmaking-modes.md) | Quick/Event join-or-create lobby → match room SSOT; invite stub |
| [practice-match-v1.md](practice-match-v1.md) | Practice loadout + local stub slam; Dart packs dormant for practice |
| [core-match-loop.md](core-match-loop.md) | Matchmaking → match → celebration → Match Summary → exits |
| [arcori-standings-surface.md](arcori-standings-surface.md) | Standings module + Detail tab + wfrun tiger seed; My Mastery/Trove still open |
| [catalog-hot-reload.md](catalog-hot-reload.md) | Catalog JSON mtime cache, authuser APIs, `/catalog-media`, Flutter Velora browse |
| [avari-profile.md](avari-profile.md) | Avari Profile `/avari` + drawer avatar header; Account stays auth/avatar upload |
| [player-profile-schema.md](player-profile-schema.md) | Auth + Avari Postgres tables, complete document, admin testuser Alembic seed |

## Design references

- [Arcori Game Design Document](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)
- [Arcori Technical Specification](../Game_Specific/Arcori_Technical_Specification_v0.4.md)
- [Arcori Content Bible](../Game_Specific/Arcori_Content_Bible_v0.4.md)
- [Velora World Bible](../Game_Specific/Velora_World_Bible_v0.5.md)
