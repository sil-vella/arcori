import 'package:flutter/material.dart';

import 'app_buttons.dart';
import 'app_colors.dart';
import 'app_modal_theme.dart';
import 'app_typography.dart';

/// Builds [ThemeData] and exposes theme helpers for the app.
abstract final class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ColorScheme colorScheme(Brightness brightness) =>
      brightness == Brightness.dark ? _darkColorScheme : _lightColorScheme;

  static ThemeData _build(Brightness brightness) {
    final scheme = colorScheme(brightness);
    final isDark = brightness == Brightness.dark;
    final buttons = AppButtonStyles.forBrightness(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: AppTypography.materialTextTheme(brightness),
      scaffoldBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.background,
      dividerColor: isDark ? AppColors.dividerDark : AppColors.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.forBrightness(brightness).appBarTitle
            .copyWith(color: scheme.onPrimaryContainer),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AppColors.outlineDark : AppColors.outline,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttons.primary.filled),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: buttons.primary.outlined),
      textButtonTheme: TextButtonThemeData(style: buttons.primary.text),
      iconButtonTheme: IconButtonThemeData(style: buttons.primary.icon),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttons.primary.filled),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: AppTypography.forBrightness(brightness).label,
        hintStyle: AppTypography.forBrightness(brightness).caption,
        errorStyle: AppTypography.forBrightness(brightness).caption.copyWith(
              color: scheme.error,
            ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      extensions: [
        const AppThemeExtension(),
        if (isDark) AppTypographyExtension.dark else AppTypographyExtension.light,
        if (isDark) AppButtonStylesExtension.dark else AppButtonStylesExtension.light,
        if (isDark) AppModalThemeExtension.dark else AppModalThemeExtension.light,
      ],
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryPastel,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryPastel,
    onSecondaryContainer: AppColors.onSecondary,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryPastel,
    onTertiaryContainer: AppColors.onTertiary,
    error: AppColors.red,
    onError: AppColors.onRed,
    errorContainer: AppColors.redPastel,
    onErrorContainer: AppColors.onRed,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceMuted,
    outline: AppColors.outline,
    outlineVariant: AppColors.divider,
    shadow: Color(0x1A000000),
    scrim: Color(0x66000000),
    inverseSurface: AppColors.onSurface,
    onInverseSurface: AppColors.surface,
    inversePrimary: AppColors.primaryPastel,
    surfaceTint: AppColors.primary,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainerDark,
    onPrimaryContainer: AppColors.primaryPastel,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainerDark,
    onSecondaryContainer: AppColors.secondaryPastel,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainerDark,
    onTertiaryContainer: AppColors.tertiaryPastel,
    error: AppColors.red,
    onError: AppColors.onRed,
    errorContainer: AppColors.errorContainerDark,
    onErrorContainer: AppColors.redPastel,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onSurfaceDark,
    onSurfaceVariant: AppColors.onSurfaceMutedDark,
    outline: AppColors.outlineDark,
    outlineVariant: AppColors.dividerDark,
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
    inverseSurface: AppColors.onSurfaceDark,
    onInverseSurface: AppColors.surfaceDark,
    inversePrimary: AppColors.primary,
    surfaceTint: AppColors.primary,
  );
}

/// Brand palette exposed on [ThemeData.extensions] for convenient access.
///
/// Prefer [AppColors] for static references; use this when you already have a
/// [BuildContext] and want theme-adjacent tokens in one place.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension();

  Color get primary => AppColors.primary;
  Color get primaryPastel => AppColors.primaryPastel;
  Color get secondary => AppColors.secondary;
  Color get secondaryPastel => AppColors.secondaryPastel;
  Color get tertiary => AppColors.tertiary;
  Color get tertiaryPastel => AppColors.tertiaryPastel;
  Color get accent => AppColors.accent;
  Color get accentPastel => AppColors.accentPastel;

  Color get green => AppColors.green;
  Color get greenPastel => AppColors.greenPastel;
  Color get red => AppColors.red;
  Color get redPastel => AppColors.redPastel;
  Color get amber => AppColors.amber;
  Color get amberPastel => AppColors.amberPastel;
  Color get blue => AppColors.blue;
  Color get bluePastel => AppColors.bluePastel;

  @override
  AppThemeExtension copyWith() => const AppThemeExtension();

  @override
  AppThemeExtension lerp(covariant AppThemeExtension? other, double t) =>
      const AppThemeExtension();
}

/// Convenience accessors for theme, palette, and spacing from [BuildContext].
extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);

  ColorScheme get appColorScheme => Theme.of(this).colorScheme;

  TextTheme get appTextTheme => Theme.of(this).textTheme;

  /// Semantic text styles (headers, menus, body, labels, etc.).
  AppTypographyExtension get appTypography =>
      Theme.of(this).extension<AppTypographyExtension>() ??
      AppTypographyExtension.light;

  /// Brand and semantic button styles (filled, tonal, outlined, text, icon).
  AppButtonStylesExtension get appButtons =>
      Theme.of(this).extension<AppButtonStylesExtension>() ??
      AppButtonStylesExtension.light;

  /// Modal overlay tokens (scrim, surface, max width).
  AppModalThemeExtension get appModalTheme =>
      Theme.of(this).extension<AppModalThemeExtension>() ??
      AppModalThemeExtension.light;

  /// Brand palette tokens registered on the active theme.
  AppThemeExtension get appColors =>
      Theme.of(this).extension<AppThemeExtension>() ??
      const AppThemeExtension();
}
