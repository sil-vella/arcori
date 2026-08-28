/// Practice-local slam resolver (mirrors Dart slam_resolver.dart).
library;

import 'dart:math';

const Map<String, int> defaultGameplayAttributes = {
  'impact': 5,
  'precision': 5,
  'control': 5,
  'recovery': 5,
  'spread': 5,
};

/// Starter-balanced attrs used for practice until client hydrates freeze.
const Map<String, Map<String, dynamic>> practiceSlammerAttrs = {
  'SLM-STR-GEN001-0001': {
    'impact': 5,
    'precision': 5,
    'control': 5,
    'recovery': 5,
    'spread': 5,
  },
};

const stubPracticeAiArcoriId = 'ANM-WTI-GEN001-0002';

class SlamResolveResult {
  const SlamResolveResult({
    required this.pieces,
    required this.scoreDeltas,
    required this.flippedPieceIds,
    required this.impulse,
    required this.result,
  });

  final List<Map<String, dynamic>> pieces;
  final Map<String, int> scoreDeltas;
  final List<String> flippedPieceIds;
  final Map<String, dynamic> impulse;
  final String result;
}

Map<String, dynamic> tableFromSeatViews({
  required List<
          ({
            String userId,
            int seatIndex,
            List<String> arcoriIds,
          })>
      seats,
}) {
  final pieces = <Map<String, dynamic>>[];
  var stackIndex = 0;
  for (final seat in seats) {
    final designId =
        seat.arcoriIds.isNotEmpty ? seat.arcoriIds.first.trim() : '';
    if (designId.isEmpty) continue;
    pieces.add({
      'pieceId': 'p${seat.seatIndex}',
      'designId': designId,
      'ownerUserId': seat.userId,
      'seatIndex': seat.seatIndex,
      'faceUp': false,
      'stackIndex': stackIndex,
    });
    stackIndex++;
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
    final sa = a['seatIndex'] is int ? a['seatIndex'] as int : 0;
    final sb = b['seatIndex'] is int ? b['seatIndex'] as int : 0;
    return sa.compareTo(sb);
  });
  for (var i = 0; i < pieces.length; i++) {
    pieces[i] = {...pieces[i], 'faceUp': false, 'stackIndex': i};
  }
  return {'pieces': pieces};
}

int _attr(Map<String, dynamic>? attrs, String key) {
  if (attrs == null) return defaultGameplayAttributes[key]!;
  final v = attrs[key];
  if (v is int) return v.clamp(1, 10);
  if (v is num) return v.toInt().clamp(1, 10);
  return defaultGameplayAttributes[key]!;
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

  pieces.sort((a, b) {
    final sa = a['stackIndex'] is int ? a['stackIndex'] as int : 0;
    final sb = b['stackIndex'] is int ? b['stackIndex'] as int : 0;
    return sa.compareTo(sb);
  });

  final flipped = <String>[];
  final scoreDeltas = <String, int>{};
  var remainingPower = power;

  // Soft miss floor — timeout still misses; light swipes can flip.
  if (power < 0.02) {
    return SlamResolveResult(
      pieces: pieces,
      scoreDeltas: scoreDeltas,
      flippedPieceIds: flipped,
      impulse: _impulse(dx, dy, speed, power),
      result: 'miss',
    );
  }

  var affected = 0;
  var faceDownDepth = 0;
  for (var i = pieces.length - 1; i >= 0 && affected < maxAffect; i--) {
    if (pieces[i]['faceUp'] == true) {
      continue;
    }

    final threshold = 0.03 + faceDownDepth * 0.025;
    faceDownDepth++;
    final roll = rng.nextDouble() * 0.25;
    if (remainingPower + roll >= threshold) {
      final id = pieces[i]['pieceId']?.toString() ?? 'p$i';
      pieces[i] = {...pieces[i], 'faceUp': true};
      flipped.add(id);
      final owner = pieces[i]['ownerUserId']?.toString() ?? '';
      if (owner.isNotEmpty) {
        scoreDeltas[owner] = (scoreDeltas[owner] ?? 0) + 1;
      }
      remainingPower *= 0.75;
      affected++;
    } else {
      break;
    }
  }

  return SlamResolveResult(
    pieces: pieces,
    scoreDeltas: scoreDeltas,
    flippedPieceIds: flipped,
    impulse: _impulse(dx, dy, speed, power),
    result: flipped.isEmpty ? 'miss' : 'flip',
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
