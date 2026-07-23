import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Imperative navigation for screens and shell. Avoids [BuildContext] extension
/// name clashes with go_router. [GoRouter] is the single source of truth for
/// location and back-stack depth.
abstract final class Nav {
  /// Active route location, including imperative [GoRouter.push] entries.
  static String matchedLocation(BuildContext context) =>
      GoRouter.of(context).routerDelegate.state.matchedLocation;

  static void push(BuildContext context, String location, {Object? extra}) {
    GoRouter.of(context).push(location, extra: extra);
  }

  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    final router = GoRouter.of(context);
    if (!router.canPop()) {
      return;
    }
    router.pop<T>(result);
  }

  static bool canPop(BuildContext context) => GoRouter.of(context).canPop();

  static void go(BuildContext context, String location, {Object? extra}) {
    GoRouter.of(context).go(location, extra: extra);
  }

  static void pushFromDrawer(
    BuildContext context,
    String location, {
    Object? extra,
    ScaffoldState? scaffold,
  }) {
    scaffold?.closeDrawer();
    final current = _normalizePath(matchedLocation(context));
    if (current != _normalizePath(location)) {
      push(context, location, extra: extra);
    }
  }

  static String _normalizePath(String path) => path.isEmpty ? '/' : path;
}
