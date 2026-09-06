# Slammer Recovery + Charge Spend / Recharge

**Status:** Future  
**Created:** 2026-09-05  
**Last Updated:** 2026-09-05

Related: [arcori-slam-impact.md](arcori-slam-impact.md) · [player-slam-input.md](player-slam-input.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Implement the two deferred slammer systems that are catalogued but unused in live slam:

1. **Recovery** — `gameplayAttributes.recovery` (1–10). Combat/feel stat. Freeze already copies it; `resolveSlam` does not read it.
2. **Charge spend / recharge** — `economy.maxCharges`, `chargeCostPerUse`, `rechargeCostGoldCaps`. Gold Caps to refill non-permanent slammers. Not wired to slam or Market yet.

These are **not the same field**. Recovery does not change recharge cost.

## Live today (do not regress)

Slam uses frozen **impact**, **precision**, **control**, and **spread** only. Starter slammer is permanent (`maxCharges` null, recharge 0).

## Implementation Steps

- [ ] Define Recovery in slam (or document a different layer if it is not a kick stat)
- [ ] Deduct charges on paid-match slam for non-permanent slammers
- [ ] Gold Cap recharge flow (Market / inventory)
- [ ] Tests + tech spec / case study

## Notes

- Do not block celebration / Match Summary on this.
- Practice should stay free (no charge spend).

## Case study

`03_CASE_STUDY.md` — recovery + spend/recharge deferred; slam live attrs are impact / precision / control / spread.

## Task Manager

App Dev (`32`) open checklist: slammer recovery + charge spend / Gold Cap recharge.
