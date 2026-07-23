import 'dart:math' as math;

/// Backoff settings for unexpected WebSocket disconnects.
class WsReconnectPolicy {
  const WsReconnectPolicy({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;

  Duration delayForAttempt(int attempt) {
    if (attempt <= 0) return initialDelay;
    final ms = initialDelay.inMilliseconds * math.pow(multiplier, attempt);
    final capped = ms.clamp(0, maxDelay.inMilliseconds.toDouble());
    return Duration(milliseconds: capped.round());
  }
}

const defaultWsReconnectPolicy = WsReconnectPolicy();
