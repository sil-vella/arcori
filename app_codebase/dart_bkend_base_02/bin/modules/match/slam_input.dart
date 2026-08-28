/// Raw slam gesture payload — validated wire shape; no slammer stat math.
library;

import '../../core/errors/app_error.dart';
import 'match_errors.dart';

const double slamInputSpeedMin = 0.0;
const double slamInputSpeedMax = 1.0;

/// Default down-vector when player times out or skips gesture.
Map<String, dynamic> timeoutSlamInput({String source = 'timeout'}) => {
      'speed': 0.0,
      'trajectory': {
        'dx': 0.0,
        'dy': 1.0,
        'angleDeg': 90.0,
      },
      'source': source,
    };

/// Parse and normalize optional slam `input` from action payload.
///
/// Returns null when absent. Throws [AppError] on invalid ranges/shape.
/// True when [active] still carries `graceEndsAt` (cleared by server after grace).
///
/// Presence is authoritative — do not arm input from local clock alone, or a
/// slightly-early client will commit during server grace and burn the turn.
bool activeInGracePeriod(Map<String, dynamic>? active) {
  if (active == null) return false;
  final raw = active['graceEndsAt']?.toString();
  return raw != null && raw.isNotEmpty;
}

Map<String, dynamic>? parseSlamInput(Map<String, dynamic> payload) {
  final raw = payload['input'];
  if (raw == null) return null;
  if (raw is! Map) {
    throw AppError(matchInvalidRequest, message: 'input must be a map');
  }
  final map = Map<String, dynamic>.from(raw);

  final speed = map['speed'];
  if (speed is! num) {
    throw AppError(matchInvalidRequest, message: 'input.speed required');
  }
  final speedVal = speed.toDouble();
  if (speedVal < slamInputSpeedMin || speedVal > slamInputSpeedMax) {
    throw AppError(matchInvalidRequest, message: 'input.speed out of range');
  }

  final trajectory = map['trajectory'];
  if (trajectory is! Map) {
    throw AppError(matchInvalidRequest, message: 'input.trajectory required');
  }
  final traj = Map<String, dynamic>.from(trajectory);
  final dx = traj['dx'];
  final dy = traj['dy'];
  if (dx is! num || dy is! num) {
    throw AppError(matchInvalidRequest, message: 'input.trajectory dx/dy required');
  }
  final dxVal = dx.toDouble();
  final dyVal = dy.toDouble();
  final len = (dxVal * dxVal + dyVal * dyVal);
  if (len < 1e-6) {
    throw AppError(matchInvalidRequest, message: 'input.trajectory zero vector');
  }

  final angleDeg = traj['angleDeg'];
  final out = <String, dynamic>{
    'speed': speedVal,
    'trajectory': <String, dynamic>{
      'dx': dxVal,
      'dy': dyVal,
      if (angleDeg is num) 'angleDeg': angleDeg.toDouble(),
    },
    if (map['source'] != null) 'source': map['source']?.toString(),
  };

  final swipe = map['swipe'];
  if (swipe is Map) {
    out['swipe'] = Map<String, dynamic>.from(swipe);
  }
  final motion = map['motion'];
  if (motion is Map) {
    out['motion'] = Map<String, dynamic>.from(motion);
  }
  return out;
}
