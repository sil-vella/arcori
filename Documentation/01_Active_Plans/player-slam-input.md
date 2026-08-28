# Player Slam Input

**Status:** Completed  
**Created:** 2026-08-22  
**Last Updated:** 2026-08-22

Related: [stub-match-turn-stages.md](stub-match-turn-stages.md) · [practice-stub-gameplay.md](practice-stub-gameplay.md) · [match-hot-state.md](match-hot-state.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Replace instant auto-stub slams with **5s turn windows** and **raw player input**: finger swipe down + phone motion fused into `speed` + `trajectory` on the wire. Slammer `gameplayAttributes` and Arcori effects remain out of scope (`result: stub`).

## Flow

```text
5s grace (active.graceEndsAt) → slams rejected until grace ends
active seat → human: Flutter SlamInputCapture (5s) → match/action input
           → AI: Dart turn runner 2–4s delay or miss → full 5s timeout
           → lastEvent echoes raw input; advance turn
           → after 2×N slams → endMatch
```

## Swipe tuning

- `minDownSwipeDy`: **12** logical px (was 24)
- Slow finger lifts (`primaryVelocity ≈ 0`): speed from drag distance (`swipeDy / 100`)

## Raw input (client)

- **Swipe:** `GestureDetector.onVerticalDrag*` → velocity + delta → trajectory
- **Motion:** `sensors_plus` `userAccelerometerEventStream` (peak magnitude during window)
- **Fusion:** global weights (not per-slammer); logged via `customlog` + `LOGGING_SWITCH`

## Dart

- `MatchTurnRunner` replaces `MatchStubLoop` burst
- `parseSlamInput` validates payload; `CoreActionPack._slam` echoes `input` on `lastEvent`
- Frozen catalog attrs **not** read yet (weighted slam follow-up)

## Files

- Dart: `slam_input.dart`, `turn_pacing.dart`, `match_turn_runner.dart`, `core_action_pack.dart`, `match_service.dart`
- Flutter: `input/slam_input_*.dart`, `match_action_client.dart`, `practice_match_surface.dart`, `match_notifier.dart`, `play_notifier.dart`

## Next

Weighted slam math (`impact` / `precision` / `control` / `recovery` / `spread` from freeze) → score / table state.
