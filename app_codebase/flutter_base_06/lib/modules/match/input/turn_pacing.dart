/// Shared turn timing + synthetic AI slam input (Dart online + Flutter practice).
library;

import 'dart:math';

import 'slam_input_models.dart';

const Duration matchStartGraceDefault = Duration(seconds: 5);
const Duration turnTimeoutDefault = Duration(seconds: 5);
const Duration aiDelayMinDefault = Duration(seconds: 2);
const Duration aiDelayMaxDefault = Duration(seconds: 4);
const double aiMissProbabilityDefault = 0.05;
const Duration turnPollInterval = Duration(milliseconds: 50);

/// Client hold after last sim frame before snap-to-stack (Flutter + server).
const Duration slamSettleHoldDefault = Duration(milliseconds: 1600);

/// Extra pad so the next turn does not start before [onAnimComplete].
const Duration slamAnimPadDefault = Duration(milliseconds: 300);

/// Fallback when a slam has no usable sim steps (tests may set [Duration.zero]
/// on the turn runner to disable holds entirely).
const Duration postSlamAnimHoldDefault = Duration(seconds: 5);

/// Physics timestep mirrored from [kSlamPhysicsDt] (avoid circular imports).
const double slamAnimDtDefault = 1.0 / 60.0;

/// Wall-clock hold after a slam: sim replay (steps×dt) + settle hold + pad.
Duration postSlamHoldForSimSteps(
  int steps, {
  double dt = slamAnimDtDefault,
  Duration settleHold = slamSettleHoldDefault,
  Duration pad = slamAnimPadDefault,
}) {
  final safeSteps = steps < 0 ? 0 : steps;
  final simMs = (safeSteps * dt * 1000.0).round();
  return Duration(milliseconds: simMs) + settleHold + pad;
}

/// Stamp authoritative client/server anim timing onto a physics [sim] map.
Map<String, dynamic> withSlamAnimTiming(Map<String, dynamic> sim) {
  final steps = sim['steps'] is num ? (sim['steps'] as num).toInt() : 0;
  final dt = sim['dt'] is num
      ? (sim['dt'] as num).toDouble()
      : slamAnimDtDefault;
  final hold = postSlamHoldForSimSteps(steps, dt: dt);
  return {
    ...sim,
    'steps': steps,
    'settleHoldMs': slamSettleHoldDefault.inMilliseconds,
    'animHoldMs': hold.inMilliseconds,
  };
}

/// Read hold from match [lastEvent] outcome.sim (after a slam).
Duration? animHoldFromLastEvent(Map<String, dynamic>? lastEvent) {
  if (lastEvent == null) return null;
  final outcome = lastEvent['outcome'];
  if (outcome is! Map) return null;
  final sim = outcome['sim'];
  if (sim is! Map) return null;
  if (sim['animHoldMs'] is num) {
    return Duration(milliseconds: (sim['animHoldMs'] as num).round());
  }
  if (sim['steps'] is num) {
    final dt = sim['dt'] is num
        ? (sim['dt'] as num).toDouble()
        : slamAnimDtDefault;
    return postSlamHoldForSimSteps((sim['steps'] as num).toInt(), dt: dt);
  }
  return null;
}

Duration randomAiDelay(
  Random rng, {
  Duration min = aiDelayMinDefault,
  Duration max = aiDelayMaxDefault,
}) {
  final span = max.inMilliseconds - min.inMilliseconds;
  if (span <= 0) return min;
  return Duration(milliseconds: min.inMilliseconds + rng.nextInt(span + 1));
}

bool rollAiMiss(Random rng, {double probability = aiMissProbabilityDefault}) {
  return rng.nextDouble() < probability;
}

Map<String, dynamic> syntheticAiSlamInput(Random rng) {
  // Soft AI band — often nudges / occasional flips, not wipeouts.
  final speed = 0.12 + rng.nextDouble() * 0.38;
  final aimX = (rng.nextDouble() - 0.5) * kSlamAimHitRadius * 0.6;
  final aimZ = (rng.nextDouble() - 0.5) * kSlamAimHitRadius * 0.6;
  final kick = kickDirectionFromAim(aimX, aimZ);
  return {
    'speed': speed,
    'aim': {'x': aimX, 'z': aimZ},
    'trajectory': {
      'dx': kick.dx,
      'dy': kick.dy,
      'angleDeg': atan2(kick.dy, kick.dx) * 180 / pi,
    },
    'source': 'ai_synthetic',
  };
}
