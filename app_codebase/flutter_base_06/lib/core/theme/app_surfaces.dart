import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';

/// Gallery / reliquary surface fills and frame borders derived from [AppColors].
///
/// Prefer these over inventing one-off DecoratedBox colors in screens.
abstract final class AppSurfaces {
  AppSurfaces._();

  /// Soft lavender (light) / velvet purple (dark) page canvas.
  static Color canvas(Brightness brightness) => brightness == Brightness.dark
      ? AppColors.backgroundDark
      : AppColors.background;

  /// Exhibit card fill — white day / raised night surface.
  static Color exhibit(Brightness brightness) => brightness == Brightness.dark
      ? AppColors.surfaceDark
      : AppColors.surface;

  /// Slightly elevated panel (lists, section bodies).
  static Color panel(Brightness brightness) => brightness == Brightness.dark
      ? AppColors.primaryContainerDark
      : AppColors.primaryPastel.withValues(alpha: 0.35);

  /// Hairline gold frame for hero frames and CTAs.
  static Color frameGold(Brightness brightness) => brightness == Brightness.dark
      ? AppColors.secondary.withValues(alpha: 0.72)
      : AppColors.secondary;

  /// Hairline bronze frame for section rails and quiet cards.
  static Color frameBronze(Brightness brightness) =>
      brightness == Brightness.dark
          ? AppColors.tertiary.withValues(alpha: 0.65)
          : AppColors.tertiary;

  /// Match HUD glass fill (piano-glass overlay).
  static Color glassHud(Brightness brightness) => brightness == Brightness.dark
      ? AppColors.surfaceDark.withValues(alpha: 0.72)
      : AppColors.onSurface.withValues(alpha: 0.42);

  /// Match HUD glass border.
  static Color glassHudBorder(Brightness brightness) =>
      brightness == Brightness.dark
          ? AppColors.secondary.withValues(alpha: 0.35)
          : AppColors.onPrimary.withValues(alpha: 0.28);

  /// Default exhibit card border radius.
  static double get exhibitRadius => AppRadii.lg;

  /// Quiet panel / list-row radius.
  static double get panelRadius => AppRadii.md;
}

/// Surface + HUD tokens registered on [ThemeData.extensions].
@immutable
class AppSurfacesExtension extends ThemeExtension<AppSurfacesExtension> {
  const AppSurfacesExtension({required this.brightness});

  final Brightness brightness;

  static final light = AppSurfacesExtension(brightness: Brightness.light);
  static final dark = AppSurfacesExtension(brightness: Brightness.dark);

  Color get canvas => AppSurfaces.canvas(brightness);
  Color get exhibit => AppSurfaces.exhibit(brightness);
  Color get panel => AppSurfaces.panel(brightness);
  Color get frameGold => AppSurfaces.frameGold(brightness);
  Color get frameBronze => AppSurfaces.frameBronze(brightness);
  Color get glassHud => AppSurfaces.glassHud(brightness);
  Color get glassHudBorder => AppSurfaces.glassHudBorder(brightness);

  double get exhibitRadius => AppSurfaces.exhibitRadius;
  double get panelRadius => AppSurfaces.panelRadius;

  @override
  AppSurfacesExtension copyWith({Brightness? brightness}) {
    return AppSurfacesExtension(brightness: brightness ?? this.brightness);
  }

  @override
  AppSurfacesExtension lerp(
    covariant AppSurfacesExtension? other,
    double t,
  ) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Match HUD state colors — aim lock, power, miss zone.
@immutable
class AppHudThemeExtension extends ThemeExtension<AppHudThemeExtension> {
  const AppHudThemeExtension();

  /// Living spark — armed / aim-locked (brand green, not Material accent).
  Color get armed => AppColors.accent;

  Color get aimLocked => AppColors.accent;

  Color get powerLow => AppColors.secondary;

  Color get powerMid => AppColors.amber;

  Color get powerHigh => AppColors.tertiary;

  Color get missZone => AppColors.red;

  Color get glassFill => AppColors.onSurface.withValues(alpha: 0.35);

  Color get glassBorder => AppColors.onPrimary.withValues(alpha: 0.28);

  Color get onGlass => AppColors.onPrimary;

  Color get onGlassMuted => AppColors.onPrimary.withValues(alpha: 0.55);

  Color get track => AppColors.onPrimary.withValues(alpha: 0.12);

  @override
  AppHudThemeExtension copyWith() => const AppHudThemeExtension();

  @override
  AppHudThemeExtension lerp(
    covariant AppHudThemeExtension? other,
    double t,
  ) =>
      const AppHudThemeExtension();
}
