/// Practice-local slam resolver (mirrors Dart slam_resolver.dart + physics).
library;

import 'dart:math';

import '../../../utils/dev_logger.dart';
import 'slam_input_models.dart';
import 'slam_physics_world.dart';
import 'turn_pacing.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const Map<String, dynamic> defaultGameplayAttributes = {
  'impact': 5,
  'precision': 5,
  'control': 5,
  'recovery': 5,
  'spread': 5,
  'hitTarget': 'center',
  'powerBracket': {'min': 0.4, 'max': 0.6},
};

const double kHitPrefTol = 0.45;
/// Falloff distance outside the preferred power band (keeps ~90% vs 0.4–0.6 medium-low).
const double kPowerPrefTol = 0.45;

/// Starter-balanced attrs used for practice until client hydrates freeze.
const Map<String, Map<String, dynamic>> practiceSlammerAttrs = {
  'SLM-STR-SER001-0001': {
    'impact': 5,
    'precision': 3,
    'control': 3,
    'recovery': 5,
    'spread': 5,
    'hitTarget': 'center',
    'powerBracket': {'min': 0.55, 'max': 0.85},
  },
};

/// Practice disc art — human seat 0 = 001; AI seats 1/2 = 002/003.
const String practiceHumanArcoriId = 'PRA-ARC-SER001-0001';

/// Practice AI seatIndex 1 / 2 design ids (bundle art — not catalog).
const List<String> practiceAiArcoriIds = [
  'PRA-ARC-SER001-0002',
  'PRA-ARC-SER001-0003',
];

const Map<String, Map<String, String>> practiceFaceDefaults = {
  practiceHumanArcoriId: {
    'imageUrl': 'assets/images/arcori/practice_arcori_001.webp',
    'color': '#6B5B95',
  },
  'PRA-ARC-SER001-0002': {
    'imageUrl': 'assets/images/arcori/practice_arcori_002.webp',
    'color': '#C6A15B',
  },
  'PRA-ARC-SER001-0003': {
    'imageUrl': 'assets/images/arcori/practice_arcori_003.webp',
    'color': '#4A7C59',
  },
};

/// Practice / stub slammer face art (strike overlay).
const Map<String, Map<String, String>> practiceSlammerFaceDefaults = {
  'SLM-STR-SER001-0001': {
    'imageUrl': 'assets/images/arcori/practice_arcori_002.webp',
    'color': '#C6A15B',
  },
};

Map<String, String?> practiceSlammerFaceFor(String? slammerId) {
  final id = (slammerId ?? '').trim();
  final face = practiceSlammerFaceDefaults[id] ??
      practiceSlammerFaceDefaults['SLM-STR-SER001-0001'];
  if (face == null) {
    return const {'imageUrl': null, 'lottieUrl': null, 'color': '#C6A15B'};
  }
  return {
    'imageUrl': face['imageUrl'],
    'lottieUrl': face['lottieUrl'],
    'color': face['color'],
  };
}

class SlamResolveResult {
  const SlamResolveResult({
    required this.pieces,
    required this.scoreDeltas,
    required this.flippedPieceIds,
    required this.impulse,
    required this.result,
    this.sim,
  });

  final List<Map<String, dynamic>> pieces;
  final Map<String, int> scoreDeltas;
  final List<String> flippedPieceIds;
  final Map<String, dynamic> impulse;
  final String result;
  final Map<String, dynamic>? sim;
}

Map<String, dynamic> tableFromSeatViews({
  required List<
          ({
            String userId,
            int seatIndex,
            List<String> arcoriIds,
          })>
      seats,
  Map<String, Map<String, String?>>? facesByDesignId,
  String? gathererArcoriId,
}) {
  final pieces = <Map<String, dynamic>>[];
  var stackIndex = 0;
  for (final seat in seats) {
    final designId =
        seat.arcoriIds.isNotEmpty ? seat.arcoriIds.first.trim() : '';
    if (designId.isEmpty) continue;
    final face = facesByDesignId?[designId];
    final imageUrl = face?['imageUrl']?.trim() ?? '';
    final lottieUrl = face?['lottieUrl']?.trim() ?? '';
    final color = face?['color']?.trim() ?? '';
    pieces.add({
      'pieceId': 'p${seat.seatIndex}',
      'designId': designId,
      'ownerUserId': seat.userId,
      'seatIndex': seat.seatIndex,
      'faceUp': false,
      'stackIndex': stackIndex,
      if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (lottieUrl.isNotEmpty) 'lottieUrl': lottieUrl,
      if (color.isNotEmpty) 'color': color,
    });
    stackIndex++;
  }

  final gathererId = gathererArcoriId?.trim() ?? '';
  if (gathererId.isNotEmpty) {
    final face = facesByDesignId?[gathererId];
    final imageUrl = face?['imageUrl']?.trim() ?? '';
    final lottieUrl = face?['lottieUrl']?.trim() ?? '';
    final color = face?['color']?.trim() ?? '';
    pieces.add({
      'pieceId': 'p_gatherer',
      'designId': gathererId,
      'ownerUserId': '',
      'faceUp': false,
      'stackIndex': stackIndex,
      if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (lottieUrl.isNotEmpty) 'lottieUrl': lottieUrl,
      if (color.isNotEmpty) 'color': color,
    });
  }

  return {'pieces': pieces};
}

Map<String, dynamic> restackFaceDown(Map<String, dynamic> table) {
  final raw = table['pieces'];
  final pieces = raw is List
      ? raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];
  pieces.sort((a, b) {
    final sa = a['seatIndex'] is int ? a['seatIndex'] as int : null;
    final sb = b['seatIndex'] is int ? b['seatIndex'] as int : null;
    if (sa == null && sb == null) return 0;
    if (sa == null) return 1;
    if (sb == null) return -1;
    return sa.compareTo(sb);
  });
  for (var i = 0; i < pieces.length; i++) {
    pieces[i] = {...pieces[i], 'faceUp': false, 'stackIndex': i};
  }
  return {'pieces': pieces};
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

double aimRadiusNorm(double aimX, double aimZ) {
  final r = sqrt(aimX * aimX + aimZ * aimZ) / kSlamAimHitRadius;
  return r.clamp(0.0, 1.0);
}

double powerBandDistance(double power, double minP, double maxP) {
  if (power < minP) return minP - power;
  if (power > maxP) return power - maxP;
  return 0.0;
}

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

int _seedFrom(String matchId, int version, int seatIndex) {
  var h = 0;
  for (final c in matchId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  h = (h * 31 + version) & 0x7fffffff;
  h = (h * 31 + seatIndex) & 0x7fffffff;
  return h == 0 ? 1 : h;
}

SlamResolveResult resolveSlam({
  required String matchId,
  required int version,
  required int actorSeatIndex,
  required Map<String, dynamic>? input,
  required Map<String, dynamic>? gameplayAttributes,
  required Map<String, dynamic> table,
  String? actorUserId,
}) {
  final raw = table['pieces'];
  final pieces = raw is List
      ? raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];

  if (pieces.isEmpty) {
    return SlamResolveResult(
      pieces: pieces,
      scoreDeltas: const {},
      flippedPieceIds: const [],
      impulse: _impulse(0, 0, 1, 0),
      result: 'miss',
      sim: withSlamAnimTiming({
        'dt': kSlamPhysicsDt,
        'sampleEvery': kSlamPhysicsSampleEvery,
        'pxPerMeter': kSlamPhysicsPxPerMeter,
        'space': kSlamPhysicsSpace,
        'steps': 0,
        'frames': <Map<String, dynamic>>[],
      }),
    );
  }

  final speed = input != null && input['speed'] is num
      ? (input['speed'] as num).toDouble().clamp(0.0, 1.0)
      : 0.0;
  var aimX = 0.0;
  var aimZ = 0.0;
  final aimRaw = input != null ? input['aim'] : null;
  if (aimRaw is Map) {
    if (aimRaw['x'] is num) aimX = (aimRaw['x'] as num).toDouble();
    if (aimRaw['z'] is num) aimZ = (aimRaw['z'] as num).toDouble();
  }
  final kick = kickDirectionFromAim(aimX, aimZ);
  var dx = kick.dx;
  var dy = kick.dy;

  final impact = _attr(gameplayAttributes, 'impact');
  final precision = _attr(gameplayAttributes, 'precision');
  final control = _attr(gameplayAttributes, 'control');
  final spread = _attr(gameplayAttributes, 'spread');
  final hitTarget = _hitTarget(gameplayAttributes);
  final powerBracket = _powerBracket(gameplayAttributes);

  final rng = Random(_seedFrom(matchId, version, actorSeatIndex));
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

  Map<String, dynamic> emptySim() => withSlamAnimTiming({
        'dt': kSlamPhysicsDt,
        'sampleEvery': kSlamPhysicsSampleEvery,
        'pxPerMeter': kSlamPhysicsPxPerMeter,
        'space': kSlamPhysicsSpace,
        'steps': 0,
        'frames': <Map<String, dynamic>>[],
      });

  if (aimOutsideStackFootprint(aimX, aimZ)) {
    final impulse = _impulse(dx, dy, speed, power);
    if (LOGGING_SWITCH) {
      customlog(
        'slamResolve: aimMiss x=${aimX.toStringAsFixed(4)} '
        'z=${aimZ.toStringAsFixed(4)} matchId=$matchId',
      );
    }
    return SlamResolveResult(
      pieces: pieces,
      scoreDeltas: const {},
      flippedPieceIds: const [],
      impulse: impulse,
      result: 'miss',
      sim: emptySim(),
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
      sim: emptySim(),
    );
  }

  final fit = preferenceFit(
    aimX: aimX,
    aimZ: aimZ,
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
      'aim=(${aimX.toStringAsFixed(4)},${aimZ.toStringAsFixed(4)})',
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

  return SlamResolveResult(
    pieces: physics.pieces,
    scoreDeltas: physics.scoreDeltas,
    flippedPieceIds: physics.flippedPieceIds,
    impulse: impulse,
    result: physics.flippedPieceIds.isEmpty ? 'miss' : 'flip',
    sim: sim,
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
