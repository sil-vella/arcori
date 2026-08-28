# Arcori Slam Impact

**Status:** Completed  
**Created:** 2026-08-23  
**Last Updated:** 2026-08-23

Related: [player-slam-input.md](player-slam-input.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Face-down Arcori stack on the table; slam input + frozen slammer attrs resolve flips and scores (Dart SSOT); Flutter animates with `SpringSimulation` from live impulse and settles to authority faces.

## Flow

```text
match start → table.pieces faceDown (1 per seat)
slam input → resolveSlam(attrs, power) → faceUp + score + impulse
Flutter: predictive spring → settle to table.pieces
round advance → restackFaceDown
```

## Files

- Dart: `table_pieces.dart`, `slam_resolver.dart`, `core_action_pack.dart`, `match_store.dart`
- Flutter: `input/slam_resolver.dart`, `arcori_disc.dart`, `arcori_stack_surface.dart`, snapshot `table` mirror

## Next

Random first player; celebration / Match Summary.
