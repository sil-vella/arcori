import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../state/match_snapshot_state.dart';

/// Thin round medallion — face-down / face-up via rotationX.
class ArcoriDisc extends StatelessWidget {
  const ArcoriDisc({
    super.key,
    required this.piece,
    required this.size,
    this.offset = Offset.zero,
    this.rotationX = 0,
  });

  final MatchPieceView piece;
  final double size;
  final Offset offset;
  final double rotationX;

  @override
  Widget build(BuildContext context) {
    final faceUp = piece.faceUp || rotationX.abs() > pi / 2;
    final label = piece.designId.length > 8
        ? piece.designId.substring(piece.designId.length - 8)
        : piece.designId;

    return Transform.translate(
      offset: offset,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(rotationX),
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: faceUp
                    ? [
                        AppColors.primary.withValues(alpha: 0.95),
                        AppColors.primary.withValues(alpha: 0.55),
                      ]
                    : [
                        const Color(0xFF3A3A3A),
                        const Color(0xFF1A1A1A),
                      ],
              ),
              border: Border.all(
                color: faceUp ? AppColors.primary : Colors.white24,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateX(faceUp && rotationX.abs() > pi / 2 ? pi : 0),
                child: Text(
                  faceUp ? label : '●',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
