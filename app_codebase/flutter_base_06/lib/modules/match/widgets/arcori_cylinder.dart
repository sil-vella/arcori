import 'package:flutter/material.dart';

import '../../../core/http/media_url.dart';
import '../../../core/theme/theme.dart';
import 'arcori_look.dart';

/// Shared Arcori disc: catalog art, color rim, color back, color thickness.
///
/// Used by the match stack, Avari inventory, and Velora. [ArcoriDisc] only
/// adds the 3D pose transform.
class ArcoriCylinder extends StatelessWidget {
  const ArcoriCylinder({
    super.key,
    required this.look,
    required this.size,
    this.faceUp = true,
    this.showThickness = true,
  });

  final ArcoriLook look;
  final double size;
  final bool faceUp;
  final bool showThickness;

  @override
  Widget build(BuildContext context) {
    final thickness = size * kArcoriThicknessFactor;
    final scheme = context.appColorScheme;
    final imageUrl = resolveMediaUrl(look.imageUrl);
    final faceSize = (size - 2 * kArcoriRimWidth).clamp(1.0, size);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (showThickness)
            Transform.translate(
              offset: Offset(0, thickness * 0.55),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: look.edgeColor,
                ),
                child: SizedBox(width: size, height: size),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: look.accent,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox(width: size, height: size),
          ),
          // Keep Image.network mounted while face-down so art is already
          // decoded before a flip (Play-screen prefetch fills ImageCache).
          if (imageUrl.isNotEmpty)
            ClipOval(
              child: SizedBox(
                width: faceSize,
                height: faceSize,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: look.backColor,
                    child: Center(
                      child: Text(
                        look.fallbackLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: look.labelColor,
                          fontSize: size * 0.14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!faceUp)
            ClipOval(
              child: SizedBox(
                width: faceSize,
                height: faceSize,
                child: ColoredBox(color: look.backColor),
              ),
            )
          else if (imageUrl.isEmpty)
            ClipOval(
              child: SizedBox(
                width: faceSize,
                height: faceSize,
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Center(
                    child: Text(
                      look.fallbackLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: look.labelColor,
                        fontSize: size * 0.14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          CustomPaint(
            size: Size(size, size),
            painter: ArcoriRimPainter(
              rimColor: look.accent,
              innerLineColor: look.innerLineColor,
              paintInnerLine: !faceUp,
            ),
          ),
        ],
      ),
    );
  }
}

/// Catalog-color rim in front of the face; optional inner hairline on the back.
class ArcoriRimPainter extends CustomPainter {
  const ArcoriRimPainter({
    required this.rimColor,
    required this.innerLineColor,
    this.rimWidth = kArcoriRimWidth,
    this.innerLineWidth = kArcoriInnerLineWidth,
    this.paintInnerLine = false,
  });

  final Color rimColor;
  final Color innerLineColor;
  final double rimWidth;
  final double innerLineWidth;
  final bool paintInnerLine;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2;
    final rimPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimWidth
      ..color = rimColor;
    canvas.drawCircle(center, (outerR - rimWidth / 2).clamp(0.5, outerR), rimPaint);

    if (!paintInnerLine) return;
    final linePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerLineWidth
      ..color = innerLineColor;
    canvas.drawCircle(
      center,
      (outerR - rimWidth).clamp(0.5, outerR),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ArcoriRimPainter oldDelegate) {
    return oldDelegate.rimColor != rimColor ||
        oldDelegate.innerLineColor != innerLineColor ||
        oldDelegate.rimWidth != rimWidth ||
        oldDelegate.innerLineWidth != innerLineWidth ||
        oldDelegate.paintInnerLine != paintInnerLine;
  }
}
