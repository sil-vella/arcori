import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../shell_chrome_registrar.dart';

/// Layout metrics for [AppScreenTemplate001] (top banner / hero gap).
abstract final class AppScreenTemplate001Metrics {
  AppScreenTemplate001Metrics._();

  /// Fraction of the viewport below the AppBar for the banner slot.
  static const double contentStartFraction = 0.4;

  /// Soft canvas scrim over the page mural so foreground chrome stays readable.
  static const double scrimOpacity = 0.42;
}

/// Template **001 — top banner**.
///
/// Full-bleed page mural under a transparent AppBar. A leading **banner slot**
/// (default 40% of the area below the AppBar) scrolls away with [slivers].
/// Fill the slot with [banner] (image, disc, copy, etc.) or leave empty.
///
/// Use inside [ModuleScreenRegistrar] (or [AppBarRegistrar]).
///
/// Registers [ShellChromeRegistrar.extendBodyBehindAppBar] so the shell
/// paints the body under the AppBar.
class AppScreenTemplate001 extends StatelessWidget {
  const AppScreenTemplate001({
    required this.slivers,
    this.banner,
    this.background,
    this.backgroundAsset,
    this.contentStartFraction = AppScreenTemplate001Metrics.contentStartFraction,
    this.scrimOpacity = AppScreenTemplate001Metrics.scrimOpacity,
    this.extendBodyBehindAppBar = true,
    this.appBarForeground,
    this.alignment = Alignment.center,
    this.controller,
    this.physics,
    super.key,
  }) : assert(
          background != null ||
              backgroundAsset != null ||
              banner != null,
          'Provide background, backgroundAsset, and/or banner',
        );

  /// Prefer [AssetImage] / [NetworkImage] for the page mural (behind content).
  final ImageProvider? background;

  /// Convenience when the mural is a bundled asset path.
  final String? backgroundAsset;

  /// Content for the top banner slot (fixed height = [contentStartFraction]).
  /// Scrolls away with [slivers]. May be an image, disc hero, text, etc.
  final Widget? banner;

  /// 0–1: banner slot height as a fraction of the area below the AppBar.
  final double contentStartFraction;

  /// 0–1 canvas tint over the mural (`0` = none).
  final double scrimOpacity;

  /// When true, asks [AppShell] to extend the body under the AppBar.
  final bool extendBodyBehindAppBar;

  /// Optional AppBar tint (title, back, menu) over the mural.
  final Color? appBarForeground;

  final AlignmentGeometry alignment;

  /// Content slivers after the banner slot (filters, lists, etc.).
  final List<Widget> slivers;

  final ScrollController? controller;
  final ScrollPhysics? physics;

  ImageProvider? get _image {
    if (background != null) return background;
    if (backgroundAsset != null) return AssetImage(backgroundAsset!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mural = _image;
    final body = Stack(
      fit: StackFit.expand,
      children: [
        if (mural != null)
          Positioned.fill(
            child: Image(
              image: mural,
              fit: BoxFit.cover,
              alignment: alignment,
              gaplessPlayback: true,
            ),
          ),
        if (mural != null && scrimOpacity > 0)
          Positioned.fill(
            child: ColoredBox(
              color: context.appSurfaces.canvas.withValues(alpha: scrimOpacity),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bannerHeight =
                  constraints.maxHeight * contentStartFraction.clamp(0.0, 1.0);
              return CustomScrollView(
                controller: controller,
                physics: physics,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: bannerHeight,
                      width: double.infinity,
                      child: banner,
                    ),
                  ),
                  ...slivers,
                ],
              );
            },
          ),
        ),
      ],
    );

    if (!extendBodyBehindAppBar) return body;

    return ShellChromeRegistrar(
      extendBodyBehindAppBar: true,
      appBarForeground: appBarForeground,
      child: body,
    );
  }
}
