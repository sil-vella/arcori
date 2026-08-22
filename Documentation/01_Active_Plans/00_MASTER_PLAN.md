# Master Plan

**Status:** Living index  
**Created:** 2026-07-20  
**Last Updated:** 2026-08-21

Index of active implementation plans. Detail lives in the linked files; Game_Specific docs remain design SSOT for content/model.

**Next app build:** weighted slam / real turns / random first player (practice + online). After that: celebration / Match Summary → Home sink / first-time flows.

**Narrative:** [03_CASE_STUDY.md](03_CASE_STUDY.md) — full game implementation case study (design → matchmaking; template infra out of scope).

## Task Manager (Arcori board)

The `arcori` label is **project-wide**. Do **not** create one board task per app-build plan.

| Board task | Use for |
|------------|---------|
| **App Dev** (single card, task `32`) | All player-app micro-builds as **checklists** (and notes). Reuse this card forever. |
| **Ideas** (task `18`) | Unstructured notes — **do not edit** unless asked |
| **Template / install** | Living ops checklist |
| Other Ops cards | Marketing, dashboard revenue, cron — not the game app |

### App Dev checklist (mirror of app plans)

Done:

- [x] Catalog hot-reload + Velora browse
- [x] Avari Profile
- [x] Player profile schema + 500 AI seed
- [x] Play hub + match type select
- [x] Match hot state (Dart room SSOT + Flutter mirror)
- [x] Practice offline routing + stub gameplay
- [x] Quick Start / Special Event matchmaking (AI fill → match room → stub end)
- [x] Play failure OK modal + lobby/match dismiss hardening
- [x] Invite / Friend Match WS — [ws-invite-match.md](ws-invite-match.md)
- [x] Stub match Arcori selection (Python weights + Dart startFromLobby) — [stub-match-arcori-selection.md](stub-match-arcori-selection.md)
- [x] Stub match turn stages (2 rounds × slam, Dart auto loop) — [stub-match-turn-stages.md](stub-match-turn-stages.md)

Open (ordered):

- [ ] **Weighted slam / real turns / random first player** *(next)*
- [ ] Celebration + Match Summary + FastAPI durable rewards
- [ ] Home sink Trove • PLAY • Market; first-time / returning startup
- [ ] My Mastery tab + Trove UI + economy writers

Standings surface is live with an open tail (My Mastery / Trove) covered by the last open line.

**Board (2026-08-21):** Stub match turn stages **Completed** on App Dev (`32`) — checklist `146` (+ dup `147`) + note `148`. Next open line: weighted slam. **Ideas** (`18`) untouched.

## Template / ops / project-wide (own TM cards — not App Dev)

| Plan | Status | Focus |
|------|--------|--------|
| [rop01-cron-social-auto-post.md](rop01-cron-social-auto-post.md) | In Progress | Hostinger queue + cron poster FB/YT/TT |
| [dashboard-revenue-tab.md](dashboard-revenue-tab.md) | Mostly done | wfrun Revenue tab (Play / ASC / AdMob) |
| [dashboard-parallel-script-runs.md](dashboard-parallel-script-runs.md) | Completed | Same script in multiple PTY tabs (do not kill sibling) |
| [marketing-post-metrics.md](marketing-post-metrics.md) | In Progress | Marketing metrics; TikTok list still open |
| [01_TEMPLATE_INSTALLATION.MD](01_TEMPLATE_INSTALLATION.MD) | Living | New product install, secrets, drain, TLS, RBAC, first deploy |

## Player app flows

| Plan | Status | Focus |
|------|--------|--------|
| [first-time-player-flow.md](first-time-player-flow.md) | Spec | Splash → Kin/Genesis → starter access → guided practice → intros → Home |
| [returning-player-startup-flow.md](returning-player-startup-flow.md) | Spec | Auto login → sync → overnight → notification queue → Home |
| [home-and-play-hub-flow.md](home-and-play-hub-flow.md) | Spec | Home layout, Velora entry, sink Trove • PLAY • Market |
| [match-setting-core-flow.md](match-setting-core-flow.md) | Partial | Play hub + types; practice offline; quick/event/invite online |
| [match-hot-state.md](match-hot-state.md) | Done (online room SSOT) | Dart match module + Flutter mirror; used by matchmaking promote |
| [practice-offline-routing.md](practice-offline-routing.md) | Completed | Practice = Flutter-only; embedded 10 AI pool |
| [practice-stub-gameplay.md](practice-stub-gameplay.md) | Completed | Auto stub loop: 2 rounds × 3 seats → postMatch |
| [ws-matchmaking-modes.md](ws-matchmaking-modes.md) | Completed | Quick/Event lobby → AI fill → match room SSOT |
| [ws-invite-match.md](ws-invite-match.md) | Completed | Friend Match invite WS + notification reply modal |
| [stub-match-arcori-selection.md](stub-match-arcori-selection.md) | Completed | After seats: FastAPI pick via `04_selection_weights.json` |
| [stub-match-turn-stages.md](stub-match-turn-stages.md) | Completed | Online Dart: 2×N stub slams then end; practice lastEvent aligned |
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
