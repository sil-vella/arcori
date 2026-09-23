/// Face-down Arcori stack pieces on the match table.
library;

import 'match_models.dart';

/// Stable piece id for the non-seat Gatherer disc (Quick Start / Invite).
const String kGathererPieceId = 'p_gatherer';

Map<String, dynamic> emptyTable() => {'pieces': <dynamic>[]};

/// Stamp equipped-slammer face fields from catalog freeze onto seats.
List<MatchSeat> stampSlammerFaces(
  List<MatchSeat> seats,
  Map<String, Map<String, dynamic>> catalogById,
) {
  return [
    for (final seat in seats) _seatWithSlammerFace(seat, catalogById),
  ];
}

MatchSeat _seatWithSlammerFace(
  MatchSeat seat,
  Map<String, Map<String, dynamic>> catalogById,
) {
  final id = seat.slammerId.trim();
  if (id.isEmpty) return seat;
  final frozen = catalogById[id];
  if (frozen == null) return seat;
  final imageUrl = frozen['imageUrl']?.toString().trim() ?? '';
  final lottieUrl = frozen['lottieUrl']?.toString().trim() ?? '';
  final color = frozen['color']?.toString().trim() ?? '';
  return MatchSeat(
    userId: seat.userId,
    seatIndex: seat.seatIndex,
    kind: seat.kind,
    arcoriIds: seat.arcoriIds,
    slammerId: seat.slammerId,
    score: seat.score,
    connected: seat.connected,
    username: seat.username,
    avatarUrl: seat.avatarUrl,
    imageUrl: imageUrl.isNotEmpty ? imageUrl : seat.imageUrl,
    lottieUrl: lottieUrl.isNotEmpty ? lottieUrl : seat.lottieUrl,
    color: color.isNotEmpty ? color : seat.color,
  );
}

/// Build face-down pieces: one per seat with an Arcori id, plus optional Gatherer.
///
/// Gatherer has [kGathererPieceId], empty [ownerUserId], and **no** `seatIndex`
/// (not tied to any [MatchSeat]). Restack keeps seat discs ordered by seat,
/// then Gatherer on top.
Map<String, dynamic> tableFromSeats(
  List<MatchSeat> seats, {
  Map<String, Map<String, dynamic>>? catalogById,
  String? gathererArcoriId,
}) {
  final pieces = <Map<String, dynamic>>[];
  var stackIndex = 0;
  for (final seat in seats) {
    final designId =
        seat.arcoriIds.isNotEmpty ? seat.arcoriIds.first.trim() : '';
    if (designId.isEmpty) continue;
    final frozen = catalogById?[designId];
    final imageUrl = frozen?['imageUrl']?.toString().trim() ?? '';
    final lottieUrl = frozen?['lottieUrl']?.toString().trim() ?? '';
    final color = frozen?['color']?.toString().trim() ?? '';
    pieces.add(
      piecePayload(
        pieceId: 'p${seat.seatIndex}',
        designId: designId,
        ownerUserId: seat.userId,
        seatIndex: seat.seatIndex,
        faceUp: false,
        stackIndex: stackIndex,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
        lottieUrl: lottieUrl.isNotEmpty ? lottieUrl : null,
        color: color.isNotEmpty ? color : null,
      ),
    );
    stackIndex++;
  }

  final gathererId = gathererArcoriId?.trim() ?? '';
  if (gathererId.isNotEmpty) {
    final frozen = catalogById?[gathererId];
    final imageUrl = frozen?['imageUrl']?.toString().trim() ?? '';
    final lottieUrl = frozen?['lottieUrl']?.toString().trim() ?? '';
    final color = frozen?['color']?.toString().trim() ?? '';
    pieces.add(
      piecePayload(
        pieceId: kGathererPieceId,
        designId: gathererId,
        ownerUserId: '',
        seatIndex: null,
        faceUp: false,
        stackIndex: stackIndex,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
        lottieUrl: lottieUrl.isNotEmpty ? lottieUrl : null,
        color: color.isNotEmpty ? color : null,
      ),
    );
  }

  return {'pieces': pieces};
}

Map<String, dynamic> piecePayload({
  required String pieceId,
  required String designId,
  required String ownerUserId,
  required int? seatIndex,
  required bool faceUp,
  required int stackIndex,
  String? imageUrl,
  String? lottieUrl,
  String? color,
}) {
  return {
    'pieceId': pieceId,
    'designId': designId,
    'ownerUserId': ownerUserId,
    if (seatIndex != null) 'seatIndex': seatIndex,
    'faceUp': faceUp,
    'stackIndex': stackIndex,
    if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    if (lottieUrl != null && lottieUrl.isNotEmpty) 'lottieUrl': lottieUrl,
    if (color != null && color.isNotEmpty) 'color': color,
  };
}

List<Map<String, dynamic>> piecesFromTable(Map<String, dynamic> table) {
  final raw = table['pieces'];
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

int? pieceSeatIndex(Map<String, dynamic> piece) {
  final raw = piece['seatIndex'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return null;
}

bool isGathererPiece(Map<String, dynamic> piece) {
  final id = piece['pieceId']?.toString().trim() ?? '';
  if (id == kGathererPieceId) return true;
  return pieceSeatIndex(piece) == null && id.isNotEmpty;
}

/// Reset all pieces face-down and re-index stack: seats by seatIndex, then seatless.
Map<String, dynamic> restackFaceDown(Map<String, dynamic> table) {
  final pieces = piecesFromTable(table);
  pieces.sort((a, b) {
    final sa = pieceSeatIndex(a);
    final sb = pieceSeatIndex(b);
    if (sa == null && sb == null) return 0;
    if (sa == null) return 1;
    if (sb == null) return -1;
    return sa.compareTo(sb);
  });
  for (var i = 0; i < pieces.length; i++) {
    pieces[i] = {
      ...pieces[i],
      'faceUp': false,
      'stackIndex': i,
    };
  }
  return {'pieces': pieces};
}
