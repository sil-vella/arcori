/// Raw slam gesture payload — validated wire shape; no slammer stat math.
library;

import 'dart:math';

import '../../core/errors/app_error.dart';
import 'match_errors.dart';
import 'slam_physics_world.dart';

const double slamInputSpeedMin = 0.0;
const double slamInputSpeedMax = 1.0;

/// Stack footprint / slammer aim radius — same as a disc.
const double kSlamAimHitRadius = kDiscRadius;

double _clampAimAxis(double v) => v.clamp(-kWallLimit, kWallLimit);

/// Kick direction from aim offset on the table (XZ). Center → straight into stack.
({double dx, double dy}) kickDirectionFromAim(double aimX, double aimZ) {
  final hitR = kSlamAimHitRadius;
  final nx = (aimX / hitR).clamp(-1.0, 1.0);
  final nz = (aimZ / hitR).clamp(-1.0, 1.0);
  final dist = sqrt(nx * nx + nz * nz).clamp(0.0, 1.0);
  final dx = nx * 0.95;
  final dy = max(0.25, 1.0 - dist * 0.55);
  final len = sqrt(dx * dx + dy * dy);
  if (len < 1e-6) return (dx: 0.0, dy: 1.0);
  return (dx: dx / len, dy: dy / len);
}

bool aimOutsideStackFootprint(double aimX, double aimZ) {
  return aimX * aimX + aimZ * aimZ > kSlamAimHitRadius * kSlamAimHitRadius;
}

/// Default down-vector when player times out or skips gesture.
Map<String, dynamic> timeoutSlamInput({String source = 'timeout'}) => {
      'speed': 0.0,
      'aim': {'x': 0.0, 'z': 0.0},
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

/// True while [active] carries `inputLockedUntil` (cleared after post-slam anim hold).
///
/// Presence is authoritative — next seat is already in `active.seatIndex`, but
/// input/UI must stay locked until the server clears this after [animHoldMs].
bool activeInputLocked(Map<String, dynamic>? active) {
  if (active == null) return false;
  final raw = active['inputLockedUntil']?.toString();
  return raw != null && raw.isNotEmpty;
}

/// Stamp post-slam input lock onto an advanced [active] map.
Map<String, dynamic> activeWithAnimLock(
  Map<String, dynamic> active,
  Duration hold,
) {
  final next = Map<String, dynamic>.from(active);
  if (hold <= Duration.zero) {
    next.remove('inputLockedUntil');
    return next;
  }
  next['inputLockedUntil'] =
      DateTime.now().toUtc().add(hold).toIso8601String();
  return next;
}

Map<String, dynamic> activeWithoutAnimLock(Map<String, dynamic>? active) {
  if (active == null) return const {'seatIndex': 0, 'action': 'slam'};
  final next = Map<String, dynamic>.from(active)..remove('inputLockedUntil');
  return next;
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

  final aimRaw = map['aim'];
  if (aimRaw is! Map) {
    throw AppError(matchInvalidRequest, message: 'input.aim required');
  }
  final aimMap = Map<String, dynamic>.from(aimRaw);
  final ax = aimMap['x'];
  final az = aimMap['z'];
  if (ax is! num || az is! num) {
    throw AppError(matchInvalidRequest, message: 'input.aim x/z required');
  }
  final aimX = _clampAimAxis(ax.toDouble());
  final aimZ = _clampAimAxis(az.toDouble());

  // Optional legacy trajectory (debug / older clients). Kick bias prefers aim.
  Map<String, dynamic>? trajOut;
  final trajectory = map['trajectory'];
  if (trajectory is Map) {
    final traj = Map<String, dynamic>.from(trajectory);
    final dx = traj['dx'];
    final dy = traj['dy'];
    if (dx is num && dy is num) {
      final dxVal = dx.toDouble();
      final dyVal = dy.toDouble();
      final len = (dxVal * dxVal + dyVal * dyVal);
      if (len >= 1e-6) {
        final angleDeg = traj['angleDeg'];
        trajOut = <String, dynamic>{
          'dx': dxVal,
          'dy': dyVal,
          if (angleDeg is num) 'angleDeg': angleDeg.toDouble(),
        };
      }
    }
  }

  final out = <String, dynamic>{
    'speed': speedVal,
    'aim': {'x': aimX, 'z': aimZ},
    if (trajOut != null) 'trajectory': trajOut,
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
