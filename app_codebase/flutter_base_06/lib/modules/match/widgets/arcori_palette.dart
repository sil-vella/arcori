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
