import 'package:flutter/material.dart';

import '../screen/shell_chrome_registrar.dart';
import '../theme/theme.dart';

/// Shared Museum / Velora / Home dark chrome (canvas, glass panels, type).
///
/// Use for settings/profile-style screens that are not [AppScreenTemplate001].
abstract final class AppChrome {
  AppChrome._();

  static const Brightness brightness = Brightness.dark;

  static Color get canvasBase => AppSurfaces.canvas(brightness);

  /// Page fill (dark canvas at 80%).
  static Color get canvas => canvasBase.withValues(alpha: 0.8);

  /// Soft glass fill for outer sections.
  static Color get panelFill => AppColors.surfaceDark.withValues(alpha: 0.28);

  static Color get panelBorder =>
      AppSurfaces.frameBronze(brightness).withValues(alpha: 0.55);

  static Color get panelBorderGold =>
      AppSurfaces.frameGold(brightness).withValues(alpha: 0.5);

  static Color get onSurface => AppColors.onSurfaceDark;

  static Color get onSurfaceMuted => AppColors.onSurfaceMutedDark;

  static Color get accentGold => AppSurfaces.frameGold(brightness);

  static Color get accentBronze => AppSurfaces.frameBronze(brightness);

  static Color get fieldFill => AppColors.surfaceDark;

  /// Dark-chrome [InputDecoration] for forms on the canvas.
  static InputDecoration inputDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? suffixIcon,
    bool dense = true,
  }) {
    final bronze = panelBorder;
    final gold = accentGold;
    final radius = BorderRadius.circular(AppRadii.md);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      isDense: dense,
      filled: true,
      fillColor: fieldFill,
      labelStyle: context.appTypography.bodyMuted.copyWith(
        color: onSurfaceMuted,
      ),
      hintStyle: context.appTypography.bodyMuted.copyWith(
        color: onSurfaceMuted,
      ),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: bronze),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: context.appColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: context.appColors.red, width: 1.5),
      ),
    );
  }
}

/// Full-page dark canvas under a transparent AppBar.
///
/// Put [topClearance] at the start of scroll content (or pad a non-scroll
/// child) so body content clears the transparent AppBar.
class AppChromePage extends StatelessWidget {
  const AppChromePage({
    super.key,
    required this.child,
    this.extendBodyBehindAppBar = true,
  });

  final Widget child;
  final bool extendBodyBehindAppBar;

  /// Space below the status bar + toolbar for content under a transparent bar.
  static double topClearance(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight;

  @override
  Widget build(BuildContext context) {
    return ShellChromeRegistrar(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBarForeground: Colors.white,
      child: Theme(
        data: AppTheme.dark,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: AppChrome.onSurface),
          child: IconTheme.merge(
            data: IconThemeData(color: AppChrome.onSurfaceMuted),
            child: ColoredBox(
              color: AppChrome.canvas,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Outer glass section: label rail + optional action + body.
class AppChromeSection extends StatelessWidget {
  const AppChromeSection({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.goldFrame = false,
    this.margin,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool goldFrame;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSurfaces.exhibitRadius);
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: AppChrome.panelFill,
        borderRadius: radius,
        border: Border.all(
          color: goldFrame ? AppChrome.panelBorderGold : AppChrome.panelBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.screenPaddingCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: 20,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppChrome.accentBronze,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: context.appTypography.title.copyWith(
                      color: AppChrome.onSurface,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: AppChrome.accentGold,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            AppSpacing.gapSm,
            child,
          ],
        ),
      ),
    );
    if (margin == null) return panel;
    return Padding(padding: margin!, child: panel);
  }
}

/// Centered empty / error / loading body on the chrome canvas.
class AppChromeCentered extends StatelessWidget {
  const AppChromeCentered({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppChrome.canvas,
      child: Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: child,
        ),
      ),
    );
  }
}
