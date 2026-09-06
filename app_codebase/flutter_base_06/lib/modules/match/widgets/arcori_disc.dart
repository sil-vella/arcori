import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../state/match_snapshot_state.dart';
import 'arcori_cylinder.dart';
import 'arcori_look.dart';

/// Thin cylinder disc — pose transform around [ArcoriCylinder] (look SSOT).
class ArcoriDisc extends StatelessWidget {
  const ArcoriDisc({
    super.key,
    required this.piece,
    required this.size,
    this.offset = Offset.zero,
    this.viewPitch = 0,
    this.qx = 0,
    this.qy = 0,
    this.qz = 0,
    this.qw = 1,
    this.faceUpOverride,
  });

  final MatchPieceView piece;
  final double size;
  final Offset offset;
  /// Camera pitch (rad). 0 = dead-above (full circles); negative tilts toward side.
  final double viewPitch;
  final double qx;
  final double qy;
  final double qz;
  final double qw;
  final bool? faceUpOverride;

  @override
  Widget build(BuildContext context) {
    final faceUp = faceUpOverride ?? faceUpFromQuat(qx, qy, qz, qw);
    final look = ArcoriLook(
      designId: piece.designId,
      imageUrl: piece.imageUrl,
      colorHex: piece.color,
    );

    final transform = Matrix4.identity()..translate(offset.dx, offset.dy);
    if (viewPitch.abs() > 1e-6) {
      transform
        ..setEntry(3, 2, 0.0009)
        ..rotateX(viewPitch);
    }
    transform.multiply(matrixFromQuat(qx, qy, qz, qw));

    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: ArcoriCylinder(
        look: look,
        size: size,
        faceUp: faceUp,
      ),
    );
  }
}

/// Nearly flat on the table — use yaw-only view so we never 180-flip the widget.
const double kDiscFlatViewDot = 0.92;

bool faceUpFromQuat(double x, double y, double z, double w) {
  final q = Quaternion(x, y, z, w)..normalize();
  final up = q.rotated(Vector3(0, 1, 0));
  return up.y >= 0.35;
}

/// In-plane heading only (physics yaw around Y). Drops face-down π-about-X.
/// The widget is one-sided: art vs back is [ArcoriCylinder.faceUp], not a 180° flip.
Quaternion inPlaneYawOnly(Quaternion q) {
  final localX = q.rotated(Vector3(1, 0, 0));
  var hx = localX.x;
  var hz = localX.z;
  var hLen = sqrt(hx * hx + hz * hz);
  if (hLen < 1e-5) {
    final localZ = q.rotated(Vector3(0, 0, 1));
    hx = localZ.x;
    hz = localZ.z;
    hLen = sqrt(hx * hx + hz * hz);
  }
  final yaw = hLen < 1e-5 ? 0.0 : atan2(-hz, hx);
  return Quaternion.axisAngle(Vector3(0, 1, 0), yaw)..normalize();
}

/// Physics is Y-up (table XZ). The disc widget lies in screen XY (face along Z).
/// Conjugate by +90° around X so table yaw (physics Y) becomes in-plane spin.
Quaternion physicsToViewQuat(Quaternion q) {
  final basis = Quaternion.axisAngle(Vector3(1, 0, 0), pi / 2);
  return (basis * q * basis.conjugated())..normalize();
}

/// View pose for painting: full tumble in the air; yaw-only when flat so the
/// painted face stays toward the camera (otherwise flipped art is backface-culled).
Quaternion discViewQuat(Quaternion physicsQ) {
  final n = physicsQ.rotated(Vector3(0, 1, 0));
  final src =
      n.y.abs() >= kDiscFlatViewDot ? inPlaneYawOnly(physicsQ) : physicsQ;
  return physicsToViewQuat(src);
}

/// True when the widget face stays a circle (normal ±screen Z), not on edge.
bool isFlatInView(Quaternion physicsQ, {double eps = 0.02}) {
  final face = discViewQuat(physicsQ).rotated(Vector3(0, 0, 1));
  return face.z.abs() >= 1.0 - eps && face.x.abs() <= eps && face.y.abs() <= eps;
}

/// Painted face (widget +Z) points toward the camera.
bool paintedFaceTowardCamera(Quaternion physicsQ, {double eps = 0.08}) {
  return discViewQuat(physicsQ).rotated(Vector3(0, 0, 1)).z >= 1.0 - eps;
}

Matrix4 matrixFromQuat(double x, double y, double z, double w) {
  final q = discViewQuat(Quaternion(x, y, z, w)..normalize());
  final m = Matrix4.identity();
  m.setRotation(q.asRotationMatrix());
  return m;
}
