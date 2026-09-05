/// Raw slam input wire models — client capture only; no slammer stat math.
library;

import 'dart:math';

import 'slam_physics_world.dart';

/// Higher caps → same gesture maps to lower speed (weak slam still commits).
const double swipeMaxPxPerSec = 3500;
const double swipeMaxDragDy = 280;
const double motionMaxMps2 = 28;

/// Minimum user-accelerometer |Z| (m/s²) to commit a shake slam.
/// Kept well above casual tilt noise; XY must not dominate (see capture).
const double kMinShakeMps2 = 4.5;

/// Raw accelerometer |Z−g| (m/s²) — fallback when user accel is flat.
const double kMinRawShakeDelta = 3.5;

/// Standard gravity — raw accelerometer shake uses deviation from this.
const double gravityMps2 = 9.80665;

/// Stack footprint / slammer aim radius — same as a disc.
const double kSlamAimHitRadius = kDiscRadius;

/// Max aim travel on table (m) — matches physics wall soft limit.
const double kSlamAimAxisLimit = kWallLimit;

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

class SlamAim {
  const SlamAim({required this.x, required this.z});

  final double x;
  final double z;

  static const center = SlamAim(x: 0, z: 0);

  SlamAim clampToTable() => SlamAim(
        x: x.clamp(-kSlamAimAxisLimit, kSlamAimAxisLimit),
        z: z.clamp(-kSlamAimAxisLimit, kSlamAimAxisLimit),
      );

  Map<String, dynamic> toJson() => {'x': x, 'z': z};
}

class SlamTrajectory {
  const SlamTrajectory({
    required this.dx,
    required this.dy,
    required this.angleDeg,
  });

  final double dx;
  final double dy;
  final double angleDeg;

  Map<String, dynamic> toJson() => {
        'dx': dx,
        'dy': dy,
        'angleDeg': angleDeg,
      };

  factory SlamTrajectory.fromAim(SlamAim aim) {
    final kick = kickDirectionFromAim(aim.x, aim.z);
    return SlamTrajectory(
      dx: kick.dx,
      dy: kick.dy,
      angleDeg: atan2(kick.dy, kick.dx) * 180 / pi,
    );
  }
}

class SlamInputPayload {
  const SlamInputPayload({
    required this.speed,
    required this.aim,
    required this.source,
    this.trajectory,
    this.swipe,
    this.motion,
  });

  final double speed;
  final SlamAim aim;
  final String source;
  final SlamTrajectory? trajectory;
  final Map<String, dynamic>? swipe;
  final Map<String, dynamic>? motion;

  Map<String, dynamic> toJson() {
    final traj = trajectory ?? SlamTrajectory.fromAim(aim);
    return {
      'speed': speed,
      'aim': aim.toJson(),
      'trajectory': traj.toJson(),
      'source': source,
      if (swipe != null) 'swipe': swipe,
      if (motion != null) 'motion': motion,
    };
  }
}

SlamInputPayload timeoutSlamInput({String source = 'timeout'}) {
  return SlamInputPayload(
    speed: 0,
    aim: SlamAim.center,
    trajectory: const SlamTrajectory(dx: 0, dy: 1, angleDeg: 90),
    source: source,
  );
}

Map<String, dynamic> timeoutSlamInputMap({String source = 'timeout'}) =>
    timeoutSlamInput(source: source).toJson();

SlamInputPayload webFallbackSlamInput() {
  return timeoutSlamInput(source: 'web_fallback');
}

/// Touch swipe power commit — speed from vertical drag; aim already frozen.
SlamInputPayload fuseTouchPowerSlam({
  required double swipePrimaryVelocity,
  required double swipeDy,
  required SlamAim aim,
  String source = 'gesture',
}) {
  final swipeSpeedFromVelocity =
      (swipePrimaryVelocity.abs() / swipeMaxPxPerSec).clamp(0.0, 1.0);
  final swipeSpeedFromDistance =
      (swipeDy / swipeMaxDragDy).clamp(0.0, 1.0);
  final speed = swipeSpeedFromVelocity > swipeSpeedFromDistance
      ? swipeSpeedFromVelocity
      : swipeSpeedFromDistance;

  return SlamInputPayload(
    speed: speed,
    aim: aim.clampToTable(),
    trajectory: SlamTrajectory.fromAim(aim),
    source: source,
    swipe: {
      'primaryVelocity': swipePrimaryVelocity,
      'velocityPxPerSec': {'x': 0.0, 'y': swipePrimaryVelocity},
      'delta': {'dx': 0.0, 'dy': swipeDy},
    },
  );
}

/// Accel Z-shake power commit — aim already frozen from XY.
SlamInputPayload fuseAccelPowerSlam({
  required double motionPeakMagnitude,
  required double motionPeakX,
  required double motionPeakY,
  required double motionPeakZ,
  required SlamAim aim,
  String source = 'shake',
}) {
  final speed = (motionPeakMagnitude / motionMaxMps2).clamp(0.0, 1.0);
  return SlamInputPayload(
    speed: speed,
    aim: aim.clampToTable(),
    trajectory: SlamTrajectory.fromAim(aim),
    source: source,
    swipe: const {
      'primaryVelocity': 0.0,
      'velocityPxPerSec': {'x': 0.0, 'y': 0.0},
      'delta': {'dx': 0.0, 'dy': 0.0},
    },
    motion: {
      'peakMagnitude': motionPeakMagnitude,
      'peak': {'x': motionPeakX, 'y': motionPeakY, 'z': motionPeakZ},
    },
  );
}
