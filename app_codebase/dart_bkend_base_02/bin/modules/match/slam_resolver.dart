/// Weighted slam outcome from raw input + frozen slammer gameplayAttributes.
library;

import 'dart:math';

import '../../utils/dev_logger.dart';
import 'slam_physics_world.dart';
import 'table_pieces.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Default balanced attrs when freeze is missing a field.
const Map<String, int> defaultGameplayAttributes = {
  'impact': 5,
  'precision': 5,
  'control': 5,
  'recovery': 5,
  'spread': 5,
};

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
  final String result; // flip | miss
  final Map<String, dynamic>? sim;
}

int _attr(Map<String, dynamic>? attrs, String key) {
  if (attrs == null) return defaultGameplayAttributes[key]!;
  final v = attrs[key];
  if (v is int) return v.clamp(1, 10);
  if (v is num) return v.toInt().clamp(1, 10);
  return defaultGameplayAttributes[key]!;
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

/// Resolve slam via Forge2D side-view sim (collisions change trajectory/speed).
SlamResolveResult resolveSlam({
  required String matchId,
  required int version,
  required int actorSeatIndex,
  required Map<String, dynamic>? input,
  required Map<String, dynamic>? gameplayAttributes,
  required Map<String, dynamic> table,
}) {
  final pieces = piecesFromTable(table);
  if (pieces.isEmpty) {
    return SlamResolveResult(
      pieces: pieces,
      scoreDeltas: const {},
      flippedPieceIds: const [],
      impulse: _impulse(0, 0, 1, 0),
      result: 'miss',
      sim: {
        'dt': kSlamPhysicsDt,
        'sampleEvery': kSlamPhysicsSampleEvery,
        'pxPerMeter': kSlamPhysicsPxPerMeter,
        'frames': <Map<String, dynamic>>[],
      },
    );
  }

  final speed = input != null && input['speed'] is num
      ? (input['speed'] as num).toDouble().clamp(0.0, 1.0)
      : 0.0;
  final traj = input != null && input['trajectory'] is Map
      ? Map<String, dynamic>.from(input['trajectory'] as Map)
      : <String, dynamic>{'dx': 0.0, 'dy': 1.0};
  var dx = traj['dx'] is num ? (traj['dx'] as num).toDouble() : 0.0;
  var dy = traj['dy'] is num ? (traj['dy'] as num).toDouble() : 1.0;

  final impact = _attr(gameplayAttributes, 'impact');
  final precision = _attr(gameplayAttributes, 'precision');
  final control = _attr(gameplayAttributes, 'control');
  final spread = _attr(gameplayAttributes, 'spread');

  final rng = Random(seedFromMatch(matchId, version, actorSeatIndex));

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
  final impulse = _impulse(dx, dy, speed, power);

  if (power < 0.02) {
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
      sim: {
        'dt': kSlamPhysicsDt,
        'sampleEvery': kSlamPhysicsSampleEvery,
        'pxPerMeter': kSlamPhysicsPxPerMeter,
        'frames': <Map<String, dynamic>>[],
      },
    );
  }

  if (LOGGING_SWITCH) {
    customlog(
      'slamResolve: physics matchId=$matchId v=$version seat=$actorSeatIndex '
      'power=${power.toStringAsFixed(3)} maxAffect=$maxAffect',
    );
  }

  final physics = runSlamPhysics(
    pieces: pieces,
    dx: dx,
    dy: dy,
    speed: speed,
    power: power,
    maxAffect: maxAffect,
    rng: rng,
  );

  return SlamResolveResult(
    pieces: physics.pieces,
    scoreDeltas: physics.scoreDeltas,
    flippedPieceIds: physics.flippedPieceIds,
    impulse: impulse,
    result: physics.flippedPieceIds.isEmpty ? 'miss' : 'flip',
    sim: physics.sim,
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
