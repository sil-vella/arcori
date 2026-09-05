import 'package:flutter/material.dart';

/// Disc accent palette — shared across all Arcori designs (stable hash pick).
const List<Color> kArcoriAccentPalette = [
  Color(0xFFC6A15B), // Gold
  Color(0xFFA8B0B8), // Silver
  Color(0xFF7A3142), // Maroon
  Color(0xFFB8734A), // Copper
  Color(0xFFD8CDB8), // Warm ivory
  Color(0xFF4E7A78), // Slate teal
  Color(0xFF7A8458), // Dusty olive
  Color(0xFF3E5270), // Soft navy
  Color(0xFFB5817A), // Clay rose
  Color(0xFF5C4A58), // Charcoal plum
];

const List<String> kArcoriAccentNames = [
  'Gold',
  'Silver',
  'Maroon',
  'Copper',
  'Warm ivory',
  'Slate teal',
  'Dusty olive',
  'Soft navy',
  'Clay rose',
  'Charcoal plum',
];

/// Stable accent for [designId] from [kArcoriAccentPalette].
Color arcoriAccentForDesignId(String designId) {
  if (designId.isEmpty) return kArcoriAccentPalette.first;
  var hash = 0;
  for (final unit in designId.codeUnits) {
    hash = 0x7fffffff & (hash * 31 + unit);
  }
  return kArcoriAccentPalette[hash % kArcoriAccentPalette.length];
}

/// Dark label on light accents (e.g. warm ivory / silver).
Color arcoriAccentLabelColor(Color accent) {
  return accent.computeLuminance() > 0.45 ? const Color(0xFF1A1A1A) : Colors.white;
}

/// Pivot: HSL lightness below this is a "dark" back face.
const double kArcoriBackLightnessPivot = 0.5;

/// How far to walk lightness so the inner hairline reads on the fill.
const double kArcoriInnerLineLightnessDelta = 0.28;

/// Same hue as [back]; auto lightness + saturation for a visible inner hairline.
///
/// Dark / dull backs get a lighter, slightly richer line. Light backs get a
/// darker line. Mid saturations keep the catalog color in-family.
Color arcoriBackInnerLineColor(Color back) {
  final hsl = HSLColor.fromColor(back);
  final darkBack = hsl.lightness < kArcoriBackLightnessPivot;
  var lightness = hsl.lightness;
  var saturation = hsl.saturation;

  if (darkBack) {
    lightness = (lightness + kArcoriInnerLineLightnessDelta).clamp(0.42, 0.88);
    if (lightness - hsl.lightness < 0.16) {
      lightness = (hsl.lightness + 0.34).clamp(0.0, 0.90);
    }
    if (saturation < 0.22) {
      saturation = (saturation + 0.18).clamp(0.0, 0.55);
    } else if (saturation > 0.82) {
      saturation = saturation * 0.88;
    }
  } else {
    lightness = (lightness - kArcoriInnerLineLightnessDelta).clamp(0.10, 0.48);
    if (hsl.lightness - lightness < 0.16) {
      lightness = (hsl.lightness - 0.34).clamp(0.10, 1.0);
    }
    if (saturation < 0.22) {
      saturation = (saturation + 0.12).clamp(0.0, 0.45);
    }
  }

  return hsl.withLightness(lightness).withSaturation(saturation).toColor();
}

/// Parse catalog JSON `color` (`#RRGGBB`). Null if missing or invalid.
Color? parseCatalogColor(String? raw) {
  if (raw == null) return null;
  var hex = raw.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) {
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
  if (hex.length == 8) {
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }
  return null;
}
