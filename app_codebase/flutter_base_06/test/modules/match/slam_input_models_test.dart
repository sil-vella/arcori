import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/match/input/slam_input_models.dart';

void main() {
  group('fuseSlamInput', () {
    test('down swipe yields high dy trajectory', () {
      final payload = fuseSlamInput(
        swipePrimaryVelocity: 1000,
        swipeDx: 5,
        swipeDy: 120,
        motionPeakMagnitude: 0,
        motionAvailable: false,
      );
      expect(payload.speed, greaterThan(0.2));
      expect(payload.trajectory.dy, greaterThan(0.9));
      expect(payload.source, 'gesture');
    });

    test('slow drag without velocity uses distance speed', () {
      final payload = fuseSlamInput(
        swipePrimaryVelocity: 0,
        swipeDx: 2,
        swipeDy: 80,
        motionPeakMagnitude: 0,
        motionAvailable: false,
      );
      // 80 / swipeMaxDragDy(280) ≈ 0.29 with old caps; with soft caps ≈ 0.17.
      expect(payload.speed, greaterThan(0.12));
      expect(payload.speed, lessThan(0.35));
    });

    test('timeout payload is zero speed down', () {
      final payload = timeoutSlamInput();
      expect(payload.speed, 0);
      expect(payload.trajectory.dy, 1);
      expect(payload.source, 'timeout');
    });

    test('shake-only yields speed from motion peak', () {
      final payload = fuseMotionSlamInput(
        motionPeakMagnitude: 12,
        motionPeakX: 0.2,
        motionPeakY: -8,
        motionPeakZ: 4,
      );
      expect(payload.source, 'shake');
      // 12 / motionMaxMps2(28) ≈ 0.43
      expect(payload.speed, closeTo(12 / 28, 0.02));
      expect(payload.trajectory.dy, greaterThan(0));
    });
  });
}
