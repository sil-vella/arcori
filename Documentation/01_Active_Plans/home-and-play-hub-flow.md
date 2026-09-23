# Home and Play Hub Flow

**Status:** In Progress  
**Created:** 2026-07-20  
**Last Updated:** 2026-09-20

Related: [returning-player-startup-flow.md](returning-player-startup-flow.md) · [core-match-loop.md](core-match-loop.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [first-time-player-flow.md](first-time-player-flow.md) · [NOTIFICATION_SYSTEM.md](../03_Base/NOTIFICATION_SYSTEM.md) · Flutter bottom-nav docs in `03_Base/Flutter/`

Stage 1 Play route + type select (drawer entry; Home sink later): [match-setting-core-flow.md](match-setting-core-flow.md).  
Play modes live status: practice / quick / event / invite online (stub match end).

## Objective

Ship Home widgets (Mastery Value, Daily Missions, featured events, World News, mastery ticker) and wire World News through the existing notification system. Play Hub modes and bottom sink remain related but deferred where noted.

## Home contents (v1)

Home contains:

- **Total Mastery Value** (profile aggregate + Fair→Priceless label)
- **Daily Missions** (featured strip → Tasks)
- **Featured events** (special events catalog; `homeFeatured` pin)
- **World News** (notifications with `category=news`)
- **Mastery ticker** (horizontal animated text: last 5 player mastery deltas)

Deferred (prior GDD / this plan): Main Play card, Velora hero entry.

## World News

- Storage: **no separate news table** — news rows are notifications with `category=news`
- Admin: `global_notifications.json` sync + `POST /service/notifications/global-upsert`
- Auto: gen closure / Legacy Owner emitters from Legacy (`source=world`, subtypes `gen_closed_v1` / `legacy_owner_v1` / `admin_v1`)
- Critical (`type=instant`) → `NotificationHost` modal; routine (`type=inbox`) → Home feed + inbox

## Bottom sink

```text
Trove — PLAY — Market
```

Uses the platform **screen-scoped bottom action bar** ([BOTTOM_NAV_REGISTRATION.md](../03_Base/Flutter/BOTTOM_NAV_REGISTRATION.md)): shared `hub_sink` scope + `ModuleScreenRegistrar` on Home, Trove, Play, Market.

- **Trove** (`/trove`) — minted closed Arcori (Legacy) + closed gens / preservation windows. Circulating play stock stays on Avari profile.
- **PLAY** (`/play`) — Play Hub (circulating mastery-accessible designs).
- **Market** (`/market`) — **Slammers** section (Rim buy / recharge); packs later — [arcori-packs.md](arcori-packs.md).
- **Velora** — first-class from Home (and related), not under Trove.

## Play Hub

**PLAY** opens the Play Hub (Stage 1 live via `/play`):

- Random Match
- Event Match
- Practice
- Friend Match
- Future modes

## Implementation Steps

- [x] Home screen composition (Mastery Value, Daily Missions, featured event, World News, mastery ticker)
- [x] World News via notification `category=news` (subtypes, global-upsert, admin seed)
- [x] Auto emit gen closed / Legacy Owner news
- [x] Mastery recent change log + API for ticker
- [x] Bottom sink: Trove • PLAY • Market (`hub_sink` bottom nav + `/trove` + `/market` Slammers)
- [x] Play Hub screen with mode list (via `/play`)
- [ ] Full returning-player startup queue (see [returning-player-startup-flow.md](returning-player-startup-flow.md))

## Current Progress

2026-09-20 — Hub sink live (Trove / Play / Market); Trove screen holds Legacy mints + closed gens / preservation; Market empty stub; profile links to Trove.

## Files Modified

- `Documentation/01_Active_Plans/home-and-play-hub-flow.md`, `returning-player-startup-flow.md`, `00_MASTER_PLAN.md`, `03_CASE_STUDY.md`, `avari-profile.md`
- `Documentation/03_Base/NOTIFICATION_SYSTEM.md`
- `bin/modules/notifications/*` (world news, global-upsert)
- `bin/modules/legacy/legacy_service.py`, `bin/modules/avari/*`, `alembic/versions/029_*.py`
- `flutter_base_06/lib/modules/hub/hub_bottom_nav.dart`, `trove/`, `market/`, `home/home_screen.dart`, `play/screens/play_screen.dart`, `avari/screens/avari_profile_screen.dart`
- `automation/backend/files/global_notifications.json`, `special_events.json` (`homeFeatured`)

## Next Steps

Play/Velora hero on Home; Market packs UI; returning-player overnight/startup queue consuming news.

## Notes

Critical generation/event news may interrupt as full-screen modals (`instant`); routine items stay in World News (`inbox`). Full startup sequencer is still later — instant news works via `NotificationHost` without it.
