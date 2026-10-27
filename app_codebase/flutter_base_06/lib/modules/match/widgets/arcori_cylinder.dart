import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/http/media_url.dart';
import '../../../core/theme/theme.dart';
import 'arcori_design_labels.dart';
import 'arcori_look.dart';

/// Shared Arcori disc: catalog art, color rim, art back + labels, thickness.
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
    this.face,
  });

  final ArcoriLook look;
  final double size;
  final bool faceUp;
  final bool showThickness;

  /// Optional face art (e.g. Kin scene). When set, replaces catalog [look.imageUrl].
  final Widget? face;

  @override
  Widget build(BuildContext context) {
    final thickness = size * kArcoriThicknessFactor;
    final scheme = context.appColorScheme;
    final imageUrl = look.imageUrl?.trim() ?? '';
    final rimWidth = look.rimWidthFor(size);
    final faceSize = (size - 2 * rimWidth).clamp(1.0, size);

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
              child: look.isSlammer
                  ? CustomPaint(
                      painter: SlammerSideEdgePainter(
                        color: look.edgeColor,
                        band: thickness,
                      ),
                      child: SizedBox(width: size, height: size),
                    )
                  : DecoratedBox(
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
                  color: AppColors.onSurface.withValues(alpha: 0.28),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox(width: size, height: size),
          ),
          // Keep face art mounted while face-down so a flip is instant.
          if (face != null && faceUp)
            ClipOval(
              child: SizedBox(width: faceSize, height: faceSize, child: face),
            )
          else if (imageUrl.isNotEmpty)
            Opacity(
              opacity: faceUp ? 1 : 0,
              child: ClipOval(
                child: SizedBox(
                  width: faceSize,
                  height: faceSize,
                  child: _ArcoriMediaImage(
                    path: imageUrl,
                    size: faceSize,
                    fallback: look,
                  ),
                ),
              ),
            ),
          if (!faceUp)
            ClipOval(
              child: SizedBox(
                width: faceSize,
                height: faceSize,
                child: _ArcoriBackFace(look: look, size: faceSize),
              ),
            )
          else if (face == null && imageUrl.isEmpty)
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
                      style: context.appTypography.caption.copyWith(
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
              rimWidth: rimWidth,
              paintInnerLine: !faceUp && !look.isSlammer,
              slammerRing: look.isSlammer,
              rimEdgeColor: look.isSlammer ? look.rimEdgeColor : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcoriMediaImage extends StatelessWidget {
  const _ArcoriMediaImage({
    required this.path,
    required this.size,
    required this.fallback,
  });

  final String path;
  final double size;
  final ArcoriLook fallback;

  @override
  Widget build(BuildContext context) {
    final err = ColoredBox(
      color: fallback.backColor,
      child: Center(
        child: Text(
          fallback.fallbackLabel,
          textAlign: TextAlign.center,
          style: context.appTypography.caption.copyWith(
            color: fallback.labelColor,
            fontSize: size * 0.14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    if (isBundleAssetMedia(path)) {
      return Image.asset(
        bundleAssetPath(path),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => err,
      );
    }

    final url = resolveMediaUrl(path);
    if (url.isEmpty) return err;
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => err,
    );
  }
}

/// Shared back art + bottom-up serial / generation / series labels.
class _ArcoriBackFace extends StatelessWidget {
  const _ArcoriBackFace({required this.look, required this.size});

  final ArcoriLook look;
  final double size;

  @override
  Widget build(BuildContext context) {
    final labels = ArcoriDesignLabels.fromDesignId(look.designId);
    final pad = (size * 0.08).clamp(2.0, 10.0);
    final fontSize = (size * 0.085).clamp(5.0, 14.0);
    final style = context.appTypography.caption.copyWith(
      color: AppColors.onSurfaceDark,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: 0.3,
      shadows: [
        Shadow(
          color: AppColors.onSurface.withValues(alpha: 0.8),
          blurRadius: 2,
          offset: const Offset(0, 0.5),
        ),
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          kArcoriBackAssetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => ColoredBox(color: look.backColor),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * 1.2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                labels.series,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              Text(
                labels.generation,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              Text(
                labels.serial,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Machined grooves, radial ticks, and grain clipped to an annulus.
void paintSlammerMetalTexture(
  Canvas canvas, {
  required Offset center,
  required double outerR,
  required double innerR,
  required Color baseColor,
}) {
  final band = outerR - innerR;
  if (band <= 0.5) return;
  canvas.save();
  canvas.clipPath(
    Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerR))
      ..addOval(Rect.fromCircle(center: center, radius: innerR))
      ..fillType = PathFillType.evenOdd,
  );

  final dark = Color.lerp(baseColor, Colors.black, 0.42)!;
  final light = Color.lerp(baseColor, Colors.white, 0.62)!;
  final grooves = (band / 1.6).round().clamp(3, 10);
  for (var i = 0; i < grooves; i++) {
    final t = (i + 0.5) / grooves;
    final groove = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = (band * 0.06).clamp(0.6, 1.4)
      ..color = (i.isEven ? dark : light).withValues(
        alpha: i.isEven ? 0.42 : 0.34,
      );
    canvas.drawCircle(center, innerR + band * t, groove);
  }

  final ticks = (outerR * 1.1).round().clamp(28, 80);
  final tick = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = (band * 0.045).clamp(0.5, 1.1)
    ..color = dark.withValues(alpha: 0.28);
  for (var i = 0; i < ticks; i++) {
    final angle = (i / ticks) * math.pi * 2;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final start = innerR + band * 0.18;
    final end = outerR - band * 0.18;
    canvas.drawLine(
      Offset(center.dx + cosA * start, center.dy + sinA * start),
      Offset(center.dx + cosA * end, center.dy + sinA * end),
      tick,
    );
  }

  final grain = Paint()..style = PaintingStyle.fill;
  final rng = math.Random(17);
  final specks = (band * 6).round().clamp(10, 48);
  for (var i = 0; i < specks; i++) {
    final angle = rng.nextDouble() * math.pi * 2;
    final radius = innerR + band * (0.2 + rng.nextDouble() * 0.6);
    grain.color = (rng.nextBool() ? light : dark).withValues(
      alpha: 0.22 + rng.nextDouble() * 0.2,
    );
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      ),
      rng.nextDouble() * 0.7 + 0.35,
      grain,
    );
  }
  canvas.restore();
}

/// Cylinder wall peeking under a slammer: same metal texture as the face ring.
class SlammerSideEdgePainter extends CustomPainter {
  const SlammerSideEdgePainter({required this.color, required this.band});

  final Color color;
  final double band;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..isAntiAlias = true
        ..color = color,
    );
    final wall = band.clamp(0.0, outerR);
    paintSlammerMetalTexture(
      canvas,
      center: center,
      outerR: outerR,
      innerR: (outerR - wall).clamp(0.0, outerR),
      baseColor: color,
    );
  }

  @override
  bool shouldRepaint(covariant SlammerSideEdgePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.band != band;
  }
}

/// Catalog-color rim in front of the face.
///
/// Arcori rings are 1/16 of the diameter. Slammer rings are 2/16, with a
/// machined groove texture, a darker border on both edges, and a shine across
/// the band. Back-face Arcori keep the inner hairline.
class ArcoriRimPainter extends CustomPainter {
  const ArcoriRimPainter({
    required this.rimColor,
    required this.innerLineColor,
    required this.rimWidth,
    this.innerLineWidth = kArcoriInnerLineWidth,
    this.paintInnerLine = false,
    this.slammerRing = false,
    this.rimEdgeColor,
  });

  final Color rimColor;
  final Color innerLineColor;
  final double rimWidth;
  final double innerLineWidth;
  final bool paintInnerLine;
  final bool slammerRing;
  final Color? rimEdgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2;
    final band = rimWidth.clamp(0.0, outerR);
    final midR = (outerR - band / 2).clamp(0.5, outerR);
    final rimPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = band
      ..color = rimColor;
    canvas.drawCircle(center, midR, rimPaint);

    if (slammerRing && band > 0) {
      _paintSlammerTexture(canvas, center, outerR, band);
      _paintSlammerShine(canvas, center, outerR, band);
      _paintSlammerEdges(canvas, center, outerR, band);
    }

    if (!paintInnerLine) return;
    final linePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerLineWidth
      ..color = innerLineColor;
    canvas.drawCircle(center, (outerR - band).clamp(0.5, outerR), linePaint);
  }

  void _paintSlammerTexture(
    Canvas canvas,
    Offset center,
    double outerR,
    double band,
  ) {
    final innerR = (outerR - band).clamp(0.0, outerR);
    paintSlammerMetalTexture(
      canvas,
      center: center,
      outerR: outerR,
      innerR: innerR,
      baseColor: rimColor,
    );
  }

  Path _slammerRingPath(Offset center, double outerR, double innerR) {
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerR))
      ..addOval(Rect.fromCircle(center: center, radius: innerR))
      ..fillType = PathFillType.evenOdd;
  }

  void _paintSlammerShine(
    Canvas canvas,
    Offset center,
    double outerR,
    double band,
  ) {
    final innerR = (outerR - band).clamp(0.0, outerR);
    canvas.save();
    canvas.clipPath(_slammerRingPath(center, outerR, innerR));
    final bounds = Rect.fromCircle(center: center, radius: outerR);
    final gleam = Color.lerp(rimColor, Colors.white, 0.78)!;
    final shade = Color.lerp(rimColor, Colors.black, 0.4)!;
    final wash = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          gleam.withValues(alpha: 0.85),
          rimColor.withValues(alpha: 0.05),
          shade.withValues(alpha: 0.45),
        ],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, wash);
    final glint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (band * 0.22).clamp(1.0, 8.0)
      ..color = Colors.white.withValues(alpha: 0.72);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerR - band * 0.38),
      -2.45,
      1.05,
      false,
      glint,
    );
    canvas.restore();
  }

  void _paintSlammerEdges(
    Canvas canvas,
    Offset center,
    double outerR,
    double band,
  ) {
    final edge = rimEdgeColor ?? rimColor;
    final border = (outerR * 2 * (1 / 64)).clamp(1.0, band * 0.16);
    final edgePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = border
      ..color = edge;
    canvas.drawCircle(
      center,
      (outerR - border / 2).clamp(0.5, outerR),
      edgePaint,
    );
    canvas.drawCircle(
      center,
      (outerR - band + border / 2).clamp(0.5, outerR),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ArcoriRimPainter oldDelegate) {
    return oldDelegate.rimColor != rimColor ||
        oldDelegate.innerLineColor != innerLineColor ||
        oldDelegate.rimWidth != rimWidth ||
        oldDelegate.innerLineWidth != innerLineWidth ||
        oldDelegate.paintInnerLine != paintInnerLine ||
        oldDelegate.slammerRing != slammerRing ||
        oldDelegate.rimEdgeColor != rimEdgeColor;
  }
}
