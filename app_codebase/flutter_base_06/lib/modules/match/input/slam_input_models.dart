/// Raw slam input wire models — client capture only; no slammer stat math.
library;

import 'dart:math';

/// Higher caps → same gesture maps to lower speed (weak slam still commits).
const double swipeMaxPxPerSec = 3500;
const double swipeMaxDragDy = 280;
const double motionMaxMps2 = 28;
const double swipeFusionWeight = 0.6;
const double motionFusionWeight = 0.4;
const double trajectorySwipeWeight = 0.7;

/// Minimum user-accelerometer peak (m/s²) to commit a shake-only slam.
const double kMinShakeMps2 = 1.0;

/// Raw accelerometer deviation from ~1g (m/s²) — fallback when user accel is flat.
const double kMinRawShakeDelta = 0.8;

/// Standard gravity — raw accelerometer shake uses deviation from this.
const double gravityMps2 = 9.80665;

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
}

class SlamInputPayload {
  const SlamInputPayload({
    required this.speed,
    required this.trajectory,
    required this.source,
    this.swipe,
    this.motion,
  });

  final double speed;
  final SlamTrajectory trajectory;
  final String source;
  final Map<String, dynamic>? swipe;
  final Map<String, dynamic>? motion;

  Map<String, dynamic> toJson() {
    return {
      'speed': speed,
      'trajectory': trajectory.toJson(),
      'source': source,
      if (swipe != null) 'swipe': swipe,
      if (motion != null) 'motion': motion,
    };
  }
}

SlamInputPayload timeoutSlamInput({String source = 'timeout'}) {
  return SlamInputPayload(
    speed: 0,
    trajectory: const SlamTrajectory(dx: 0, dy: 1, angleDeg: 90),
    source: source,
  );
}

Map<String, dynamic> timeoutSlamInputMap({String source = 'timeout'}) =>
    timeoutSlamInput(source: source).toJson();

SlamInputPayload webFallbackSlamInput() {
  return timeoutSlamInput(source: 'web_fallback');
}

/// Fuse swipe + motion samples into raw speed and trajectory.
SlamInputPayload fuseSlamInput({
  required double swipePrimaryVelocity,
  required double swipeDx,
  required double swipeDy,
  required double motionPeakMagnitude,
  double? motionPeakX,
  double? motionPeakY,
  double? motionPeakZ,
  bool motionAvailable = true,
  String source = 'gesture',
}) {
  final swipeSpeedFromVelocity =
      (swipePrimaryVelocity.abs() / swipeMaxPxPerSec).clamp(0.0, 1.0);
  final swipeSpeedFromDistance =
      (swipeDy / swipeMaxDragDy).clamp(0.0, 1.0);
  final swipeSpeed = swipeSpeedFromVelocity > swipeSpeedFromDistance
      ? swipeSpeedFromVelocity
      : swipeSpeedFromDistance;
  final motionSpeed = motionAvailable
      ? (motionPeakMagnitude / motionMaxMps2).clamp(0.0, 1.0)
      : 0.0;
  final speed =
      (swipeFusionWeight * swipeSpeed + motionFusionWeight * motionSpeed)
          .clamp(0.0, 1.0);

  final swipeLen = sqrt(swipeDx * swipeDx + swipeDy * swipeDy);
  var sdx = swipeLen > 1e-6 ? swipeDx / swipeLen : 0.0;
  var sdy = swipeLen > 1e-6 ? swipeDy / swipeLen : 1.0;

  if (motionAvailable &&
      motionPeakX != null &&
      motionPeakY != null &&
      motionPeakZ != null) {
    final mx = motionPeakX;
    final my = motionPeakY;
    final mz = motionPeakZ.abs();
    final mLen = sqrt(mx * mx + my * my + mz * mz);
    if (mLen > 1e-6) {
      final mdx = mx / mLen;
      final mdy = my / mLen;
      final blend = trajectorySwipeWeight;
      sdx = blend * sdx + (1 - blend) * mdx;
      sdy = blend * sdy + (1 - blend) * mdy;
      final tLen = sqrt(sdx * sdx + sdy * sdy);
      if (tLen > 1e-6) {
        sdx /= tLen;
        sdy /= tLen;
      }
    }
  }

  final angleDeg = atan2(sdy, sdx) * 180 / pi;

  return SlamInputPayload(
    speed: speed,
    trajectory: SlamTrajectory(dx: sdx, dy: sdy, angleDeg: angleDeg),
    source: source,
    swipe: {
      'primaryVelocity': swipePrimaryVelocity,
      'velocityPxPerSec': {'x': 0.0, 'y': swipePrimaryVelocity},
      'delta': {'dx': swipeDx, 'dy': swipeDy},
    },
    motion: motionAvailable
        ? {
            'peakMagnitude': motionPeakMagnitude,
            'peak': {
              'x': motionPeakX ?? 0,
              'y': motionPeakY ?? 0,
              'z': motionPeakZ ?? 0,
            },
          }
        : null,
  );
}

/// Shake-only slam — no swipe required; speed comes entirely from motion peak.
SlamInputPayload fuseMotionSlamInput({
  required double motionPeakMagnitude,
  required double motionPeakX,
  required double motionPeakY,
  required double motionPeakZ,
}) {
  final speed = (motionPeakMagnitude / motionMaxMps2).clamp(0.0, 1.0);
  var sdx = motionPeakX;
  var sdy = motionPeakY.abs();
  if (motionPeakZ.abs() > sdy) {
    sdy = motionPeakZ.abs();
    sdx = motionPeakX * 0.5;
  }
  final len = sqrt(sdx * sdx + sdy * sdy);
  if (len > 1e-6) {
    sdx /= len;
    sdy /= len;
  } else {
    sdx = 0;
    sdy = 1;
  }
  final angleDeg = atan2(sdy, sdx) * 180 / pi;

  return SlamInputPayload(
    speed: speed,
    trajectory: SlamTrajectory(dx: sdx, dy: sdy, angleDeg: angleDeg),
    source: 'shake',
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
