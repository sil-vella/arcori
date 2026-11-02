# Avari's hand

**Status:** In progress  
**Created:** 2026-10-31  
**Last Updated:** 2026-11-01

Related: [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [slam-strike-motion.md](slam-strike-motion.md) · [slammer-recovery-and-recharge.md](slammer-recovery-and-recharge.md)

## Objective

Sell a Market cosmetic named **Avari's hand**: glowing hands in the style of the splash screen (`assets/images/branding/splash_screen.png`) that play in time with the existing slammer slam animation.

## Product rules

1. **Name** — Avari's hand. The first three are Celestial Gold Hand, Copper Arcane Hand, and Luminous Cybernetic Hand.
2. **Where it is bought** — Market, once, for 4 Gold Arcori (the shop slammer price). No charges and no recharge. Only an owned hand can be equipped.
3. **Look** — Glowing hands on a transparent background, same idea as the splash.
4. **Motion** — The hands animate with the slammer strike. They do not change slam power, aim, or the physics result.
5. **Who sees it** — The owner who bought it, on their slam.
6. **Catalog** — Series Avari Hands (`SER008`), theme Hands (`HND`), type Hand, `worldState` Cosmetic. They use the same design JSON and `imageUrl` hydrate as other catalog items. They are not match stock.

## Implementation steps

- [x] Convert the first three hands to transparent WebP and author the catalog
- [x] Rest pose on the play screen: palm under the right side of the slammer, wrist along that seat's right
- [x] Sell the three hands on the Market for 4 Gold Arcori and store ownership in `player_hands`
- [x] Equip only an owned hand, from the Avari profile and from Game Controls
- [x] Draw the owned hand on the slammer strike (fly-in, scatter, return)

## Current Progress

The three source PNGs are WebP at a 768 long edge, with transparency kept. Catalog ids:

- `ARC-HND-CLG-SER008-GEN001-0001` Celestial Gold Hand
- `ARC-HND-CPR-SER008-GEN001-0002` Copper Arcane Hand
- `ARC-HND-LCY-SER008-GEN001-0003` Luminous Cybernetic Hand

Art for the catalog mount is `assets/images/arcori/008_avari_hands/hands/`. Working copies stay in `assets/images/avari_hands/`. Local `catalog_designs` has the three rows, origin Shop, price 4.

Rest pose is in the play chrome, behind the disc. The palm sits just to the seat's right of the disc center, nudged a little down and left. The forearm is vertical. Opacity breathes between 0.5 and 0.8. The hand follows the strike while the disc grows and through half of the shrink, holds for 2 seconds, then fades out. At rest the order is slammer, profile, hand. The left-seat hand is turned 90° clockwise from the local hand, and the right-seat hand 270° clockwise. The disc keeps tumbling.

Hands are Shop designs at 4 Gold Arcori, permanent, with no charges. `GET /authuser/market/hands` and `POST /authuser/market/hands/purchase` spend Gold Arcori and insert `player_hands`. The profile `hands` list is that table. Game Controls and the profile Equip button write `arcori_equipped_hand_id` only from owned rows. The play screen paints the local hand only when that id is in the profile list.

A bought hand and an AI hand are the same row: `player_hands` (`user_id`, `design_id`, `source`). There is no equipped column. A person's equipped hand stays on the device (`arcori_equipped_hand_id`). An AI has no device, so the one owned row is the hand they play. Two of three AI users get one shop hand, chosen from the user id so a later backfill does not move it. The row's source is `ai`. The other third own none. The dev database has 351 of 500 AI users with a hand (110 gold, 108 copper, 133 luminous) and the one market purchase left as source `market`.

Online seats ask `POST /service/avari/owned_hands` and stamp `handId` on AI seats. Practice uses the same user-id rule locally. The opponent chrome and that seat's slam draw the hand.

Local catalog rows were overwritten for the three ids, and migration `035_player_hands` is applied on the dev database.

## Next Steps

Human opponents still send no equipped hand, because equip lives on the device, not in `player_hands`.

## Case study

Row added under major decisions: Market cosmetic, visual only, timed to the slam.

## Files

- `app_codebase/flutter_base_06/lib/modules/match/widgets/hand_under_slammer.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/match_player_chrome.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/practice_match_surface.dart`
- `app_codebase/flutter_base_06/lib/modules/play/avari_hand_catalog.dart`
- `app_codebase/flutter_base_06/lib/modules/play/game_controls_prefs.dart`
- `app_codebase/flutter_base_06/lib/modules/play/screens/game_controls_screen.dart`

## Task Manager

App Dev checklist on task 32. Not checked.
