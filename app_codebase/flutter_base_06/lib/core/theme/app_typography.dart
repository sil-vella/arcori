import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Font family tokens. Set [primary] when custom fonts are added to pubspec.
abstract final class AppFonts {
  AppFonts._();

  /// Main UI font. `null` uses the platform default (Roboto / SF Pro).
  static const String? primary = null;

  /// Code, logs, and technical output.
  static const String monospace = 'monospace';
}

/// Font size scale — raw values for one-off use or custom compositions.
abstract final class AppFontSizes {
  AppFontSizes._();

  static const double display = 48;
  static const double h1 = 32;
  static const double h2 = 28;
  static const double h3 = 24;
  static const double h4 = 20;
  static const double title = 18;
  static const double subtitle = 16;
  static const double menu = 16;
  static const double menuSmall = 14;
  static const double bodyLarge = 16;
  static const double body = 14;
  static const double bodySmall = 12;
  static const double label = 12;
  static const double caption = 11;
  static const double button = 14;
  static const double appBar = 20;
  static const double monospace = 12;
  static const double monospaceSmall = 11;
}

abstract final class AppFontWeights {
  AppFontWeights._();

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

abstract final class AppLineHeights {
  AppLineHeights._();

  static const double tight = 1.2;
  static const double normal = 1.4;
  static const double relaxed = 1.5;
  static const double loose = 1.6;
}

/// Semantic text styles for screens, menus, and chrome.
@immutable
class AppTypographyStyles {
  const AppTypographyStyles({
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.h4,
    required this.title,
    required this.subtitle,
    required this.appBarTitle,
    required this.menu,
    required this.menuSmall,
    required this.bodyLarge,
    required this.body,
    required this.bodySmall,
    required this.bodyMuted,
    required this.label,
    required this.caption,
    required this.button,
    required this.monospace,
    required this.monospaceSmall,
  });

  final TextStyle display;
  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle h4;
  final TextStyle title;
  final TextStyle subtitle;
  final TextStyle appBarTitle;
  final TextStyle menu;
  final TextStyle menuSmall;
  final TextStyle bodyLarge;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle bodyMuted;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle button;
  final TextStyle monospace;
  final TextStyle monospaceSmall;
}

/// Builds [TextTheme] and semantic style sets from typography tokens.
abstract final class AppTypography {
  AppTypography._();

  static final AppTypographyStyles light =
      _buildStyles(Brightness.light);

  static final AppTypographyStyles dark = _buildStyles(Brightness.dark);

  static AppTypographyStyles forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static TextTheme materialTextTheme(Brightness brightness) {
    final styles = forBrightness(brightness);
    return TextTheme(
      displayLarge: styles.display,
      displayMedium: styles.h1,
      displaySmall: styles.h2,
      headlineLarge: styles.h3,
      headlineMedium: styles.h4,
      headlineSmall: styles.title,
      titleLarge: styles.appBarTitle,
      titleMedium: styles.subtitle,
      titleSmall: styles.menu,
      bodyLarge: styles.bodyLarge,
      bodyMedium: styles.body,
      bodySmall: styles.bodySmall,
      labelLarge: styles.button,
      labelMedium: styles.label,
      labelSmall: styles.caption,
    );
  }

  static AppTypographyStyles _buildStyles(Brightness brightness) {
    final onSurface = brightness == Brightness.dark
        ? AppColors.onSurfaceDark
        : AppColors.onSurface;
    final muted = brightness == Brightness.dark
        ? AppColors.onSurfaceMutedDark
        : AppColors.onSurfaceMuted;

    TextStyle ui({
      required double size,
      FontWeight weight = AppFontWeights.regular,
      Color? color,
      double height = AppLineHeights.normal,
      double? letterSpacing,
    }) {
      return TextStyle(
        fontFamily: AppFonts.primary,
        fontSize: size,
        fontWeight: weight,
        color: color ?? onSurface,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    TextStyle mono({required double size, Color? color}) {
      return TextStyle(
        fontFamily: AppFonts.monospace,
        fontSize: size,
        fontWeight: AppFontWeights.regular,
        color: color ?? muted,
        height: AppLineHeights.normal,
      );
    }

    return AppTypographyStyles(
      display: ui(
        size: AppFontSizes.display,
        weight: AppFontWeights.bold,
        height: AppLineHeights.tight,
      ),
      h1: ui(size: AppFontSizes.h1, weight: AppFontWeights.bold),
      h2: ui(size: AppFontSizes.h2, weight: AppFontWeights.semiBold),
      h3: ui(size: AppFontSizes.h3, weight: AppFontWeights.semiBold),
      h4: ui(size: AppFontSizes.h4, weight: AppFontWeights.medium),
      title: ui(size: AppFontSizes.title, weight: AppFontWeights.semiBold),
      subtitle: ui(size: AppFontSizes.subtitle, weight: AppFontWeights.medium),
      appBarTitle: ui(
        size: AppFontSizes.appBar,
        weight: AppFontWeights.semiBold,
        height: AppLineHeights.tight,
      ),
      menu: ui(size: AppFontSizes.menu, weight: AppFontWeights.medium),
      menuSmall: ui(
        size: AppFontSizes.menuSmall,
        weight: AppFontWeights.medium,
      ),
      bodyLarge: ui(
        size: AppFontSizes.bodyLarge,
        height: AppLineHeights.relaxed,
      ),
      body: ui(size: AppFontSizes.body, height: AppLineHeights.relaxed),
      bodySmall: ui(
        size: AppFontSizes.bodySmall,
        height: AppLineHeights.relaxed,
      ),
      bodyMuted: ui(
        size: AppFontSizes.body,
        color: muted,
        height: AppLineHeights.relaxed,
      ),
      label: ui(
        size: AppFontSizes.label,
        weight: AppFontWeights.medium,
        letterSpacing: 0.2,
      ),
      caption: ui(
        size: AppFontSizes.caption,
        color: muted,
        height: AppLineHeights.normal,
      ),
      button: ui(
        size: AppFontSizes.button,
        weight: AppFontWeights.semiBold,
        height: AppLineHeights.tight,
      ),
      monospace: mono(size: AppFontSizes.monospace),
      monospaceSmall: mono(size: AppFontSizes.monospaceSmall),
    );
  }
}

/// Semantic typography registered on [ThemeData.extensions].
@immutable
class AppTypographyExtension extends ThemeExtension<AppTypographyExtension> {
  const AppTypographyExtension(this.styles);

  final AppTypographyStyles styles;

  static final light = AppTypographyExtension(AppTypography.light);
  static final dark = AppTypographyExtension(AppTypography.dark);

  TextStyle get display => styles.display;
  TextStyle get h1 => styles.h1;
  TextStyle get h2 => styles.h2;
  TextStyle get h3 => styles.h3;
  TextStyle get h4 => styles.h4;
  TextStyle get title => styles.title;
  TextStyle get subtitle => styles.subtitle;
  TextStyle get appBarTitle => styles.appBarTitle;
  TextStyle get menu => styles.menu;
  TextStyle get menuSmall => styles.menuSmall;
  TextStyle get bodyLarge => styles.bodyLarge;
  TextStyle get body => styles.body;
  TextStyle get bodySmall => styles.bodySmall;
  TextStyle get bodyMuted => styles.bodyMuted;
  TextStyle get label => styles.label;
  TextStyle get caption => styles.caption;
  TextStyle get button => styles.button;
  TextStyle get monospace => styles.monospace;
  TextStyle get monospaceSmall => styles.monospaceSmall;

  @override
  AppTypographyExtension copyWith({AppTypographyStyles? styles}) {
    return AppTypographyExtension(styles ?? this.styles);
  }

  @override
  AppTypographyExtension lerp(
    covariant AppTypographyExtension? other,
    double t,
  ) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
