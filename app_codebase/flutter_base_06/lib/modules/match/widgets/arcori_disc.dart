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

bool faceUpFromQuat(double x, double y, double z, double w) {
  final q = Quaternion(x, y, z, w)..normalize();
  final up = q.rotated(Vector3(0, 1, 0));
  return up.y >= 0.35;
}

Matrix4 matrixFromQuat(double x, double y, double z, double w) {
  final q = Quaternion(x, y, z, w)..normalize();
  final m = Matrix4.identity();
  m.setRotation(q.asRotationMatrix());
  return m;
}
