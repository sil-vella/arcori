import 'dart:math';

import 'package:arcori/modules/match/widgets/arcori_disc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

void main() {
  test('identity and face-down rest stay flat circles in view', () {
    expect(isFlatInView(Quaternion.identity()), isTrue);
    expect(
      isFlatInView(Quaternion.axisAngle(Vector3(1, 0, 0), pi)),
      isTrue,
    );
  });

  test('physics yaw around Y stays a flat circle with in-plane spin', () {
    const yaw = 0.8;
    final phys = Quaternion.axisAngle(Vector3(0, 1, 0), yaw);
    expect(isFlatInView(phys), isTrue);

    final view = physicsToViewQuat(phys);
    final right = view.rotated(Vector3(1, 0, 0));
    expect(right.z.abs(), lessThan(0.02));
    // Rx(+90) conjugation maps physics yaw to clockwise view spin.
    expect(atan2(right.y, right.x), closeTo(-yaw, 0.08));
  });

  test('yaw then flip stays a flat circle in view', () {
    final restDown = Quaternion.axisAngle(Vector3(0, 1, 0), 0.55) *
        Quaternion.axisAngle(Vector3(1, 0, 0), pi);
    restDown.normalize();
    expect(isFlatInView(restDown), isTrue);
  });

  test('flat rest keeps the painted face toward the camera', () {
    expect(paintedFaceTowardCamera(Quaternion.identity()), isTrue);
    expect(
      paintedFaceTowardCamera(Quaternion.axisAngle(Vector3(1, 0, 0), pi)),
      isTrue,
    );
    final yawUp = Quaternion.axisAngle(Vector3(0, 1, 0), 0.7);
    expect(paintedFaceTowardCamera(yawUp), isTrue);
    expect(faceUpFromQuat(yawUp.x, yawUp.y, yawUp.z, yawUp.w), isTrue);

    final yawDown = yawUp * Quaternion.axisAngle(Vector3(1, 0, 0), pi);
    yawDown.normalize();
    expect(paintedFaceTowardCamera(yawDown), isTrue);
    expect(faceUpFromQuat(yawDown.x, yawDown.y, yawDown.z, yawDown.w), isFalse);
  });
}
