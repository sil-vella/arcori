import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Layout and motion tokens for modal overlays.
abstract final class AppModalMetrics {
  AppModalMetrics._();

  static const double centeredMaxWidth = 400;
  static const double borderRadius = 12;
  static const double elevation = 0;

  static const double scrimOpacityLight = 0.45;
  static const double scrimOpacityDark = 0.55;

  static const Duration transitionDuration = Duration(milliseconds: 250);
  static const Duration reverseTransitionDuration = Duration(milliseconds: 200);

  static const Curve transitionCurve = Curves.easeOutCubic;
  static const Curve reverseTransitionCurve = Curves.easeInCubic;

  static const double centeredScaleBegin = 0.96;
  static const Offset fullScreenSlideBegin = Offset(0, 0.04);
}

/// Modal overlay colors and dimensions derived from app palette.
abstract final class AppModalTheme {
  AppModalTheme._();

  static Color scrim(Brightness brightness) {
    final opacity = brightness == Brightness.dark
        ? AppModalMetrics.scrimOpacityDark
        : AppModalMetrics.scrimOpacityLight;
    return AppColors.onSurface.withValues(alpha: opacity);
  }

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? AppColors.surfaceDark : AppColors.surface;

  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? AppColors.outlineDark : AppColors.outline;
}

/// Modal tokens exposed on [ThemeData.extensions].
@immutable
class AppModalThemeExtension extends ThemeExtension<AppModalThemeExtension> {
  const AppModalThemeExtension({required this.brightness});

  final Brightness brightness;

  static final light = AppModalThemeExtension(brightness: Brightness.light);
  static final dark = AppModalThemeExtension(brightness: Brightness.dark);

  Color get scrim => AppModalTheme.scrim(brightness);
  Color get surface => AppModalTheme.surface(brightness);
  Color get border => AppModalTheme.border(brightness);
  double get maxWidth => AppModalMetrics.centeredMaxWidth;
  double get borderRadius => AppModalMetrics.borderRadius;

  @override
  AppModalThemeExtension copyWith({Brightness? brightness}) {
    return AppModalThemeExtension(brightness: brightness ?? this.brightness);
  }

  @override
  AppModalThemeExtension lerp(
    covariant AppModalThemeExtension? other,
    double t,
  ) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
