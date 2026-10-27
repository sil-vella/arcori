# Home and Play Hub Flow

**Status:** In Progress  
**Created:** 2026-07-20  
**Last Updated:** 2026-10-27 (match seat chrome: played Arcori, gold name ring)

Related: [returning-player-startup-flow.md](returning-player-startup-flow.md) · [core-match-loop.md](core-match-loop.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [first-time-player-flow.md](first-time-player-flow.md) · [NOTIFICATION_SYSTEM.md](../03_Base/NOTIFICATION_SYSTEM.md) · Flutter bottom-nav docs in `03_Base/Flutter/`

Stage 1 Play route + type select (drawer entry; Home sink later): [match-setting-core-flow.md](match-setting-core-flow.md).  
Play modes live status: practice / quick / event / invite online (stub match end).

## Objective

Ship Home widgets (Mastery Value, Daily Missions, featured events, World News, mastery ticker) and wire World News through the existing notification system. Play Hub modes and bottom sink remain related but deferred where noted.

## Home contents (v1)

Home contains:

- **Total Mastery Value** (profile aggregate + Fair→Priceless label) and the player’s most-mastered slammer (face + `points/reach`)
- **Daily Missions** and **World News** side by side
- **Featured events** stay full width (`homeFeatured` pin)
- **World News** (notifications with `category=news`)
- **Mastery ticker** inside the Mastery Value card, under the standing label (last 5 player mastery deltas)

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

- **Trove** (`/trove`) — **shipped:** minted closed Arcori + closed gens / preservation windows. **Target:** My Legacy Slammers ([slammer-legacy.md](slammer-legacy.md)). Circulating Arcori stay on the Avari profile.
- **PLAY** (`/play`) — Play Hub (circulating mastery-accessible designs).
- **Market** (`/market`) — **Slammers** section (Genesis shop slammers, buy / recharge); packs later — [arcori-packs.md](arcori-packs.md).
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

2026-10-20 — Home: featured stays full width. Daily Missions and World News share one row. Mastery Value shows the aggregate plus the most-mastered slammer face, with the recent-mastery ticker under that standing label.

2026-10-20 — Visual pass against `assets/ui_designs` (existing art and icons only). Featured and Play mode cards are split copy + art with gold Play Now. Bottom PLAY is a raised gold circle. Trove sections show counts. Market opens with a Gold Arcori wallet, a wide featured slammer, then a row of the rest. Post-match fragments sit in a gold banner; slammer mastery is a horizontal disc + total/gain; daily goals sit in a row. Live match stays the real stack — the arena illustration is not a replacement surface.

2026-10-23 — PLAY orb overflow: the disc is drawn above the 72px sink, and its layout box stays inside the bar so the caption no longer overflows by 1px.

2026-10-23 — Home featured event: banner art covers the card. Title, copy, and Play Now sit on a dark wash that fades out toward the right.

2026-10-27 — Play screen title is Match. The Featured card uses the altar WebP as its cover. The sink PLAY item is a gold circle on the bar's top edge, so half of it sits above the sink, with the arena mark at twice the other sink icons and the Match label underneath. The top half of the circle is part of the tap target, so it opens Match.

2026-10-23 — Mastery Value: total and top slammer are two columns with a gold divider. The total sits in a thin gold ring with a medal icon; the slammer score has a disc icon. Ticker stays full width under both. Featured and Mastery covers fill the whole card, including the label and padding. The featured wash fades out by the midpoint; the right half is the cover image only.

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

2026-10-27: Match search modal shows only “Looking for a match.” / “Match starting…” (no lobby id, timer, or player ids). Match screen has a dark-to-clear edge gradient. End-match summary uses the same modal row and gold labels as the other match dialogs. App Dev checklist 396.

Match status (Your turn, Waiting, Get ready, Resolving slam) is a gold banner above the table, with the status as the large line and the how-to underneath. App Dev checklist 397.

2026-10-27: Match seats show the Arcori that player is playing (green border while that seat is in play) instead of the profile mark. The username sits in a gold rim with a gold diamond at the bottom and a green dot while that player is current. The status banner uses the same gold card frame as the screen cards. App Dev checklist 398.

Exit match sits above the edge vignette, with a solid dark fill and gold border, so the corner wash no longer covers it. App Dev checklist 399.
