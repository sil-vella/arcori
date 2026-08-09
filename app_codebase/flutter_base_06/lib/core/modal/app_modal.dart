import 'package:flutter/material.dart';

import '../theme/app_modal_theme.dart';
import 'app_centered_modal.dart';
import 'app_fullscreen_modal.dart';

export 'app_centered_modal.dart';
export 'app_fullscreen_modal.dart';

/// Imperative modal API for overlays on top of the app shell.
///
/// Use [showCentered] for dialogs with a dimmed scrim. Use [showFullScreen] for
/// flows that occupy the entire viewport. Prefer this over raw [showDialog] so
/// scrim, motion, and dismiss behaviour stay consistent.
abstract final class AppModal {
  AppModal._();

  /// Shows a centered modal with dimmed barrier. Returns when dismissed.
  static Future<T?> showCentered<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) {
    final modalTheme = Theme.of(context).extension<AppModalThemeExtension>() ??
        AppModalThemeExtension.light;

    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: modalTheme.scrim,
      transitionDuration: AppModalMetrics.transitionDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return PopScope(
          canPop: barrierDismissible,
          child: builder(dialogContext),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppModalMetrics.transitionCurve,
          reverseCurve: AppModalMetrics.reverseTransitionCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: AppModalMetrics.centeredScaleBegin,
              end: 1,
            ).animate(curved),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppModalMetrics.borderRadius),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shows a full-screen modal overlay (not a go_router route).
  static Future<T?> showFullScreen<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = false,
    bool useRootNavigator = true,
  }) {
    final modalTheme = Theme.of(context).extension<AppModalThemeExtension>() ??
        AppModalThemeExtension.light;

    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: modalTheme.scrim,
      transitionDuration: AppModalMetrics.transitionDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return PopScope(
          canPop: barrierDismissible,
          child: builder(dialogContext),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppModalMetrics.transitionCurve,
          reverseCurve: AppModalMetrics.reverseTransitionCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: AppModalMetrics.fullScreenSlideBegin,
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Convenience: centered modal with standard [AppCenteredModal] shell.
  static Future<T?> showCenteredShell<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    List<Widget> actions = const [],
    bool showCloseButton = true,
    EdgeInsets? padding,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) {
    return showCentered<T>(
      context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (ctx) => AppCenteredModal(
        title: title,
        actions: actions,
        showCloseButton: showCloseButton,
        padding: padding,
        child: child,
      ),
    );
  }

  /// Convenience: full-screen modal with standard [AppFullScreenModal] shell.
  static Future<T?> showFullScreenShell<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    List<Widget> actions = const [],
    bool showCloseButton = true,
    EdgeInsets? padding,
    bool barrierDismissible = false,
    bool useRootNavigator = true,
  }) {
    return showFullScreen<T>(
      context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (ctx) => SizedBox.expand(
        child: AppFullScreenModal(
          title: title,
          actions: actions,
          showCloseButton: showCloseButton,
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  /// Dismisses the topmost modal route opened via [AppModal].
  ///
  /// No-ops when the root navigator cannot pop — avoids emptying go_router
  /// (black screen) if dismiss is invoked after the modal is already gone.
  static void dismiss<T>(BuildContext context, [T? result]) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (!nav.canPop()) return;
    nav.pop<T>(result);
  }
}
