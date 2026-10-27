import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

/// Shared button layout metrics.
abstract final class AppButtonMetrics {
  AppButtonMetrics._();

  /// Gold ritual CTA — slightly softer than Material 8.
  static const double radius = AppRadii.md;
  static const double borderWidth = 1;

  static const double iconSizeSmall = 16;
  static const double iconSize = 18;
  static const double iconSizeLarge = 20;

  static const EdgeInsets paddingSmall =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const EdgeInsets paddingMedium =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets paddingLarge =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  static const double minWidthSmall = 48;
  static const double minHeightSmall = 36;
  static const double minWidthMedium = 64;
  static const double minHeightMedium = 44;
  static const double minWidthLarge = 72;
  static const double minHeightLarge = 52;

  static const double iconButtonSizeSmall = 36;
  static const double iconButtonSize = 44;
  static const double iconButtonSizeLarge = 52;
}

/// Brand and semantic button tone identifiers.
enum AppButtonTone {
  primary,
  secondary,
  tertiary,
  accent,
  success,
  error,
  warning,
  info,
}

/// The four standard button variants for each tone.
@immutable
class AppToneButtonStyles {
  const AppToneButtonStyles({
    required this.filled,
    required this.tonal,
    required this.outlined,
    required this.text,
    required this.icon,
  });

  final ButtonStyle filled;
  final ButtonStyle tonal;
  final ButtonStyle outlined;
  final ButtonStyle text;
  final ButtonStyle icon;
}

/// Complete button style set for a brightness (brand + semantic tones).
@immutable
class AppButtonStyles {
  const AppButtonStyles({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.accent,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.buttonText,
    required this.buttonTextSmall,
    required this.buttonTextLarge,
  });

  final AppToneButtonStyles primary;
  final AppToneButtonStyles secondary;
  final AppToneButtonStyles tertiary;
  final AppToneButtonStyles accent;
  final AppToneButtonStyles success;
  final AppToneButtonStyles error;
  final AppToneButtonStyles warning;
  final AppToneButtonStyles info;
  final TextStyle buttonText;
  final TextStyle buttonTextSmall;
  final TextStyle buttonTextLarge;

  static final AppButtonStyles light = _build(Brightness.light);
  static final AppButtonStyles dark = _build(Brightness.dark);

  static AppButtonStyles forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  AppToneButtonStyles tone(AppButtonTone tone) => switch (tone) {
        AppButtonTone.primary => primary,
        AppButtonTone.secondary => secondary,
        AppButtonTone.tertiary => tertiary,
        AppButtonTone.accent => accent,
        AppButtonTone.success => success,
        AppButtonTone.error => error,
        AppButtonTone.warning => warning,
        AppButtonTone.info => info,
      };

  /// Compact variant of any [ButtonStyle].
  ButtonStyle small(ButtonStyle style) => _resize(style, _Size.small);

  /// Expanded variant of any [ButtonStyle].
  ButtonStyle large(ButtonStyle style) => _resize(style, _Size.large);

  ButtonStyle _resize(ButtonStyle style, _Size size) {
    final (padding, minW, minH, text) = switch (size) {
      _Size.small => (
          AppButtonMetrics.paddingSmall,
          AppButtonMetrics.minWidthSmall,
          AppButtonMetrics.minHeightSmall,
          buttonTextSmall,
        ),
      _Size.large => (
          AppButtonMetrics.paddingLarge,
          AppButtonMetrics.minWidthLarge,
          AppButtonMetrics.minHeightLarge,
          buttonTextLarge,
        ),
      _Size.medium => throw StateError('medium is the default size'),
    };
    return style.copyWith(
      padding: WidgetStateProperty.all(padding),
      minimumSize: WidgetStateProperty.all(Size(minW, minH)),
      textStyle: WidgetStateProperty.all(text),
    );
  }

  static AppButtonStyles _build(Brightness brightness) {
    final typography = AppTypography.forBrightness(brightness);
    final muted = brightness == Brightness.dark
        ? AppColors.onSurfaceMutedDark
        : AppColors.onSurfaceMuted;

    return AppButtonStyles(
      buttonText: typography.button,
      buttonTextSmall: typography.button.copyWith(fontSize: AppFontSizes.bodySmall),
      buttonTextLarge: typography.button.copyWith(fontSize: AppFontSizes.bodyLarge),
      // Primary CTA = gold (Play / claim). Purple lives on secondary for tonal chrome.
      primary: _tone(
        textStyle: typography.button,
        filledBg: AppColors.secondary,
        filledFg: AppColors.onSecondary,
        tonalBg: AppColors.secondaryPastel,
        tonalFg: AppColors.onSecondary,
        outlinedFg: AppColors.secondary,
        outlinedBorder: AppColors.secondary,
        textFg: AppColors.secondary,
        iconFg: AppColors.secondary,
        disabledFg: muted,
        // Inward corner bends on all four sides — cross-shaped gold CTA.
        inwardCorners: true,
        filledGradient: <Color>[
          Color.lerp(AppColors.secondary, AppColors.tertiary, 0.45)!,
          AppColors.secondary,
          Color.lerp(AppColors.secondary, AppColors.headingGold, 0.35)!,
          AppColors.secondary,
          Color.lerp(AppColors.secondary, AppColors.tertiary, 0.45)!,
        ],
      ),
      secondary: _tone(
        textStyle: typography.button,
        filledBg: AppColors.primary,
        filledFg: AppColors.onPrimary,
        tonalBg: AppColors.primaryPastel,
        tonalFg: AppColors.onPrimaryContainer,
        outlinedFg: AppColors.primary,
        outlinedBorder: AppColors.primary,
        textFg: AppColors.primary,
        iconFg: AppColors.primary,
        disabledFg: muted,
      ),
      tertiary: _tone(
        textStyle: typography.button,
        filledBg: AppColors.tertiary,
        filledFg: AppColors.onTertiary,
        tonalBg: AppColors.tertiaryPastel,
        tonalFg: AppColors.onTertiary,
        outlinedFg: AppColors.tertiary,
        outlinedBorder: AppColors.tertiary,
        textFg: AppColors.tertiary,
        iconFg: AppColors.tertiary,
        disabledFg: muted,
      ),
      accent: _tone(
        textStyle: typography.button,
        filledBg: AppColors.accent,
        filledFg: AppColors.onAccent,
        tonalBg: AppColors.accentPastel,
        tonalFg: AppColors.onAccent,
        outlinedFg: AppColors.accent,
        outlinedBorder: AppColors.accent,
        textFg: AppColors.accent,
        iconFg: AppColors.accent,
        disabledFg: muted,
      ),
      success: _tone(
        textStyle: typography.button,
        filledBg: AppColors.green,
        filledFg: AppColors.onGreen,
        tonalBg: AppColors.greenPastel,
        tonalFg: AppColors.onGreen,
        outlinedFg: AppColors.green,
        outlinedBorder: AppColors.green,
        textFg: AppColors.green,
        iconFg: AppColors.green,
        disabledFg: muted,
      ),
      error: _tone(
        textStyle: typography.button,
        filledBg: AppColors.red,
        filledFg: AppColors.onRed,
        tonalBg: AppColors.redPastel,
        tonalFg: AppColors.onRed,
        outlinedFg: AppColors.red,
        outlinedBorder: AppColors.red,
        textFg: AppColors.red,
        iconFg: AppColors.red,
        disabledFg: muted,
      ),
      warning: _tone(
        textStyle: typography.button,
        filledBg: AppColors.amber,
        filledFg: AppColors.onAmber,
        tonalBg: AppColors.amberPastel,
        tonalFg: AppColors.onAmber,
        outlinedFg: AppColors.amber,
        outlinedBorder: AppColors.amber,
        textFg: AppColors.amber,
        iconFg: AppColors.amber,
        disabledFg: muted,
      ),
      info: _tone(
        textStyle: typography.button,
        filledBg: AppColors.blue,
        filledFg: AppColors.onBlue,
        tonalBg: AppColors.bluePastel,
        tonalFg: AppColors.onBlue,
        outlinedFg: AppColors.blue,
        outlinedBorder: AppColors.blue,
        textFg: AppColors.blue,
        iconFg: AppColors.blue,
        disabledFg: muted,
      ),
    );
  }

  static AppToneButtonStyles _tone({
    required TextStyle textStyle,
    required Color filledBg,
    required Color filledFg,
    required Color tonalBg,
    required Color tonalFg,
    required Color outlinedFg,
    required Color outlinedBorder,
    required Color textFg,
    required Color iconFg,
    required Color disabledFg,
    double? filledRadius,
    BorderSide? filledSide,
    List<Color>? filledGradient,
    bool inwardCorners = false,
  }) {
    return AppToneButtonStyles(
      filled: _filled(
        background: filledBg,
        foreground: filledFg,
        textStyle: textStyle,
        disabledFg: disabledFg,
        radius: filledRadius,
        side: filledSide,
        gradient: filledGradient,
        inwardCorners: inwardCorners,
      ),
      tonal: _filled(
        background: tonalBg,
        foreground: tonalFg,
        textStyle: textStyle,
        disabledFg: disabledFg,
      ),
      outlined: _outlined(
        foreground: outlinedFg,
        border: outlinedBorder,
        textStyle: textStyle,
        disabledFg: disabledFg,
      ),
      text: _text(
        foreground: textFg,
        textStyle: textStyle,
        disabledFg: disabledFg,
      ),
      icon: _icon(
        foreground: iconFg,
        disabledFg: disabledFg,
      ),
    );
  }

  static ButtonStyle _base({
    required TextStyle textStyle,
    EdgeInsets padding = AppButtonMetrics.paddingMedium,
    double minWidth = AppButtonMetrics.minWidthMedium,
    double minHeight = AppButtonMetrics.minHeightMedium,
  }) {
    return ButtonStyle(
      textStyle: WidgetStateProperty.all(textStyle),
      padding: WidgetStateProperty.all(padding),
      minimumSize: WidgetStateProperty.all(Size(minWidth, minHeight)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
        ),
      ),
    );
  }

  static ButtonStyle _filled({
    required Color background,
    required Color foreground,
    required TextStyle textStyle,
    required Color disabledFg,
    double? radius,
    BorderSide? side,
    List<Color>? gradient,
    bool inwardCorners = false,
  }) {
    final corner = radius ?? AppButtonMetrics.radius;
    return _base(textStyle: textStyle).copyWith(
      shape: WidgetStateProperty.resolveWith((states) {
        if (inwardCorners) {
          final disabled = states.contains(WidgetState.disabled);
          return InwardCornerBorder(
            side: BorderSide(
              color: AppColors.surface.withValues(alpha: disabled ? 0.35 : 1),
              width: 1,
            ),
          );
        }
        final border = side == null
            ? BorderSide.none
            : states.contains(WidgetState.disabled)
                ? BorderSide(
                    color: side.color.withValues(alpha: 0.38),
                    width: side.width,
                  )
                : side;
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corner),
          side: border,
        );
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (gradient != null) return Colors.transparent;
        if (states.contains(WidgetState.disabled)) {
          return background.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.pressed)) {
          return Color.alphaBlend(
            foreground.withValues(alpha: 0.08),
            background,
          );
        }
        if (states.contains(WidgetState.hovered)) {
          return Color.alphaBlend(
            foreground.withValues(alpha: 0.04),
            background,
          );
        }
        return background;
      }),
      backgroundBuilder: gradient == null
          ? null
          : (context, states, child) {
              final disabled = states.contains(WidgetState.disabled);
              final pressed = states.contains(WidgetState.pressed);
              final colors = <Color>[
                for (final color in gradient)
                  disabled
                      ? color.withValues(alpha: 0.28)
                      : pressed
                          ? Color.alphaBlend(
                              foreground.withValues(alpha: 0.08),
                              color,
                            )
                          : color,
              ];
              return ClipPath(
                clipper: const ShapeBorderClipper(
                  shape: InwardCornerBorder(),
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: colors,
                            stops: const [0.0, 0.32, 0.5, 0.68, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.9,
                            colors: [
                              AppColors.surface.withValues(
                                alpha: disabled ? 0.05 : 0.32,
                              ),
                              AppColors.surface.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: 2.5,
                            colors: [
                              AppColors.surface.withValues(
                                alpha: disabled ? 0.1 : 0.78,
                              ),
                              AppColors.surface.withValues(
                                alpha: disabled ? 0.03 : 0.22,
                              ),
                              AppColors.surface.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.48, 1.0],
                          ),
                        ),
                      ),
                    ),
                    ?child,
                  ],
                ),
              );
            },
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledFg;
        return foreground;
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (inwardCorners) return 0;
        if (states.contains(WidgetState.pressed)) return 1;
        return 0;
      }),
      shadowColor: inwardCorners
          ? const WidgetStatePropertyAll(Colors.transparent)
          : null,
    );
  }

  static ButtonStyle _outlined({
    required Color foreground,
    required Color border,
    required TextStyle textStyle,
    required Color disabledFg,
  }) {
    return _base(textStyle: textStyle).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledFg;
        return foreground;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.disabled)
            ? disabledFg.withValues(alpha: 0.38)
            : border;
        return BorderSide(
          color: color,
          width: AppButtonMetrics.borderWidth,
        );
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) {
          return foreground.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return foreground.withValues(alpha: 0.06);
        }
        return Colors.transparent;
      }),
    );
  }

  static ButtonStyle _text({
    required Color foreground,
    required TextStyle textStyle,
    required Color disabledFg,
  }) {
    return _base(
      textStyle: textStyle,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minWidth: AppButtonMetrics.minWidthSmall,
      minHeight: AppButtonMetrics.minHeightSmall,
    ).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledFg;
        return foreground;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foreground.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return foreground.withValues(alpha: 0.06);
        }
        return Colors.transparent;
      }),
    );
  }

  static ButtonStyle _icon({
    required Color foreground,
    required Color disabledFg,
  }) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(
          AppButtonMetrics.iconButtonSize,
          AppButtonMetrics.iconButtonSize,
        ),
      ),
      padding: WidgetStateProperty.all(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledFg;
        return foreground;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foreground.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return foreground.withValues(alpha: 0.06);
        }
        return Colors.transparent;
      }),
      iconSize: const WidgetStatePropertyAll(AppButtonMetrics.iconSize),
    );
  }
}

enum _Size { small, medium, large }

/// Button styles registered on [ThemeData.extensions].
@immutable
class AppButtonStylesExtension extends ThemeExtension<AppButtonStylesExtension> {
  const AppButtonStylesExtension(this.styles);

  final AppButtonStyles styles;

  static final light = AppButtonStylesExtension(AppButtonStyles.light);
  static final dark = AppButtonStylesExtension(AppButtonStyles.dark);

  AppToneButtonStyles get primary => styles.primary;
  AppToneButtonStyles get secondary => styles.secondary;
  AppToneButtonStyles get tertiary => styles.tertiary;
  AppToneButtonStyles get accent => styles.accent;
  AppToneButtonStyles get success => styles.success;
  AppToneButtonStyles get error => styles.error;
  AppToneButtonStyles get warning => styles.warning;
  AppToneButtonStyles get info => styles.info;

  AppToneButtonStyles tone(AppButtonTone tone) => styles.tone(tone);

  ButtonStyle small(ButtonStyle style) => styles.small(style);
  ButtonStyle large(ButtonStyle style) => styles.large(style);

  @override
  AppButtonStylesExtension copyWith({AppButtonStyles? styles}) {
    return AppButtonStylesExtension(styles ?? this.styles);
  }

  @override
  AppButtonStylesExtension lerp(
    covariant AppButtonStylesExtension? other,
    double t,
  ) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Rectangle with a circular bite at each corner. The outside of each inward bend is empty.
class InwardCornerBorder extends OutlinedBorder {
  const InwardCornerBorder({super.side});

  /// Share of the short side used by each inward corner.
  static const double _cornerShare = 0.115;

  /// Gold left outside the shine-colored line.
  static const double _edgeGap = 1.25;

  @override
  OutlinedBorder copyWith({BorderSide? side}) {
    return InwardCornerBorder(side: side ?? this.side);
  }

  @override
  ShapeBorder scale(double t) {
    return InwardCornerBorder(side: side.scale(t));
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is InwardCornerBorder) {
      return InwardCornerBorder(side: BorderSide.lerp(a.side, side, t));
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is InwardCornerBorder) {
      return InwardCornerBorder(side: BorderSide.lerp(side, b.side, t));
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _outline(rect);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _outline(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final face = _outline(rect);
    final line = _outline(rect, inset: _edgeGap + side.width / 2);
    canvas.save();
    canvas.clipPath(face);
    canvas.drawPath(
      line,
      Paint()
        ..color = side.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool operator ==(Object other) {
    return other is InwardCornerBorder && other.side == side;
  }

  @override
  int get hashCode => Object.hash(runtimeType, side);

  static double _radius(Rect rect) {
    final shortest = rect.width < rect.height ? rect.width : rect.height;
    return shortest * _cornerShare;
  }

  /// Gold face, optionally inset by [inset] so the border can sit on it.
  ///
  /// Arc centers stay on the original corners. [inset] moves the straight
  /// edges inward and uses a smaller radius on the same centers.
  static Path _outline(Rect rect, {double inset = 0}) {
    final outerRadius = _radius(rect);
    final radius = outerRadius - inset;
    if (radius <= 0) {
      return Path()..addRect(rect.deflate(inset));
    }
    if (inset <= 0) {
      final left = rect.left;
      final top = rect.top;
      final right = rect.right;
      final bottom = rect.bottom;
      return Path()
        ..moveTo(left + outerRadius, top)
        ..lineTo(right - outerRadius, top)
        ..arcTo(
          Rect.fromCircle(center: rect.topRight, radius: outerRadius),
          math.pi,
          -math.pi / 2,
          false,
        )
        ..lineTo(right, bottom - outerRadius)
        ..arcTo(
          Rect.fromCircle(center: rect.bottomRight, radius: outerRadius),
          -math.pi / 2,
          -math.pi / 2,
          false,
        )
        ..lineTo(left + outerRadius, bottom)
        ..arcTo(
          Rect.fromCircle(center: rect.bottomLeft, radius: outerRadius),
          0,
          -math.pi / 2,
          false,
        )
        ..lineTo(left, top + outerRadius)
        ..arcTo(
          Rect.fromCircle(center: rect.topLeft, radius: outerRadius),
          math.pi / 2,
          -math.pi / 2,
          false,
        )
        ..close();
    }

    final join = math.sqrt(radius * radius - inset * inset);
    final top = rect.top + inset;
    final bottom = rect.bottom - inset;
    final left = rect.left + inset;
    final right = rect.right - inset;

    final trStart = math.atan2(inset, -join);
    final trSweep = _clockwiseSweep(trStart, math.atan2(join, -inset));
    final brStart = math.atan2(-join, -inset);
    final brSweep = _clockwiseSweep(brStart, math.atan2(-inset, -join));
    final blStart = math.atan2(-inset, join);
    final blSweep = _clockwiseSweep(blStart, math.atan2(-join, inset));
    final tlStart = math.atan2(join, inset);
    final tlSweep = _clockwiseSweep(tlStart, math.atan2(inset, join));

    return Path()
      ..moveTo(rect.left + join, top)
      ..lineTo(rect.right - join, top)
      ..arcTo(
        Rect.fromCircle(center: rect.topRight, radius: radius),
        trStart,
        trSweep,
        false,
      )
      ..lineTo(right, rect.bottom - join)
      ..arcTo(
        Rect.fromCircle(center: rect.bottomRight, radius: radius),
        brStart,
        brSweep,
        false,
      )
      ..lineTo(rect.left + join, bottom)
      ..arcTo(
        Rect.fromCircle(center: rect.bottomLeft, radius: radius),
        blStart,
        blSweep,
        false,
      )
      ..lineTo(left, rect.top + join)
      ..arcTo(
        Rect.fromCircle(center: rect.topLeft, radius: radius),
        tlStart,
        tlSweep,
        false,
      )
      ..close();
  }

  static double _clockwiseSweep(double start, double end) {
    var sweep = end - start;
    if (sweep > 0) sweep -= math.pi * 2;
    if (sweep < -math.pi) sweep += math.pi * 2;
    return sweep;
  }
}
