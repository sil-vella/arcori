# Arcori Standings Surface

**Status:** Spec + Velora browse slice; Standings/My Mastery still open  
**Created:** 2026-07-24  
**Last Updated:** 2026-07-25

Related: [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md) · [Tech Spec](../Game_Specific/Arcori_Technical_Specification_v0.4.md) · [Content Bible](../Game_Specific/Arcori_Content_Bible_v0.4.md) · [catalog-hot-reload.md](catalog-hot-reload.md)

## Objective

Define Velora / Trove / Arcori Detail (Standings + My Mastery) and transport (HTTP + WS nudge).

## Semantics

- **Mastery** on circulating designs ≠ ownership.
- **Trove** = minted closed Arcori only (out of circulation).
- **Museum** = world history of closed generations (not personal Trove).
- Starter “Arcori” grants = play/mastery access, not mints.

## Surfaces

| Surface | Role |
|---------|------|
| Velora | World browse → Arcori Detail (default Standings later) |
| Trove | Minted list only |
| Arcori Detail | SSOT; submenu Standings, My Mastery (deferred) |
| Sink | Trove • PLAY • Market (PLAY = circulating access) |

## Done (Flutter browse slice)

- Velora: circulating catalog index grouped **theme → series**; tiles with circle thumbs via `/catalog-media` + `imageUrl`
- Arcori Detail: circle-cropped art + design fields (no Standings / My Mastery tabs yet)
- Entry: Home CTA + drawer; paths `/velora`, `/velora/arcori?id=`

## Transport

HTTP on enter; optional WS `standings_changed` / mint invalidate while Detail open. No per-flip streams.

## Implementation Steps

- [x] Document already aligned in Game_Specific (this plan)
- [x] Catalog authuser APIs + `/catalog-media` + Flutter Velora browse / Detail shell
- [ ] REST standings + my-mastery endpoints
- [ ] Flutter Standings / My Mastery on Detail; Trove
- [ ] Optional WS invalidate hooks

## Notes

Full placement rationale lives in Cursor plan `live_arcori_stats_placement`.
