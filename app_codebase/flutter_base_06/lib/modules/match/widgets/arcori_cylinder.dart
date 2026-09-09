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
          // Keep face art mounted while face-down so a flip is instant.
          if (face != null && faceUp)
            ClipOval(
              child: SizedBox(
                width: faceSize,
                height: faceSize,
                child: face,
              ),
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
          style: TextStyle(
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
    final style = TextStyle(
      color: const Color(0xFFE8E4DC),
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: 0.3,
      shadows: const [
        Shadow(color: Color(0xCC000000), blurRadius: 2, offset: Offset(0, 0.5)),
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
