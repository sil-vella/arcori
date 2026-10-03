import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/match/widgets/slam_strike_motion.dart';

void main() {
  group('slamStrikeTravel', () {
    test('starts at zero', () {
      expect(slamStrikeTravel(0), 0);
    });

    test('at midpoint covers only the slow first-half fraction', () {
      final mid = slamStrikeTravel(0.5);
      expect(mid, closeTo(kSlamStrikeMidTravel, 1e-9));
      expect(mid, lessThan(0.5));
    });

    test('at end reaches full travel', () {
      expect(slamStrikeTravel(1), closeTo(1.0, 1e-9));
    });
  });

  group('slamStrikeScale', () {
    test('starts at one', () {
      expect(slamStrikeScale(0), closeTo(1.0, 1e-9));
    });

    test('peaks at midpoint', () {
      expect(slamStrikeScale(0.5), closeTo(kSlamStrikeScalePeak, 1e-9));
      expect(slamStrikeScale(0.25), lessThan(kSlamStrikeScalePeak));
      expect(slamStrikeScale(0.75), lessThan(kSlamStrikeScalePeak));
    });

    test('returns to one at the end', () {
      expect(slamStrikeScale(1), closeTo(1.0, 1e-9));
    });
  });
}
