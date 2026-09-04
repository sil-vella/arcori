import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../state/match_snapshot_state.dart';
import 'arcori_palette.dart';

/// Thin cylinder disc — oriented by world quaternion (local +Y = face normal).
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
    final accent = arcoriAccentForDesignId(piece.designId);
    final labelColor = arcoriAccentLabelColor(accent);
    final label = piece.designId.length > 8
        ? piece.designId.substring(piece.designId.length - 8)
        : piece.designId;
    // Visual thickness cue — small offset circle behind the face (not a bar).
    final thickness = size * 0.08;

    // Dead-above: no perspective foreshortening — face-up reads as a true circle.
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
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Rear rim / thickness (same circle, nudged down+back).
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, thickness * 0.55, -thickness),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
              ),
            ),
            // Face — full opacity.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: faceUp
                      ? [
                          accent.withValues(alpha: 0.98),
                          accent.withValues(alpha: 0.62),
                        ]
                      : [
                          const Color(0xFF3A3A3A),
                          const Color(0xFF1A1A1A),
                        ],
                ),
                border: Border.all(
                  color: faceUp ? accent : Colors.white24,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  faceUp ? label : '●',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: faceUp ? labelColor : Colors.white70,
                    fontSize: size * 0.14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
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
