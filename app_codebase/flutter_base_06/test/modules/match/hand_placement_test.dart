import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:arcori/modules/match/widgets/hand_under_slammer.dart';
import 'package:arcori/modules/play/avari_hand_catalog.dart';

void main() {
  test('play hand is two thirds of the doubled size', () {
    expect(kHandWidthOverDisc, closeTo(3.5 * 2 / 3, 0.001));
  });

  test('hand stands vertical and the palm stays on the seat right', () {
    const upright = 1.5707963267948966;
    expect(handWristRadians(SlammerDockSide.top), upright);
    expect(handWristRadians(SlammerDockSide.bottom), upright);
    expect(handWristRadians(SlammerDockSide.right), closeTo(math.pi, 0.001));
    expect(
      handWristRadians(SlammerDockSide.left),
      closeTo(upright + 3 * math.pi / 2, 0.001),
    );
    expect(handSeatRightRadians(SlammerDockSide.top), 0);
    expect(handSeatRightRadians(SlammerDockSide.bottom), 3.141592653589793);
    expect(handSeatRightRadians(SlammerDockSide.right), upright);
    expect(handSeatRightRadians(SlammerDockSide.left), -upright);
  });

  test('two of three AI ids get a stable shop hand', () {
    const hands = [
      'ARC-HND-CLG-SER008-GEN001-0001',
      'ARC-HND-CPR-SER008-GEN001-0002',
      'ARC-HND-LCY-SER008-GEN001-0003',
    ];
    var owned = 0;
    final seen = <String>{};
    for (var i = 1; i <= 300; i++) {
      final id = assignedAiHandId(_uuidFromInt(i));
      if (id == null) continue;
      owned += 1;
      expect(hands, contains(id));
      seen.add(id);
    }
    expect(owned, 200);
    expect(seen, hands.toSet());
    const practiceA = '798a2f60-ebef-5a4e-ae6c-f49037d1d00a';
    expect(assignedAiHandId(practiceA), assignedAiHandId(practiceA));
  });

  test('catalog hand ids resolve to their art', () {
    expect(avariHandFor(null), isNull);
    expect(avariHandFor(''), isNull);
    expect(avariHandFor('ARC-HND-NOPE-SER008-GEN001-0009'), isNull);
    final gold = avariHandFor('ARC-HND-CLG-SER008-GEN001-0001');
    expect(gold?.imageUrl, contains('HND-CLG-SER008-0001.webp'));
    expect(gold!.aspectWidthOverHeight, closeTo(1.5, 0.01));
    expect(
      avariHandFor('HND-CPR-SER008-0002')?.id,
      'ARC-HND-CPR-SER008-GEN001-0002',
    );
  });
}

String _uuidFromInt(int value) {
  final hex = value.toRadixString(16).padLeft(32, '0');
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
