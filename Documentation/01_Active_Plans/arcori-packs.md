# Arcori Packs (Gold purchase)

**Status:** Spec / backlog  
**Created:** 2026-09-17  
**Last Updated:** 2026-09-17

Related: [mastery.md](mastery.md) · [avari-profile.md](avari-profile.md) · starter grant (`starter_grant.py`) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md) (Market sink) · GDD Gold Arcori

## Objective

Sell **Arcori Packs** for **Gold Arcori**. On purchase, the backend **rolls** a configured count of **circulating** catalog designs at runtime (not a fixed SKU list) and grants each with **+5 mastery** + play access — same access/mastery model as starter / mastery unlocks, not Trove mints.

## Product rules

| Rule | Behavior |
|------|----------|
| Currency | Price in **Gold Arcori** (wallet); spend before roll; reject if insufficient |
| Contents | Pack defines **how many** designs (`count`) + **selection config** — not which ids |
| Selection | Runtime weighted/banded pick from **circulating** playable Arcori (`worldState` Active), exclude SLM / Kin / already owned access as configured |
| Mastery | Each opened design gets **+5 mastery** (grant access `source=pack` if new; bump existing mastery by 5) |
| Idempotency | Purchase ledger keyed by `orderId` / client request id so retries do not double-spend or double-grant |
| Reveal | API returns the rolled design cards; Flutter celebrate / inventory refresh |
| Not Trove | Packs grant **access + mastery**, never Legacy mint / Museum rows |

## Pack config (predefined SSOT)

JSON catalog (proposed): `modules/avari/data/arcori_packs.json` (or `modules/market/…` if Market module lands first).

Example shape:

```json
{
  "version": 1,
  "packs": [
    {
      "id": "pack_common_3",
      "displayName": "Common Pack",
      "priceGoldArcori": 5,
      "count": 3,
      "masteryGrant": 5,
      "selection": {
        "seriesKeys": ["genesis", "pioneers"],
        "excludeThemeCodes": ["SLM", "KIN"],
        "excludeOwned": true,
        "bands": [
          { "weightMin": 8.0, "weightMax": 10.0, "count": 2 },
          { "weightMin": 3.0, "weightMax": 7.0, "count": 1 }
        ]
      }
    }
  ]
}
```

- Hot-reload / mtime cache like other catalog JSON.
- New pack rows with existing selector → no client rebuild; new selector kinds need backend deploy.
- Align band language with [starter_grant.py](../../app_codebase/python_base_05/bin/modules/avari/starter_grant.py) where possible.

## Implementation steps

- [ ] Lock pack SKUs + prices + band configs (design pass)
- [ ] JSON SSOT + loader; validate `count` ↔ band counts
- [ ] Purchase service: affordability → debit Gold Arcori → roll → grant access + mastery 5 → ledger
- [ ] `POST /authuser/…/packs/purchase` (or Market route) + error codes (`insufficient_gold`, `pack_empty_pool`, …)
- [ ] Flutter Market / pack open UI (list packs, confirm spend, reveal results)
- [ ] Tests: spend, roll uniqueness, mastery bump, idempotent retry, empty-pool failure

## Current progress

- Spec only (this plan). No purchase/roll code yet.
- Reuse: `gold_economy`, `player_design_access`, mastery writers, circulating selectors from starter grant / catalog DB.

## Next steps

1. Confirm first SKU set (counts + prices) with design
2. Implement backend purchase + roll against `catalog_designs` circulating set
3. Minimal Market UI entry (can be Avari/Market stub until Home sink ships)

## Files (expected)

- `Documentation/01_Active_Plans/arcori-packs.md` (this file)
- `app_codebase/python_base_05/bin/modules/avari/` or new `market/` module (packs service, errors, routes)
- Pack JSON under module `data/`
- Flutter Market / pack reveal widgets
- Alembic: purchase ledger table (if not reusing an existing wallet ledger)

## Notes

- Distinct from **starter pack** (free on profile create, 10 designs @ mastery 10).
- Prefer selecting from Postgres `catalog_designs` (runtime SSOT), not theme JSON files alone.
- If pool cannot fill `count` after excludes, fail closed (no partial debit) or defined fallback — decide at implement time; default **fail closed + refund**.
- Task Manager: App Dev open checklist **Arcori Packs** (item still open; not implemented).
- **Last plan/TM align:** 2026-09-18 — echo seed / Closed Generations / catalog GEN marked done on App Dev.
