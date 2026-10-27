# Velora world regions

**Status:** Implemented  
**Created:** 2026-10-26  
**Last Updated:** 2026-10-26

## Objective

On `/velora/world`, show the five lands and the Realm Beyond as tappable tiles. Each opens `/velora/region` with lore, alliance, standings, and places from the world bible and `01_regions.json`.

## Decisions

- Copy follows the bible and catalog. Ashdrift Hill and Everlight Grove are hostile over the ash. The Veiled Accord is Ashdrift + Moonwake. The Living Pact is Everlight + Amberwild. Little Frost stays independent. The Realm Beyond has no standings.
- Region and place art is a 640px WebP under `flutter_base_06/assets/images/velora/regions/{slug}/`. Source PNGs stay in the repo `assets/images/velora/regions/` for catalog. Unnamed Realm Beyond `variant-a` / `variant-b` files are not shown.

## Files

- `lib/modules/velora/velora_regions.dart`
- `lib/modules/velora/screens/velora_world_screen.dart`
- `lib/modules/velora/screens/velora_region_screen.dart`
