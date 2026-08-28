/// Shared turn timing + synthetic AI slam input (Dart online + Flutter practice).
library;

import 'dart:math';

const Duration matchStartGraceDefault = Duration(seconds: 5);
const Duration turnTimeoutDefault = Duration(seconds: 5);
const Duration aiDelayMinDefault = Duration(seconds: 2);
const Duration aiDelayMaxDefault = Duration(seconds: 4);
const double aiMissProbabilityDefault = 0.05;
const Duration turnPollInterval = Duration(milliseconds: 50);

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
