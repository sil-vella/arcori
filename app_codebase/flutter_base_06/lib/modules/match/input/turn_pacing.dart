/// Practice / online turn timing constants (mirrors Dart turn_pacing.dart).
library;

import 'dart:math';

const Duration matchStartGraceDefault = Duration(seconds: 5);
const Duration turnTimeoutDefault = Duration(seconds: 5);
const Duration aiDelayMinDefault = Duration(seconds: 2);
const Duration aiDelayMaxDefault = Duration(seconds: 4);
const double aiMissProbabilityDefault = 0.05;
const Duration turnPollInterval = Duration(milliseconds: 50);

/// TEST: hold after each slam so sim replay / result modal can finish before
/// the next seat. Set to [Duration.zero] when done testing.
const Duration postSlamAnimHoldDefault = Duration(seconds: 5);

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
  final speed = 0.35 + rng.nextDouble() * 0.55;
  final dx = (rng.nextDouble() - 0.5) * 0.25;
  final dy = 0.88 + rng.nextDouble() * 0.12;
  return {
    'speed': speed,
    'trajectory': {
      'dx': dx,
      'dy': dy,
      'angleDeg': atan2(dy, dx) * 180 / pi,
    },
    'source': 'ai_synthetic',
  };
}

Map<String, dynamic> timeoutSlamInputMap({String source = 'timeout'}) {
  return {
    'speed': 0.0,
    'trajectory': {'dx': 0.0, 'dy': 1.0, 'angleDeg': 90.0},
    'source': source,
  };
}
