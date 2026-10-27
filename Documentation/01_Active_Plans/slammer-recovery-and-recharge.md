# Slammer Recovery + Charge Spend / Recharge

**Status:** Charge spend + Market shop slammers shipped; Recovery still deferred  
**Created:** 2026-09-05  
**Last Updated:** 2026-10-27

Related: [arcori-slam-impact.md](arcori-slam-impact.md) · [player-slam-input.md](player-slam-input.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md)

## Objective

1. **Recovery** — `gameplayAttributes.recovery` (1–10). Still unused in `resolveSlam`.
2. **Charge spend / Market recharge** — **shipped** for every Genesis Shop slammer. Starter stays free.

## Live today

### Market (all Genesis except Starter)

`origin: Shop`. Glitch moved off Event onto Shop. Starter stays `origin: Starter` and permanent — not listed, not sold.

| Action | Cost | Result |
|--------|------|--------|
| First buy | **4 Gold Arcori** | Own that slammer + **25** charges |
| Top-up | **4 Gold Arcori** | **+100** charges |
| Per slam | **1 charge** | Online, events, and practice (permanent starter free) |

Shelf is every catalog design with theme `SLM`, `origin` Shop, and `permanent` false — not a hardcoded Rim id. Endpoints: `GET/POST /authuser/market/slammers…`. Flutter Market **Slammers** section.

Buy and charge both open the shared centered confirm modal (`AppModal` / `AppCenteredModal`, same shell as the match-fee dialog). The result line stays in that modal. Profile slammer cards show remaining uses and a Charge button for shop slammers (Starter stays Permanent, no button). Charge uses the same modal and `POST /authuser/market/slammers/recharge`.

### Charge spend

- `POST /service/avari/spend_slammer_charge` (Dart match) + authuser twin (practice)
- Lobby `verify_slammers` falls back when requested design has 0 charges
- Permanent starter never deducted

### Deferred

Recovery combat/feel stat. Per-slammer prices and charge pools (Genesis is one rate for now). Arcori Packs.

**Personal Legacy** (attunement, slammer mastery, physical mint that keeps the digital slammer) is a separate plan: [slammer-legacy.md](slammer-legacy.md). It is not the `recovery` stat and not Arcori `player_mastery`.

## Case study

Charge −1 per slam anytime a shop slammer is used. Every Genesis shop slammer: buy 4 Gold Arcori / 25 uses, top-up 4 Gold Arcori / +100. Starter is permanent and spends nothing. Old gold-cap prices and Event origin are not a sales channel. Recorded in [03_CASE_STUDY.md](03_CASE_STUDY.md) (no `case-study-*.html` in this repo).

## Files

- `bin/modules/catalog/data/series/genesis/slammers.json` — Shop economy on all non-starter Genesis slammers
- `bin/modules/market/market_skus.py` / `market_service.py` — shelf from catalog, not a Rim id list
- `lib/modules/market/screens/market_screen.dart` — featured + vertical list; buy/charge confirm modal
- `lib/modules/market/market_spend_modal.dart` — confirm, then result in the same modal
- `lib/modules/avari/widgets/slammer_inventory_tile.dart` — remaining uses + Charge
- `lib/modules/avari/screens/avari_profile_screen.dart` — profile Charge opens the market modal
- Local `catalog_designs` rows for the 11 SLM ids upserted from that JSON

## Notes

Rim is no longer a catalog design. Players who already own a shop slammer keep their current charge count. The 25-use grant applies to the next purchase. Top-up is still +100.

2026-10-27: Profile slammer card shows remaining uses and Charge (hidden on Permanent). Market buy and charge confirm in the existing centered modal; the success or error line replaces the confirm copy in that same modal. No new game-logic decision.

2026-10-27: Equipped slammer is the first page of the profile card. Market cards use the catalog disc (`imageUrl`) instead of the generic slammer mark. End-match Play New label is black.

## Task Manager

App Dev checklist checked: Genesis shop slammers (4 GA / 25, recharge 4 / +100, 1 use per slam; Starter free). Note added on the same card.

App Dev checklist 389 checked: profile remaining uses + Charge, and Market buy/charge confirm modal with the result in that modal.

App Dev checklist 390 checked: equipped slammer first on the profile card; Market cards show the catalog face; Play New label is black.
