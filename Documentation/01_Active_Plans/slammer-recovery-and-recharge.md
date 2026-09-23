# Slammer Recovery + Charge Spend / Recharge

**Status:** Charge spend + Market Rim shipped; Recovery still deferred  
**Created:** 2026-09-05  
**Last Updated:** 2026-09-21

Related: [arcori-slam-impact.md](arcori-slam-impact.md) · [player-slam-input.md](player-slam-input.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md)

## Objective

1. **Recovery** — `gameplayAttributes.recovery` (1–10). Still unused in `resolveSlam`.
2. **Charge spend / Market recharge** — **shipped** for Rim Slammer.

## Live today

### Market (Rim)

| Action | Cost | Result |
|--------|------|--------|
| First buy | **4 Gold Arcori** | Own Rim + **20** charges |
| Top-up | **4 Gold Arcori** | **+100** charges |
| Per slam | **1 charge** | Online, events, and practice (permanent starter free) |

Endpoints: `GET/POST /authuser/market/slammers…`. Flutter Market **Slammers** section.

### Charge spend

- `POST /service/avari/spend_slammer_charge` (Dart match) + authuser twin (practice)
- Lobby `verify_slammers` falls back when requested design has 0 charges
- Permanent starter never deducted

### Deferred

Recovery combat/feel stat. Selling other Genesis slammers. Arcori Packs.

## Case study

Charge −1 per slam anytime used; Rim buy 4 / top-up 4 Gold Arcori (+100).
