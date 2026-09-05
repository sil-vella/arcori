import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/match/input/slam_input_models.dart';
import 'package:arcori/modules/play/game_controls_prefs.dart';

void main() {
  group('aim footprint', () {
    test('center is inside; far aim is outside', () {
      expect(aimOutsideStackFootprint(0, 0), isFalse);
      expect(aimOutsideStackFootprint(kSlamAimHitRadius * 2, 0), isTrue);
    });

    test('kick from center is mostly into-stack', () {
      final kick = kickDirectionFromAim(0, 0);
      expect(kick.dy, greaterThan(0.9));
      expect(kick.dx.abs(), lessThan(0.1));
    });
  });

  group('fuseTouchPowerSlam', () {
    test('down swipe yields speed and freezes aim', () {
      const aim = SlamAim(x: 0.01, z: -0.005);
      final payload = fuseTouchPowerSlam(
        swipePrimaryVelocity: 1000,
        swipeDy: 120,
        aim: aim,
      );
      expect(payload.speed, greaterThan(0.2));
      expect(payload.aim.x, closeTo(0.01, 1e-6));
      expect(payload.aim.z, closeTo(-0.005, 1e-6));
      expect(payload.source, 'gesture');
      expect(payload.toJson()['aim'], isA<Map>());
    });

    test('slow drag without velocity uses distance speed', () {
      final payload = fuseTouchPowerSlam(
        swipePrimaryVelocity: 0,
        swipeDy: 80,
        aim: SlamAim.center,
      );
      expect(payload.speed, greaterThan(0.12));
      expect(payload.speed, lessThan(0.35));
    });
  });

  group('fuseAccelPowerSlam', () {
    test('shake-only yields speed from Z peak and freezes aim', () {
      const aim = SlamAim(x: 0.008, z: 0.004);
      final payload = fuseAccelPowerSlam(
        motionPeakMagnitude: 12,
        motionPeakX: 0.2,
        motionPeakY: -8,
        motionPeakZ: 4,
        aim: aim,
      );
      expect(payload.source, 'shake');
      expect(payload.speed, closeTo(12 / 28, 0.02));
      expect(payload.aim.x, closeTo(0.008, 1e-6));
    });
  });

  group('timeout / mode', () {
    test('timeout payload is zero speed center aim', () {
      final payload = timeoutSlamInput();
      expect(payload.speed, 0);
      expect(payload.aim.x, 0);
      expect(payload.aim.z, 0);
      expect(payload.source, 'timeout');
    });

    test('SlamControlMode parses', () {
      expect(SlamControlMode.tryParse('accel'), SlamControlMode.accel);
      expect(SlamControlMode.tryParse('touch'), SlamControlMode.touch);
      expect(SlamControlMode.tryParse('nope'), isNull);
    });
  });
}
