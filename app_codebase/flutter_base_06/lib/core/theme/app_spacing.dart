import 'package:flutter/material.dart';

/// Shared layout spacing tokens for screens and widgets.
abstract final class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Default screen edge padding used across module screens.
  static const EdgeInsets screenPadding = EdgeInsets.all(lg);

  /// Compact screen edge padding for dense layouts.
  static const EdgeInsets screenPaddingCompact = EdgeInsets.all(md);

  static const SizedBox gapXxs = SizedBox(height: xxs, width: xxs);
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
}
