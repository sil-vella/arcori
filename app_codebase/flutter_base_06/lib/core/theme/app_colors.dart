import 'package:flutter/material.dart';

/// Single source of truth for app colors.
///
/// Brand tokens are sampled from `assets/images/branding/logo.jpg`
/// (purple field, gold wordmark/emblem, green gem accents). Prefer semantic
/// tokens (`green`, `red`, `amber`) for status UI and brand tokens
/// (`primary`, `secondary`, `tertiary`, `accent`) for chrome and accents.
///
/// All screens should read colors from here or from [Theme.of] / [ColorScheme]
/// built by [AppTheme].
abstract final class AppColors {
  AppColors._();

  // ── Brand (from logo.jpg) ──────────────────────────────────────────────────

  /// Arcori purple — main brand / primary actions.
  static const Color primary = Color(0xFF6D2885);

  /// Light lavender — primary containers, chips, highlights.
  static const Color primaryPastel = Color(0xFFD6C2DC);

  /// Arcori gold — secondary actions, wordmark-aligned accents.
  static const Color secondary = Color(0xFFFAB537);

  /// Light gold — secondary containers.
  static const Color secondaryPastel = Color(0xFFFDEAC7);

  /// Metallic bronze — tertiary accents (emblem mid-tone).
  static const Color tertiary = Color(0xFFD39F57);

  /// Light bronze — tertiary containers.
  static const Color tertiaryPastel = Color(0xFFF3E4CF);

  /// Logo green — accent highlights, links, focus rings.
  static const Color accent = Color(0xFF6FB52A);

  /// Light green — accent containers.
  static const Color accentPastel = Color(0xFFD6EAC3);

  // ── Semantic status ────────────────────────────────────────────────────────

  /// Success / positive state (aligned with brand green).
  static const Color green = Color(0xFF6FB52A);

  static const Color greenPastel = Color(0xFFD6EAC3);

  /// Error / destructive state.
  static const Color red = Color(0xFFD49090);

  static const Color redPastel = Color(0xFFF5D8D8);

  /// Warning / caution state (aligned with brand gold).
  static const Color amber = Color(0xFFE0A83A);

  static const Color amberPastel = Color(0xFFF5ECD0);

  /// Informational state.
  static const Color blue = Color(0xFF88A8C4);

  static const Color bluePastel = Color(0xFFD8E8F5);

  // ── Neutrals (light) ─────────────────────────────────────────────────────

  /// Soft lavender-tinted canvas.
  static const Color background = Color(0xFFF7F4F8);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color onSurface = Color(0xFF2E2433);

  static const Color onSurfaceMuted = Color(0xFF6B616F);

  static const Color outline = Color(0xFFC9C0CE);

  static const Color divider = Color(0xFFE8E2EC);

  // ── Neutrals (dark) ────────────────────────────────────────────────────────

  static const Color backgroundDark = Color(0xFF1A121E);

  static const Color surfaceDark = Color(0xFF261C2C);

  static const Color onSurfaceDark = Color(0xFFEDE6F0);

  static const Color onSurfaceMutedDark = Color(0xFFB5AAB8);

  static const Color outlineDark = Color(0xFF4A3F52);

  static const Color dividerDark = Color(0xFF372E3E);

  // ── On-color (text/icons on filled tokens) ─────────────────────────────────

  /// Light text on saturated purple.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Dark text on [primaryPastel] containers / tonal primary.
  static const Color onPrimaryContainer = Color(0xFF270C30);

  /// Dark text on bright gold.
  static const Color onSecondary = Color(0xFF553700);

  /// Dark text on bronze.
  static const Color onTertiary = Color(0xFF3D2A12);

  /// Dark text on brand green.
  static const Color onAccent = Color(0xFF1F3409);

  static const Color onGreen = Color(0xFF1F3409);

  static const Color onRed = Color(0xFF4A2020);

  static const Color onAmber = Color(0xFF4A3A18);

  static const Color onBlue = Color(0xFF1E3040);

  // ── Dark-mode containers (brand-tinted) ────────────────────────────────────

  static const Color primaryContainerDark = Color(0xFF42224D);

  static const Color secondaryContainerDark = Color(0xFF5D4312);

  static const Color tertiaryContainerDark = Color(0xFF5A4224);

  static const Color accentContainerDark = Color(0xFF37501F);

  static const Color errorContainerDark = Color(0xFF5C3030);
}
