import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/match/widgets/slam_hit_feedback.dart';

void main() {
  group('slamHitShakeOffset', () {
    test('zero at start and end', () {
      expect(slamHitShakeOffset(0), Offset.zero);
      expect(slamHitShakeOffset(1), Offset.zero);
    });

    test('mid shake stays within peak amplitude', () {
      final mid = slamHitShakeOffset(0.15, seed: 7);
      expect(mid.distance, greaterThan(0));
      expect(mid.distance, lessThanOrEqualTo(kSlamHitShakePeakPx + 1e-9));
    });
  });
}
