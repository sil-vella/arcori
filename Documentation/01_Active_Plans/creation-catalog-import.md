# Creation Catalog Import

**Status**: Completed  
**Created**: 2026-09-26  
**Last Updated**: 2026-09-26

## Objective

Convert new Creation PNGs under `000_creation/{the_light,the_dark}/` to catalog webp and append SER000 designs.

## Done

- [x] Convert ChatGPT PNGs (1254²) to `{themeCode}-{designCode}-SER000-0002.webp`
- [x] Append catalog JSON: Ivory Gatewalker (`LGT-IGW`) + Eclipse Veilwalker (`DRK-EVW`)
- [x] Bind regions from the art (Everlight Grove / Ashdrift Hill), not Velora
- [x] Keep Creation `selectionWeight` 0.01, legacy 50/100, out of starter pool
- [x] Archive source PNGs under `additions/_imported_creation/`

## Designs

| Design | Theme | Art | Region | Why that land |
|--------|-------|-----|--------|----------------|
| The Light (existing) | The Light | `LGT-TLT-SER000-0001.webp` | Ashdrift Hill | Ash hospital corridor |
| Ivory Gatewalker | The Light | `LGT-IGW-SER000-0002.webp` | Everlight Grove | Luminous ruined gate-city |
| The Dark (existing) | The Dark | `DRK-TDK-SER000-0001.webp` | Amberwild | Amber forest |
| Eclipse Veilwalker | The Dark | `DRK-EVW-SER000-0002.webp` | Ashdrift Hill | Eclipse, fire-cracked ruin |

Same primordial beings as 0001, different settings — not pixel replicas.

## Paths

- JSON: `app_codebase/python_base_05/bin/modules/catalog/data/series/creation/`
- Art: `assets/images/arcori/000_creation/{the_light,the_dark}/`
- Import tool: `import_creation_additions.py`

## Notes

- JSON `internalId` includes `GEN001`; art filenames omit GEN.
- Runtime catalog SSOT is Postgres — run `wfrun automation/backend/import_catalog_designs.py` to seed the new ids.

## Case study

Updated Creation row in `03_CASE_STUDY.md` (4 designs; regions from art).

## Task Manager

App Dev checklist: Creation seq 0002 import (`SER000`).
