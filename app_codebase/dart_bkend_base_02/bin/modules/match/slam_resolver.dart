/// Weighted slam outcome from raw input + frozen slammer gameplayAttributes.
library;

import 'dart:math';

import '../../utils/dev_logger.dart';
import 'slam_input.dart';
import 'slam_physics_world.dart';
import 'table_pieces.dart';
import 'turn_pacing.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Default balanced attrs when freeze is missing a field.
const Map<String, dynamic> defaultGameplayAttributes = {
  'impact': 5,
  'precision': 5,
  'control': 5,
  'recovery': 5,
  'spread': 5,
  'hitTarget': 'center',
  'powerBracket': {'min': 0.4, 'max': 0.6},
};

/// Copy catalog feel stats and overlay this player's saved sweet spot.
///
/// Does not mutate [catalogAttrs]. Missing spot leaves the catalog prefs.
Map<String, dynamic>? applyPlayerSweetSpot(
  Map<String, dynamic>? catalogAttrs,
  Map<String, dynamic>? sweetSpot,
) {
  if (catalogAttrs == null && sweetSpot == null) return null;
  final attrs = catalogAttrs == null
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(catalogAttrs);
  if (sweetSpot == null) return attrs;
  final hit = sweetSpot['hitTarget']?.toString().trim().toLowerCase() ?? '';
  if (hit == 'center' || hit == 'mid' || hit == 'edge') {
    attrs['hitTarget'] = hit;
  }
  final band = sweetSpot['powerBracket'];
  if (band is Map) {
    attrs['powerBracket'] = Map<String, dynamic>.from(band);
  }
  return attrs;
}

const double kHitPrefTol = 0.45;
/// Falloff distance outside the preferred power band (keeps ~90% vs 0.4–0.6 medium-low).
const double kPowerPrefTol = 0.45;

/// Per-flip mastery at fit=0 (still awards something when flips land).
/// Mirrors [effectivePowerFromFit]'s 0.55 floor so a cold hit is not zero mastery.
const double kMasteryFitFloor = 0.55;

/// Extra per-flip mastery from fit 0→1 (floor + span = 1.0 at perfect fit).
const double kMasteryFitSpan = 0.45;

/// Slammer mastery uses the same fit curve, counted ten times.
const double kSlammerMasteryScale = 10;

class SlamResolveResult {
  const SlamResolveResult({
    required this.pieces,
    required this.scoreDeltas,
    required this.flippedPieceIds,
    required this.impulse,
    required this.result,
    this.sim,
    this.preferenceFit = 0.0,
    this.slammerMasteryAdded = 0.0,
  });

  final List<Map<String, dynamic>> pieces;
  final Map<String, int> scoreDeltas;
  final List<String> flippedPieceIds;
  final Map<String, dynamic> impulse;
  final String result; // flip | miss
  final Map<String, dynamic>? sim;
  /// Server-internal fit 0..1 (not stamped on the client wire).
  final double preferenceFit;
  /// Player-facing mastery gain: 10 × flips × (0.55 + 0.45 × fit). Miss / 0 flips → 0.
  final double slammerMasteryAdded;
}

int _attr(Map<String, dynamic>? attrs, String key) {
  final fallback = defaultGameplayAttributes[key];
  final def = fallback is int ? fallback : 5;
  if (attrs == null) return def;
  final v = attrs[key];
  if (v is int) return v.clamp(1, 10);
  if (v is num) return v.toInt().clamp(1, 10);
  return def;
}

String _hitTarget(Map<String, dynamic>? attrs) {
  final raw = attrs?['hitTarget'] ?? defaultGameplayAttributes['hitTarget'];
  if (raw is String) {
    final hit = raw.trim().toLowerCase();
    if (hit == 'center' || hit == 'mid' || hit == 'edge') return hit;
  }
  return 'center';
}

double? _as01(Object? value) {
  if (value is num) return value.toDouble().clamp(0.0, 1.0);
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed.clamp(0.0, 1.0);
  }
  return null;
}

/// Preferred resolve-power band (0 = none, 1 = full).
({double min, double max}) _powerBracket(Map<String, dynamic>? attrs) {
  final raw =
      attrs?['powerBracket'] ?? defaultGameplayAttributes['powerBracket'];
  double? lo;
  double? hi;
  if (raw is Map) {
    lo = _as01(raw['min']);
    hi = _as01(raw['max']);
  } else if (raw is List && raw.length >= 2) {
    lo = _as01(raw[0]);
    hi = _as01(raw[1]);
  } else {
    final center = _as01(raw);
    if (center != null) {
      lo = (center - 0.1).clamp(0.0, 1.0);
      hi = (center + 0.1).clamp(0.0, 1.0);
    }
  }
  if (lo == null || hi == null) return (min: 0.4, max: 0.6);
  if (hi < lo) {
    final swap = lo;
    lo = hi;
    hi = swap;
  }
  return (min: lo, max: hi);
}

double _preferredRadius(String hitTarget) {
  switch (hitTarget) {
    case 'edge':
      return 1.0;
    case 'mid':
      return 0.5;
    case 'center':
    default:
      return 0.0;
  }
}

/// Normalized aim radius on the stack footprint (0 = center, 1 = rim).
double aimRadiusNorm(double aimX, double aimZ) {
  final r = sqrt(aimX * aimX + aimZ * aimZ) / kSlamAimHitRadius;
  return r.clamp(0.0, 1.0);
}

/// Distance of [power] outside [min,max] (0 when inside the band).
double powerBandDistance(double power, double minP, double maxP) {
  if (power < minP) return minP - power;
  if (power > maxP) return power - maxP;
  return 0.0;
}

/// How well aim + power match the slammer's preferred slam conditions (0..1).
double preferenceFit({
  required double aimX,
  required double aimZ,
  required double power,
  required String hitTarget,
  required double powerMin,
  required double powerMax,
}) {
  final r = aimRadiusNorm(aimX, aimZ);
  final preferredR = _preferredRadius(hitTarget);
  final hitMatch = (1.0 - min(1.0, (r - preferredR).abs() / kHitPrefTol))
      .clamp(0.0, 1.0);
  final dist = powerBandDistance(power, powerMin, powerMax);
  final powerMatch =
      (1.0 - min(1.0, dist / kPowerPrefTol)).clamp(0.0, 1.0);
  return sqrt(hitMatch * powerMatch).clamp(0.0, 1.0);
}

double effectivePowerFromFit(double power, double fit) {
  return (power * (0.55 + 0.70 * fit)).clamp(0.0, 1.0);
}

/// Mastery weight per flipped piece before the slammer scale (0.55 at fit=0 → 1.0 at fit=1).
double masteryWeightFromFit(double fit) {
  final f = fit.clamp(0.0, 1.0);
  return (kMasteryFitFloor + kMasteryFitSpan * f).clamp(0.0, 1.0);
}

/// Slammer mastery for this slam. Same fit curve, ten times the gain.
double slammerMasteryFromFlips(int flips, double fit) {
  if (flips <= 0) return 0;
  return flips * masteryWeightFromFit(fit) * kSlammerMasteryScale;
}

int seedFromMatch(String matchId, int version, int seatIndex) {
  var h = 0;
  for (final c in matchId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  h = (h * 31 + version) & 0x7fffffff;
  h = (h * 31 + seatIndex) & 0x7fffffff;
  return h == 0 ? 1 : h;
}

Map<String, dynamic> _emptySim() => withSlamAnimTiming({
      'dt': kSlamPhysicsDt,
      'sampleEvery': kSlamPhysicsSampleEvery,
      'pxPerMeter': kSlamPhysicsPxPerMeter,
      'space': kSlamPhysicsSpace,
      'steps': 0,
      'frames': <Map<String, dynamic>>[],
    });

({double x, double z}) _readAim(Map<String, dynamic>? input) {
  if (input == null) return (x: 0.0, z: 0.0);
  final aim = input['aim'];
  if (aim is! Map) return (x: 0.0, z: 0.0);
  final x = aim['x'] is num ? (aim['x'] as num).toDouble() : 0.0;
  final z = aim['z'] is num ? (aim['z'] as num).toDouble() : 0.0;
  return (x: x, z: z);
}

/// Resolve slam via 3D thin-cylinder sim (collisions change trajectory/speed).
SlamResolveResult resolveSlam({
  required String matchId,
  required int version,
  required int actorSeatIndex,
  required Map<String, dynamic>? input,
  required Map<String, dynamic>? gameplayAttributes,
  required Map<String, dynamic> table,
  String? actorUserId,
}) {
  final pieces = piecesFromTable(table);
  if (pieces.isEmpty) {
    return SlamResolveResult(
      pieces: pieces,
      scoreDeltas: const {},
      flippedPieceIds: const [],
      impulse: _impulse(0, 0, 1, 0),
      result: 'miss',
      sim: _emptySim(),
    );
  }

  final speed = input != null && input['speed'] is num
      ? (input['speed'] as num).toDouble().clamp(0.0, 1.0)
      : 0.0;
  final aim = _readAim(input);

  final impact = _attr(gameplayAttributes, 'impact');
  final precision = _attr(gameplayAttributes, 'precision');
  final control = _attr(gameplayAttributes, 'control');
  final spread = _attr(gameplayAttributes, 'spread');
  final hitTarget = _hitTarget(gameplayAttributes);
  final powerBracket = _powerBracket(gameplayAttributes);

  final rng = Random(seedFromMatch(matchId, version, actorSeatIndex));

  final kick = kickDirectionFromAim(aim.x, aim.z);
  var dx = kick.dx;
  var dy = kick.dy;

  // Precision reduces angular jitter; control damps random aim noise.
  final jitterScale = (11 - precision) / 10.0 * (1.0 - control / 20.0);
  final jitter = (rng.nextDouble() - 0.5) * jitterScale * 0.6;
  final cosJ = cos(jitter);
  final sinJ = sin(jitter);
  final rdx = dx * cosJ - dy * sinJ;
  final rdy = dx * sinJ + dy * cosJ;
  dx = rdx;
  dy = rdy;

  final power = (speed * (impact / 10.0)).clamp(0.0, 1.0);
  final maxAffect = max(1, ((spread / 10.0) * pieces.length).ceil());

  if (aimOutsideStackFootprint(aim.x, aim.z)) {
    final impulse = _impulse(dx, dy, speed, power);
    if (LOGGING_SWITCH) {
      customlog(
        'slamResolve: aimMiss x=${aim.x.toStringAsFixed(4)} '
        'z=${aim.z.toStringAsFixed(4)} matchId=$matchId',
      );
    }
    return SlamResolveResult(
      pieces: pieces,
      scoreDeltas: const {},
      flippedPieceIds: const [],
      impulse: impulse,
      result: 'miss',
      sim: _emptySim(),
    );
  }

  if (power < kSlamMinPower) {
    final impulse = _impulse(dx, dy, speed, power);
    if (LOGGING_SWITCH) {
      customlog(
        'slamResolve: softMiss power=${power.toStringAsFixed(3)} '
        'matchId=$matchId',
      );
    }
    return SlamResolveResult(
      pieces: pieces,
      scoreDeltas: const {},
      flippedPieceIds: const [],
      impulse: impulse,
      result: 'miss',
      sim: _emptySim(),
    );
  }

  final fit = preferenceFit(
    aimX: aim.x,
    aimZ: aim.z,
    power: power,
    hitTarget: hitTarget,
    powerMin: powerBracket.min,
    powerMax: powerBracket.max,
  );
  final effectivePower = effectivePowerFromFit(power, fit);
  final impulse = _impulse(dx, dy, speed, effectivePower);

  if (LOGGING_SWITCH) {
    customlog(
      'slamResolve: physics matchId=$matchId v=$version seat=$actorSeatIndex '
      'power=${power.toStringAsFixed(3)} '
      'effPower=${effectivePower.toStringAsFixed(3)} '
      'prefFit=${fit.toStringAsFixed(3)} hit=$hitTarget '
      'bracket=${powerBracket.min.toStringAsFixed(2)}-${powerBracket.max.toStringAsFixed(2)} '
      'maxAffect=$maxAffect '
      'aim=(${aim.x.toStringAsFixed(4)},${aim.z.toStringAsFixed(4)})',
    );
  }

  final physics = runSlamPhysics(
    pieces: pieces,
    dx: dx,
    dy: dy,
    speed: speed,
    power: effectivePower,
    maxAffect: maxAffect,
    rng: rng,
    spreadAttr: spread,
    scoringUserId: actorUserId,
  );

  final sim = withSlamAnimTiming(
    Map<String, dynamic>.from(physics.sim),
  );

  final flips = physics.flippedPieceIds.length;
  final masteryWeight = masteryWeightFromFit(fit);
  final masteryAdded = slammerMasteryFromFlips(flips, fit);
  if (LOGGING_SWITCH) {
    customlog(
      'slamResolve: slammerMastery matchId=$matchId seat=$actorSeatIndex '
      'flips=$flips prefFit=${fit.toStringAsFixed(3)} '
      'masteryWeight=${masteryWeight.toStringAsFixed(3)} '
      'slammerMasteryAdded=${masteryAdded.toStringAsFixed(3)}',
    );
  }
  return SlamResolveResult(
    pieces: physics.pieces,
    scoreDeltas: physics.scoreDeltas,
    flippedPieceIds: physics.flippedPieceIds,
    impulse: impulse,
    result: flips == 0 ? 'miss' : 'flip',
    sim: sim,
    preferenceFit: fit,
    slammerMasteryAdded: masteryAdded,
  );
}

Map<String, dynamic> _impulse(
  double dx,
  double dy,
  double speed,
  double power,
) {
  final len = sqrt(dx * dx + dy * dy);
  final ndx = len > 1e-6 ? dx / len : 0.0;
  final ndy = len > 1e-6 ? dy / len : 1.0;
  return {
    'vx': ndx * power,
    'vy': ndy * power,
    'spin': speed * power * 2.0,
    'power': power,
  };
}
