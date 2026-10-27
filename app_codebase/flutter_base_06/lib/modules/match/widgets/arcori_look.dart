import 'package:flutter/material.dart';

import 'arcori_palette.dart';

/// Arcori ring thickness as a fraction of the disc diameter.
const double kArcoriRimDiameterFraction = 1 / 16;

/// Slammer ring is twice the Arcori ring (2/16 of the diameter).
const double kSlammerRimDiameterFraction = 2 / 16;

/// Hairline at the inner edge of the rim (back face).
const double kArcoriInnerLineWidth = 1.25;

/// Visual cylinder depth as a fraction of disc [size].
const double kArcoriThicknessFactor = 0.08;

/// Catalog appearance for one Arcori (or slammer) disc — SSOT for every surface.
class ArcoriLook {
  const ArcoriLook({required this.designId, this.imageUrl, this.colorHex});

  final String designId;
  final String? imageUrl;
  final String? colorHex;

  /// Assigned catalog color, or a stable hash fallback when hex is missing.
  Color get accent =>
      parseCatalogColor(colorHex) ?? arcoriAccentForDesignId(designId);

  /// Slammer ids are `SLM-…`. Every other design uses the Arcori ring.
  bool get isSlammer => designId.trim().toUpperCase().startsWith('SLM-');

  /// Ring thickness for a disc of [diameter].
  double rimWidthFor(double diameter) {
    final fraction = isSlammer
        ? kSlammerRimDiameterFraction
        : kArcoriRimDiameterFraction;
    return diameter * fraction;
  }

  /// Darker same-hue edge for the slammer ring’s outer and inner borders.
  Color get rimEdgeColor {
    final hsl = HSLColor.fromColor(accent);
    return hsl
        .withLightness((hsl.lightness * 0.55).clamp(0.05, 0.62))
        .toColor();
  }

  /// Front/back fill and rim.
  Color get backColor => accent;

  /// Cylinder side — same hue as the rim, a clearly darker shade.
  Color get edgeColor {
    final hsl = HSLColor.fromColor(accent);
    final ceiling = (hsl.lightness - 0.16).clamp(0.04, 1.0);
    final next = (hsl.lightness * 0.55).clamp(0.04, ceiling);
    return hsl.withLightness(next).toColor();
  }

  /// Back-face hairline: same hue as the fill, auto light/dark + saturation.
  Color get innerLineColor => arcoriBackInnerLineColor(backColor);

  Color get labelColor => arcoriAccentLabelColor(accent);

  String get fallbackLabel {
    if (designId.length > 8) return designId.substring(designId.length - 8);
    return designId;
  }
}
