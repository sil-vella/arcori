# Avari Profile

**Status:** Implemented (read API + Profile screen + drawer avatar header + Wallet + link to Trove)  
**Created:** 2026-07-26  
**Last Updated:** 2026-10-27

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

**Profile UI:** Wallet, Titles, Achievements, Kin portrait in the username block, Mastery Value under the name, link to **Trove**, Slammers, circulating **Arcori as containers**.  
**Arcori card:** Mastery Value and Standing stay under the username, not on this card. Circulating `access` designs are not listed on the card itself. Every **100** designs with mastery above 0 are one sealed container, drawn from the closed container artwork. A design at 0 mastery has left the pool and does not count. The next container shows `n / 100` and a gold bar for progress toward full. Under the circulating line, a gold count includes the canister still filling, so it starts at 1 (`1 Arcori Canister`, plural otherwise) even before that canister is full. A **Browse** button sits on the right of “Circulating Arcori you have mastered.” and opens `/avari/circulating`.  
**My Arcori screen** (`/avari/circulating`): Search looks across the whole circulating set. Canisters are that list in mastery order, each one framed as tappable with “Tap to open”: the first 100 designs fill canister 1, and the last canister is always the one still filling (`n / 100`), including an empty `0 / 100` when nothing matches. There is no featured design on this screen. Tapping a canister pushes `/avari/circulating/canister`. The opening is the full-color canister artwork: the body stays still and the cap lifts, then tilts, with a full-screen rotating gold shine held on the rim while the cap lifts away. Flutter’s Lottie draw of `container_open.json` collapsed the shading to two golds, so that file is not what plays. After the cap opens, theme, series, and sort filters apply to the Arcori inside that canister. Each design opens the existing detail screen. Access cards include `theme`, `subtheme`, `seriesKey`, and `generationNumber` for those filters.  
**Trove screen:** Legacy mints + Closed Generations + Preservation Windows (not circulating play stock — GDD).

## Module files

- Python: `bin/modules/avari/`
- Flutter: `lib/modules/avari/`, `lib/modules/trove/`
- Drawer chrome: `AppShell` / `AvariDrawerHeader`

## Out of scope

Account auth flows, Market packs UI, My Mastery tab on Arcori Detail.

## Container bank (2026-10-26)

- [x] Arcori card drops Mastery Value, Standing, and the per-design face row
- [x] Circulating access with mastery above 0 → one still container per 100, plus `remainder / 100` on the next. Mastery 0 has left the pool and does not count.
- [x] Asset: `flutter_base_06/assets/images/container_closed.webp` — the closed container from `container.svg` (ribbed cap, side column, emblem). Not a crop of the opening Lottie.
- [x] Canister shown at half size. Circulating total (mastery above 0) sits on the right of the Arcori label.
- [x] Arcori card background: `029_arcori_sanctuary_desktop_21x9.webp`, resized to 960×411 (~38KB) for the card.
- [x] Economy marks (`gold_arcori`, `gold_fragment`, `matches`, `flips` webp) replace the wallet glyphs and the same marks on Market, match fee, post-match, Daily Cache claim, and special-event rows.
- [x] Avari profile mark (`avari_profile.webp`) on Account, the Profile card, the Avari card, and empty profile portraits. Drawer rows stay on the generic icons.
- [x] Circulating screen replaces the design grid with the same canisters. Tap plays `container_open.json`, then lists that canister’s Arcori.

## Files
- `app_codebase/flutter_base_06/lib/modules/avari/widgets/arcori_container_bank.dart`
- `app_codebase/flutter_base_06/lib/modules/avari/widgets/arcori_canister_grid.dart`
- `app_codebase/flutter_base_06/lib/modules/avari/widgets/circulating_arcori_tile.dart`
- `app_codebase/flutter_base_06/lib/modules/avari/screens/avari_profile_screen.dart`
- `app_codebase/flutter_base_06/lib/modules/avari/screens/circulating_arcori_screen.dart`
- `app_codebase/flutter_base_06/lib/modules/avari/screens/canister_open_screen.dart`
- `app_codebase/flutter_base_06/lib/modules/avari/circulating_browse.dart`
- `app_codebase/flutter_base_06/assets/lottie/container_open.json`
- `app_codebase/flutter_base_06/assets/images/container_body.webp`
- `app_codebase/flutter_base_06/assets/images/container_cap.webp`

## Case study
n/a — display only. Mastery Value formula is unchanged and still shown under the username. No case-study HTML file in `01_Active_Plans/`.

## Task Manager
App Dev checklist: profile Arcori containers (100 per container, progress to full). Circulating opens a canister, then shows its Arcori.
