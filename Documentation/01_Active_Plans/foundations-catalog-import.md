# Foundations Catalog Import

**Status**: Completed  
**Created**: 2026-09-13  
**Last Updated**: 2026-09-13

## Objective

Import Foundations series art from `assets/images/arcori/003_foundations` (manifests + webp) into catalog JSON and numbered theme art dirs.

## Done

- [x] Parse manifests (v1 + v2 × 40 themes)
- [x] Write `data/series/foundations/{theme}.json` (120 designs = 40 themes × 3, `SER003`, legacy 250/500)
- [x] Rename art to `{themeCode}-{designCode}-SER003-####.webp` under `003_foundations/{theme}/`
- [x] Round 3 additions from `assets/images/arcori/additions/` → seq `0003` per theme
- [x] Register new theme codes in `00_themes_subthemes.json` (Music reuses `MUS`)
- [x] Prefer Genesis when `get_theme` hits shared themeCodes
- [x] Document series in Tech Spec / GDD / Content Bible / World Bible / case study

## Paths

- JSON: `app_codebase/python_base_05/bin/modules/catalog/data/series/foundations/`
- Art: `assets/images/arcori/003_foundations/{theme}/`
- Public URL: `/catalog-media/003_foundations/{theme}/{internalId}.webp`
- Import tool: `app_codebase/python_base_05/tools/import_foundations_series.py` (already applied; keep for reference)
