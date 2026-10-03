import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Peak pixel amplitude at the start of a local slam hit shake.
const double kSlamHitShakePeakPx = 16.0;

/// Screen-shake offset for raw clock [t] in 0..1 (decays to zero).
Offset slamHitShakeOffset(double t, {int seed = 0}) {
  final u = t.clamp(0.0, 1.0);
  if (u <= 0 || u >= 1) return Offset.zero;
  final decay = (1.0 - u) * (1.0 - u);
  final rng = Random(seed ^ (u * 1000).round());
  final angle = rng.nextDouble() * pi * 2;
  final amp = kSlamHitShakePeakPx * decay;
  return Offset(cos(angle) * amp, sin(angle) * amp);
}

/// Short motor pulse on stack contact (~45ms). Falls back to system haptic.
///
/// Call only for the local player's slam.
Future<void> slamHitVibrate() async {
  try {
    if (await Vibration.hasVibrator()) {
      final amplitude = await Vibration.hasAmplitudeControl() ? 180 : -1;
      // Motor pulse + system haptic — OEMs often mute one or the other.
      unawaited(HapticFeedback.heavyImpact());
      await Vibration.vibrate(duration: 80, amplitude: amplitude);
      if (LOGGING_SWITCH) {
        customlog('slamHit: vibrate durationMs=80 amplitude=$amplitude');
      }
      return;
    }
  } catch (e) {
    if (LOGGING_SWITCH) {
      customlog('slamHit: vibrate fail err=$e → haptic');
    }
  }
  await HapticFeedback.heavyImpact();
  if (LOGGING_SWITCH) {
    customlog('slamHit: haptic heavyImpact');
  }
}
