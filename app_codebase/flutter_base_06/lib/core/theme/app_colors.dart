import 'package:flutter/material.dart';

/// Single source of truth for app colors.
///
/// All screens should read colors from here or from [Theme.of] / [ColorScheme]
/// built by [AppTheme]. Prefer semantic tokens (`green`, `red`, `amber`) for
/// status UI and brand tokens (`primary`, `secondary`, `tertiary`, `accent`) for
/// chrome and accents.
abstract final class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────

  /// Muted sage — main brand / primary actions.
  static const Color primary = Color(0xFF8FB5A0);

  /// Light sage — primary containers, chips, highlights.
  static const Color primaryPastel = Color(0xFFD4E8DC);

  /// Muted lavender — secondary actions and supporting UI.
  static const Color secondary = Color(0xFFA89BC4);

  /// Light lavender — secondary containers.
  static const Color secondaryPastel = Color(0xFFE4DCF0);

  /// Dusty peach — tertiary accents and decorative elements.
  static const Color tertiary = Color(0xFFD4A89A);

  /// Light peach — tertiary containers.
  static const Color tertiaryPastel = Color(0xFFF5E0D8);

  /// Muted sky blue — accent highlights, links, focus rings.
  static const Color accent = Color(0xFF7BAFC4);

  /// Light sky — accent containers.
  static const Color accentPastel = Color(0xFFD0E8F0);

  // ── Semantic status ────────────────────────────────────────────────────────

  /// Success / positive state.
  static const Color green = Color(0xFF88C49A);

  static const Color greenPastel = Color(0xFFD4F0DC);

  /// Error / destructive state.
  static const Color red = Color(0xFFD49090);

  static const Color redPastel = Color(0xFFF5D8D8);

  /// Warning / caution state.
  static const Color amber = Color(0xFFD4B878);

  static const Color amberPastel = Color(0xFFF5ECD0);

  /// Informational state.
  static const Color blue = Color(0xFF88A8C4);

  static const Color bluePastel = Color(0xFFD8E8F5);

  // ── Neutrals (light) ─────────────────────────────────────────────────────

  static const Color background = Color(0xFFF8F6F4);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color onSurface = Color(0xFF3D3D3D);

  static const Color onSurfaceMuted = Color(0xFF6B6B6B);

  static const Color outline = Color(0xFFC8C4C0);

  static const Color divider = Color(0xFFE8E4E0);

  // ── Neutrals (dark) ────────────────────────────────────────────────────────

  static const Color backgroundDark = Color(0xFF1E1E1E);

  static const Color surfaceDark = Color(0xFF2A2A2A);

  static const Color onSurfaceDark = Color(0xFFE8E4E0);

  static const Color onSurfaceMutedDark = Color(0xFFB0ACA8);

  static const Color outlineDark = Color(0xFF4A4A4A);

  static const Color dividerDark = Color(0xFF3A3A3A);

  // ── On-color (text/icons on filled tokens) ─────────────────────────────────

  static const Color onPrimary = Color(0xFF1E3D2E);

  static const Color onSecondary = Color(0xFF2E2840);

  static const Color onTertiary = Color(0xFF4A3028);

  static const Color onAccent = Color(0xFF1E3440);

  static const Color onGreen = Color(0xFF1E4030);

  static const Color onRed = Color(0xFF4A2020);

  static const Color onAmber = Color(0xFF4A3A18);

  static const Color onBlue = Color(0xFF1E3040);
}
