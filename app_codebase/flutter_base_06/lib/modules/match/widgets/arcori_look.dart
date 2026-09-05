import 'package:flutter/material.dart';

import 'arcori_palette.dart';

/// Slightly thick rim — same on the match stack, Avari chips, and Velora.
const double kArcoriRimWidth = 3.5;

/// Hairline at the inner edge of the rim (back face).
const double kArcoriInnerLineWidth = 1.25;

/// Visual cylinder depth as a fraction of disc [size].
const double kArcoriThicknessFactor = 0.08;

/// Catalog appearance for one Arcori (or slammer) disc — SSOT for every surface.
class ArcoriLook {
  const ArcoriLook({
    required this.designId,
    this.imageUrl,
    this.colorHex,
  });

  final String designId;
  final String? imageUrl;
  final String? colorHex;

  /// Assigned catalog color, or a stable hash fallback when hex is missing.
  Color get accent =>
      parseCatalogColor(colorHex) ?? arcoriAccentForDesignId(designId);

  /// Front/back fill and rim.
  Color get backColor => accent;

  /// Cylinder edge — same hue, slightly darker so thickness reads in 3D.
  Color get edgeColor => Color.lerp(accent, const Color(0xFF000000), 0.22)!;

  /// Back-face hairline: same hue as the fill, auto light/dark + saturation.
  Color get innerLineColor => arcoriBackInnerLineColor(backColor);

  Color get labelColor => arcoriAccentLabelColor(accent);

  String get fallbackLabel {
    if (designId.length > 8) return designId.substring(designId.length - 8);
    return designId;
  }
}
