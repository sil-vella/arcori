import 'package:flutter/material.dart';

import '../bottom_nav/shell_bottom_bar.dart';
import '../screen/shell_chrome_registrar.dart';
import '../theme/theme.dart';
import 'app_visuals.dart';

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

/// Default full-page mural behind shell screens.
const String kMainBackgroundAsset =
    'assets/images/backgrounds/main_background.webp';

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

  /// Inset that already clears the transparent AppBar.
  ///
  /// With [Scaffold.extendBodyBehindAppBar], [MediaQuery.padding.top] is the
  /// full bar (status bar + toolbar). Adding [kToolbarHeight] again left an
  /// empty band under the bar.
  static double topClearance(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  @override
  Widget build(BuildContext context) {
    return ShellChromeRegistrar(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBarForeground: AppColors.onSurfaceDark,
      child: Theme(
        data: AppTheme.dark,
        child: Builder(
          builder: (context) {
            final bottom = MediaQuery.paddingOf(context).bottom;
            final sinkClearance =
                bottom > ShellBottomBar.barContentHeight && bottom < 180
                    ? bottom - ShellBottomBar.playProtrusion
                    : 0.0;
            return DefaultTextStyle.merge(
              style: context.appTypography.body.copyWith(
                color: AppChrome.onSurface,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: AppChrome.onSurfaceMuted),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        kMainBackgroundAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) =>
                            ColoredBox(color: AppChrome.canvas),
                      ),
                    ),
                    const Positioned.fill(child: _MainBackgroundScrim()),
                    Padding(
                      padding: EdgeInsets.only(bottom: sinkClearance),
                      child: child,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dark wash over [kMainBackgroundAsset], top to bottom.
///
/// 0–20% of the page: 20% → 80%. 20–50%: 80% → 95%.
/// 50–80%: 95% → 80%. 80–100%: 80% → 20%.
class _MainBackgroundScrim extends StatelessWidget {
  const _MainBackgroundScrim();

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.backgroundDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ink.withValues(alpha: 0.20),
            ink.withValues(alpha: 0.80),
            ink.withValues(alpha: 0.95),
            ink.withValues(alpha: 0.80),
            ink.withValues(alpha: 0.20),
          ],
          stops: const [0.0, 0.20, 0.50, 0.80, 1.0],
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
    this.icon,
    this.mark,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.goldFrame = false,
    this.margin,
    this.background,
  });

  final String title;
  final IconData? icon;

  /// Painted mark in the title row. Used in place of [icon] when set.
  final Widget? mark;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Sits on the right of the title. An [actionLabel] button takes this spot when both are set.
  final Widget? trailing;
  final bool goldFrame;
  final EdgeInsetsGeometry? margin;

  /// Painted edge to edge under the label, padding, and body. Clipped to the card.
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final backdrop = background;
    final content = Padding(
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
              if (mark != null) ...[
                SizedBox(width: 22, height: 22, child: mark),
                const SizedBox(width: AppSpacing.xs),
              ] else if (icon != null) ...[
                Icon(icon, size: 18, color: AppChrome.accentGold),
                const SizedBox(width: AppSpacing.xs),
              ],
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
                  style: context.appButtons.primary.text,
                  child: Text(actionLabel!),
                )
              else if (trailing != null)
                trailing!,
            ],
          ),
          AppSpacing.gapSm,
          child,
        ],
      ),
    );
    final panel = AppCardFrame(
      gold: goldFrame,
      fill: backdrop == null ? AppChrome.panelFill : null,
      background: backdrop,
      child: content,
    );
    if (margin == null) return panel;
    return Padding(padding: margin!, child: panel);
  }
}

/// Centered empty / error / loading body on the chrome canvas.
class AppChromeCentered extends StatelessWidget {
  const AppChromeCentered({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppChrome.canvas,
      child: Center(
        child: Padding(padding: AppSpacing.screenPadding, child: child),
      ),
    );
  }
}
