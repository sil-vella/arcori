# Catalog in Postgres + GEN in serial

**Status:** Completed  
**Created:** 2026-09-17  
**Last Updated:** 2026-09-18

Related: [legacy-preserve.md](legacy-preserve.md) · [museum-browse.md](museum-browse.md) · Tech Spec

## Objective

Embed `GENnnn` in every Arcori `internalId`, make Postgres `catalog_designs` the runtime catalog SSOT, keep theme JSON as admin authoring input, and provide a wfrun dash script to scan/import new JSON additions.

## Product / tech rules

| Rule | Behavior |
|------|----------|
| Serial | `{THEME}-{CODE}-SERnnn-GENnnn-####` e.g. `ANM-TIG-SER001-GEN001-0001` |
| Runtime SSOT | `catalog_designs` (seed / import / echo) |
| Authoring | `data/series/**/*.json` — not mutated on Legacy close |
| Echo | New DB row + lifecycle on new serial + copy `player_design_access`; **random approved disc `color`**; art/Lottie reuse `art_basename`; mastery soft seed — [legacy-preserve.md](legacy-preserve.md) / [mastery.md](mastery.md) |
| Art | `:ro` mount; `art_basename` strips GEN for webp path |
| Face media | Any theme may set `faceMedia: lottie` + `lottieUrl` (Kin resolves via `/media/kin/players/…`; regular designs pass through catalog doc) |

## Ops

1. Apply Alembic `026_catalog_designs_gen_serial` (plus later `027`/`028` for closed-gen snapshots)
2. `wfrun` → `automation/backend/import_catalog_designs.py` — lists new ids + count, then prompts `Import now? [y/N]`
3. Answer **y** to seed/import (or pass `--apply` to skip the prompt)

## Current progress

Completed. Kin Lottie URLs use `art_basename` so GEN-in-serial ids resolve pre-GEN files. Regular designs pass through `lottieUrl` / `faceMedia`.

## Files

- `modules/catalog/catalog_ids.py`, `catalog_repository.py`, `catalog_authoring.py`, `kin_design_store.py`
- `models/catalog_design.py` + alembic `026_…`
- `catalog_service` / `catalog_select` / Legacy echo / Kin mint / starter slammer id
- `automation/backend/import_catalog_designs.py`
