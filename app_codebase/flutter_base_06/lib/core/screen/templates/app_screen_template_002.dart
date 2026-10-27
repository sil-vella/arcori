import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Layout metrics for [AppScreenTemplate002] (match play).
abstract final class AppScreenTemplate002Metrics {
  AppScreenTemplate002Metrics._();

  /// Soft canvas scrim over the arena mural so player chrome stays readable.
  static const double scrimOpacity = 0.28;

  /// Max width for the centered playfield (stack + aim).
  static const double playfieldMaxWidth = 360;

  /// Fixed playfield height (aim + stack hit area).
  static const double playfieldHeight = 280;

  /// Horizontal inset for left/right opponent slots.
  static const double sideInset = 12;

  /// Vertical inset for self / top opponent slots.
  static const double edgeInset = 12;

  /// Two-opponent vertical fraction from top (0 = top, 1 = bottom).
  static const double sideOpponentTopFraction = 0.25;
}

/// Template **002 — match play**.
///
/// Full-bleed arena mural with spatial player chrome:
/// - [self] always bottom-center
/// - one opponent → top-center
/// - two opponents → left + right at **25%** from top
///
/// [center] is the playfield hit-slot (aim overlay + lock). Stack visuals may
/// live in an [arenaLayer] behind (Arena POV), same as pre-refactor.
///
/// [overlay] must not steal playfield hits — wrap non-interactive chrome in
/// [IgnorePointer]; only interactive controls (e.g. End match) should hit-test.
///
/// Used inside the match fullscreen modal (no [ShellChromeRegistrar]).
class AppScreenTemplate002 extends StatelessWidget {
  const AppScreenTemplate002({
    required this.self,
    required this.center,
    this.opponents = const [],
    this.arenaLayer,
    this.background,
    this.backgroundAsset,
    this.backgroundNetworkUrl,
    this.scrimOpacity = AppScreenTemplate002Metrics.scrimOpacity,
    this.alignment = Alignment.center,
    this.overlay,
    this.stackAreaKey,
    super.key,
  }) : assert(
         opponents.length <= 2,
         'Template 002 supports at most 2 opponents',
       );

  /// Local player chrome (bottom-center).
  final Widget self;

  /// Opponent chrome widgets in seat order (0–2).
  final List<Widget> opponents;

  /// Stack / slam playfield hit-slot (centered). Aim overlay lives here.
  final Widget center;

  /// Optional full-bleed arena + stack camera (e.g. [ArenaPovBackdrop]).
  /// Painted under chrome; when set, [background*] are ignored.
  final Widget? arenaLayer;

  /// Prefer [AssetImage] / [NetworkImage] when [arenaLayer] is null.
  final ImageProvider? background;

  /// Convenience when the mural is a bundled asset path.
  final String? backgroundAsset;

  /// Convenience when the mural is a resolved network/media URL.
  final String? backgroundNetworkUrl;

  /// 0–1 canvas tint over the mural (`0` = none). Ignored when [arenaLayer] set.
  final double scrimOpacity;

  final AlignmentGeometry alignment;

  /// Thin chrome above the layout (hints, End match).
  final Widget? overlay;

  /// Optional key on the playfield slot (Arena POV stack alignment).
  final Key? stackAreaKey;

  ImageProvider? get _image {
    if (background != null) return background;
    if (backgroundAsset != null) return AssetImage(backgroundAsset!);
    final url = backgroundNetworkUrl?.trim() ?? '';
    if (url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mural = _image;
    final safe = MediaQuery.paddingOf(context);
    final opp = opponents;
    final useArenaLayer = arenaLayer != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Arena / table camera (or flat cover mural)
        if (useArenaLayer)
          Positioned.fill(child: arenaLayer!)
        else ...[
          if (mural != null)
            Positioned.fill(
              child: Image(
                image: mural,
                fit: BoxFit.cover,
                alignment: alignment,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: context.appSurfaces.canvas),
              ),
            )
          else
            Positioned.fill(
              child: ColoredBox(color: context.appSurfaces.canvas),
            ),
          if (mural != null && scrimOpacity > 0)
            Positioned.fill(
              child: ColoredBox(
                color: context.appSurfaces.canvas.withValues(
                  alpha: scrimOpacity,
                ),
              ),
            ),
        ],
        // 2) Player chrome — ignore pointers so they never block aim
        if (opp.length == 1)
          Positioned(
            top: safe.top + AppScreenTemplate002Metrics.edgeInset,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: opp[0])),
          )
        else if (opp.length >= 2) ...[
          Positioned(
            left: safe.left + AppScreenTemplate002Metrics.sideInset,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Align(
                alignment: const Alignment(
                  -1,
                  // -1 top … 1 bottom; 25% from top → -0.5
                  -1 + 2 * AppScreenTemplate002Metrics.sideOpponentTopFraction,
                ),
                child: opp[0],
              ),
            ),
          ),
          Positioned(
            right: safe.right + AppScreenTemplate002Metrics.sideInset,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Align(
                alignment: const Alignment(
                  1,
                  -1 + 2 * AppScreenTemplate002Metrics.sideOpponentTopFraction,
                ),
                child: opp[1],
              ),
            ),
          ),
        ],
        Positioned(
          left: 0,
          right: 0,
          bottom: safe.bottom + AppScreenTemplate002Metrics.edgeInset,
          child: IgnorePointer(child: Center(child: self)),
        ),
        // 3) Dark-to-light frame under status and Exit so those stay opaque.
        const Positioned.fill(
          child: IgnorePointer(child: _MatchEdgeGradient()),
        ),
        // 4) Hints / Exit under the playfield so aim/swipe still win in the slot
        if (overlay != null) Positioned.fill(child: overlay!),
        // 5) Center playfield hit-slot ON TOP (aim + lock + swipe)
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: SizedBox(
                key: stackAreaKey,
                width: double.infinity,
                height: AppScreenTemplate002Metrics.playfieldHeight,
                child: center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dark at the screen edge, clear toward the table.
class _MatchEdgeGradient extends StatelessWidget {
  const _MatchEdgeGradient();

  @override
  Widget build(BuildContext context) {
    final edge = AppColors.backgroundDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.92,
          colors: [
            edge.withValues(alpha: 0),
            edge.withValues(alpha: 0.18),
            edge.withValues(alpha: 0.82),
          ],
          stops: const [0.46, 0.74, 1],
        ),
      ),
    );
  }
}
