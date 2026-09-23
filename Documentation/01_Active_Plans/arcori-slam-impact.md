# Arcori Slam Impact

**Status:** Completed  
**Created:** 2026-08-23  
**Last Updated:** 2026-09-23

Related: [player-slam-input.md](player-slam-input.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md) · [slammer-recovery-and-recharge.md](slammer-recovery-and-recharge.md)

## Objective

Face-down Arcori stack on the table; slam input + frozen slammer attrs resolve flips and scores (Dart SSOT); Flutter plays a **face-up equipped-slammer strike** beat, then animates scatter from live impulse / sim and settles to authority faces.

## Slammer resolve pipeline (SSOT)

Dart `resolveSlam` (Flutter practice mirror identical). Frozen catalog `gameplayAttributes` shape the outcome in this order:

```text
aim + speed
  → precision/control jitter on kick direction
  → power = speed × (impact/10)          // 0 = none, 1 = full
  → hard miss if aim outside footprint
  → preferenceFit(hitTarget, powerBracket band)
  → effectivePower = power × (0.55 + 0.70 × fit)
  → runSlamPhysics(effectivePower, spread)
  → faceUp / score / impulse / sim
```

### Live 1–10 attrs (still affect outcome)

| Attr | Effect |
|------|--------|
| **impact** | Scales raw resolve power from input speed |
| **precision** | Higher → less angular kick jitter (more accurate) |
| **control** | Higher → further damps that jitter (more stable) |
| **spread** | Fans how hard pieces scatter in physics (not who gets kicked) |
| **recovery** | Catalog / profile only — **not used** in resolve yet |

There is no separate `inaccuracy` / `unpredictability` / `instability` field. Wildness is low precision/control + high spread + high power (physics also adds power-scaled chaos).

### Preferred slam conditions

| Field | Meaning |
|-------|---------|
| `hitTarget` | `center` \| `mid` \| `edge` — preferred aim radius on the stack footprint (`center→0`, `mid→0.5`, `edge→1`) |
| `powerBracket` | `{ "min", "max" }` preferred resolve-power **band** in `0..1` (e.g. starter `{0.55, 0.85}`) |

Match quality after raw `power` is known (`hitTol≈0.45`, `powerTol≈0.45` outside the band):

1. `hitMatch` — how close aim radius is to the preferred radius  
2. `powerMatch` — **1.0** when power is inside `[min, max]`; falls off by distance outside / `powerTol`  
3. `preferenceFit = sqrt(hitMatch × powerMatch)`  
4. `effectivePower = power × (0.55 + 0.70 × preferenceFit)` → physics / impulse  

| Slam (starter prefs: center + 0.55–0.85; precision/control 3) | Fit | Flip effect |
|------------------------------------------------------------|-----|-------------|
| Centered + power in band (~mid–high) | High | Strong flip boost |
| Centered + soft ~40% power (below band) | Medium–low | Milder flips |
| Edge + soft power | Low | Weak flips |

Starter catalog feel: rewards center hits and mid–high power, but lower precision/control means more kick jitter (less “laser” accuracy). System defaults when attrs missing: `hitTarget: "center"`, `powerBracket: {min: 0.4, max: 0.6}`. Legacy single-number `powerBracket` expands to a ±0.1 band.

Prefs **do not replace** impact / precision / control / spread — they multiply kick energy after those attrs have already shaped the slam.

## Flow

```text
match start → table.pieces faceDown (1 per seat); seats stamped with slammer face
slam input → resolveSlam (attrs + prefs → effectivePower) → faceUp + score + impulse/sim
Flutter: equipped-slammer fly-in → tumble/scatter with Arcori (face up or down)
       → both animate back (Arcori→stack, slammer→last player) → settle
round advance → restackFaceDown (client animates return; table already face-down)
animHoldMs = strike + steps×dt + settleHold + pad
```

## Files

- Dart: `table_pieces.dart` (`stampSlammerFaces`), `slam_resolver.dart`, `slam_physics_world.dart`, `core_action_pack.dart`, `match_store.dart`, `turn_pacing.dart`
- Flutter: `input/slam_resolver.dart`, `arcori_disc.dart`, `arcori_stack_surface.dart`, `slammer_strike_overlay.dart`, snapshot `table` + seat face fields
- Catalog / API: `catalog/data/series/genesis/slammers.json`; Avari `_gameplay_attributes`; Flutter `SlammerGameplayAttributes` / `SlammerPowerBracket`

## Next

Celebration / Match Summary. **Deferred:** slammer Recovery slam-stat + charge spend / Gold Cap recharge — [slammer-recovery-and-recharge.md](slammer-recovery-and-recharge.md).
