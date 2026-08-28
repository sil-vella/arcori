/// Face-down Arcori stack pieces on the match table.
library;

import 'match_models.dart';

Map<String, dynamic> emptyTable() => {'pieces': <dynamic>[]};

/// Build one face-down piece per seat that has an Arcori design id.
Map<String, dynamic> tableFromSeats(List<MatchSeat> seats) {
  final pieces = <Map<String, dynamic>>[];
  var stackIndex = 0;
  for (final seat in seats) {
    final designId =
        seat.arcoriIds.isNotEmpty ? seat.arcoriIds.first.trim() : '';
    if (designId.isEmpty) continue;
    pieces.add(
      piecePayload(
        pieceId: 'p${seat.seatIndex}',
        designId: designId,
        ownerUserId: seat.userId,
        seatIndex: seat.seatIndex,
        faceUp: false,
        stackIndex: stackIndex,
      ),
    );
    stackIndex++;
  }
  return {'pieces': pieces};
}

Map<String, dynamic> piecePayload({
  required String pieceId,
  required String designId,
  required String ownerUserId,
  required int seatIndex,
  required bool faceUp,
  required int stackIndex,
}) {
  return {
    'pieceId': pieceId,
    'designId': designId,
    'ownerUserId': ownerUserId,
    'seatIndex': seatIndex,
    'faceUp': faceUp,
    'stackIndex': stackIndex,
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

/// Reset all pieces face-down and re-index stack order by seatIndex.
Map<String, dynamic> restackFaceDown(Map<String, dynamic> table) {
  final pieces = piecesFromTable(table);
  pieces.sort((a, b) {
    final sa = a['seatIndex'] is int ? a['seatIndex'] as int : 0;
    final sb = b['seatIndex'] is int ? b['seatIndex'] as int : 0;
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
