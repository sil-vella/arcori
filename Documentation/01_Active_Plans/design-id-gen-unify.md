# Design id GEN unify (Arcori + Slammers)

**Status:** Shipped (core)  
**Created:** 2026-10-15  
**Last Updated:** 2026-10-15

Related: [catalog-db-gen-serial.md](catalog-db-gen-serial.md) · [slammer-legacy.md](slammer-legacy.md)

## Objective

One wire/storage form for every Arcori and Slammer design id:

`{TYPE}-{THEME}-{CODE}-SERnnn-GENnnn-####`  
e.g. `ARC-ANM-TIG-SER001-GEN001-0001`, `SLM-SLM-STR-SER001-GEN001-0001`

| Token | Meaning |
|-------|---------|
| `TYPE` | `ARC` (disc) / `SLM` (slammer) — Kin stays `KIN-{token}-…` |
| `THEME` | Theme code (`ANM`, `SLM`, …) |
| `CODE` | Design code (`TIG`, `STR`, …) |
| `SERnnn` | Series |
| `GENnnn` | Generation |

Legacy forms (no TYPE / no GEN) remain **aliases for lookups** (art basename, old prefs) but must not create duplicate inventory rows.

## Why

Catalog + starter grant already use GEN. Match stubs / equipped prefs / mastery finalize still stamped the short starter id → duplicate profile tiles + false `slammer_no_charges` on the short row.

## Rules

| Layer | Behavior |
|-------|----------|
| Writes | `ensure_gen001` before insert/update |
| Reads | `design_id_aliases` match |
| Profile list | Dedupe by `family_key`, prefer GEN row, merge mastery stats |
| Art / Lottie | Unchanged — `art_basename` strips GEN |
| Clients | Stub / practice / equipped default = GEN001 form; migrate short prefs on load |

## Tasks

- [x] Canonicalize `ensure_slammer` / `get_slammer` / `apply_slammer_mastery`
- [x] `verify_slammers` + `spend_slammer_charge` alias-aware; return GEN id
- [x] Profile slammer payload dedupe
- [x] Alembic `031` merge short→GEN `player_slammers`
- [x] Dart/Flutter stub + practice maps → GEN001
- [x] Apply migration + confirm single starter on profile (mastery merged)
- [x] Insert `TYPE` (`ARC`/`SLM`) into canonical id + Alembic `032` + authoring JSON rewrite
- [x] Art basename strips TYPE+GEN; aliases cover legacy forms

## Files

- `modules/catalog/catalog_ids.py` (helpers already present)
- `modules/avari/avari_repository.py`, `avari_service.py`
- `alembic/versions/031_unify_design_id_gen.py`
- Dart `match_models.dart` stub; Flutter match/play stubs + practice maps
