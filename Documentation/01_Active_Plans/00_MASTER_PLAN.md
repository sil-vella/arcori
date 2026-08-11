# Master Plan

**Status:** Living index  
**Created:** 2026-07-20  
**Last Updated:** 2026-08-11

Index of active implementation plans. Detail lives in the linked files; Game_Specific docs remain design SSOT for content/model.

**Next implementation:** [ws-invite-match.md](ws-invite-match.md) (Friend Match / invite WS).

**Narrative:** [03_CASE_STUDY.md](03_CASE_STUDY.md) — full game implementation case study (design → matchmaking; template infra out of scope).

## Template / ops

| Plan | Status | Focus |
|------|--------|--------|
| [rop01-cron-social-auto-post.md](rop01-cron-social-auto-post.md) | In Progress | Hostinger queue + cron poster FB/YT/TT |
| [01_TEMPLATE_INSTALLATION.MD](01_TEMPLATE_INSTALLATION.MD) | Living | New product install, secrets, drain, TLS, RBAC, first deploy |

## Player app flows

| Plan | Status | Focus |
|------|--------|--------|
| [first-time-player-flow.md](first-time-player-flow.md) | Spec | Splash → Kin/Genesis → starter access → guided practice → intros → Home |
| [returning-player-startup-flow.md](returning-player-startup-flow.md) | Spec | Auto login → sync → overnight → notification queue → Home |
| [home-and-play-hub-flow.md](home-and-play-hub-flow.md) | Spec | Home layout, Velora entry, sink Trove • PLAY • Market |
| [match-setting-core-flow.md](match-setting-core-flow.md) | Partial | Play hub + types; practice offline; quick/event online; invite next |
| [match-hot-state.md](match-hot-state.md) | Done (online room SSOT) | Dart match module + Flutter mirror; used by matchmaking promote |
| [practice-offline-routing.md](practice-offline-routing.md) | Completed | Practice = Flutter-only; embedded 10 AI pool |
| [practice-stub-gameplay.md](practice-stub-gameplay.md) | Completed | Auto stub loop: 2 rounds × 3 seats → postMatch |
| [ws-matchmaking-modes.md](ws-matchmaking-modes.md) | Completed | Quick/Event lobby → AI fill → match room SSOT |
| [ws-invite-match.md](ws-invite-match.md) | **Next** | Friend Match invite WS (replaces Play stub) |
| [practice-match-v1.md](practice-match-v1.md) | Superseded routing | Loadout + local practice; Dart packs dormant for practice |
| [core-match-loop.md](core-match-loop.md) | Spec | Matchmaking → match → celebration → Match Summary → exits |
| [arcori-standings-surface.md](arcori-standings-surface.md) | Partial | Standings + Detail tab; My Mastery/Trove still open |
| [catalog-hot-reload.md](catalog-hot-reload.md) | Done | Catalog JSON mtime cache, authuser APIs, Flutter Velora |
| [avari-profile.md](avari-profile.md) | Done | Avari Profile `/avari` + drawer avatar header |
| [player-profile-schema.md](player-profile-schema.md) | Done | Auth + Avari tables, admin testuser seed |

## Design references

- [Arcori Game Design Document](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)
- [Arcori Technical Specification](../Game_Specific/Arcori_Technical_Specification_v0.4.md)
- [Arcori Content Bible](../Game_Specific/Arcori_Content_Bible_v0.4.md)
- [Velora World Bible](../Game_Specific/Velora_World_Bible_v0.5.md)
