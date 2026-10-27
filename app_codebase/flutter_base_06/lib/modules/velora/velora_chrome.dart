import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../kin/widgets/kin_lottie_preview.dart';
import '../match/widgets/arcori_cylinder.dart';
import '../match/widgets/arcori_look.dart';
import 'velora_assets.dart';
import 'velora_models.dart';

/// Featured disc stage with glow + pedestal.
class VeloraFeaturedStage extends StatefulWidget {
  const VeloraFeaturedStage({
    super.key,
    required this.design,
    this.onTap,
    this.subtitle,
    this.discSize = 140,
  });

  final DesignSummary? design;
  final VoidCallback? onTap;
  final String? subtitle;

  /// Disc diameter. Arcori Detail uses 280 (2× default).
  final double discSize;

  @override
  State<VeloraFeaturedStage> createState() => _VeloraFeaturedStageState();
}

class _VeloraFeaturedStageState extends State<VeloraFeaturedStage>
    with SingleTickerProviderStateMixin {
  static const Duration _cycle = Duration(milliseconds: 4800);
  static const double _bouncePx = 7;
  static const double _swivelRad = 0.32;

  double get _discSize => widget.discSize;

  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: _cycle)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featured = widget.design;
    if (featured == null) {
      return Center(
        child: Text(
          'No featured Arcori',
          style: context.appTypography.bodyMuted.copyWith(
            color: AppChrome.onSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final disc = AnimatedBuilder(
      animation: _idle,
      child: SizedBox(
        width: _discSize,
        height: _discSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -_discSize * 0.275,
              top: -_discSize * 0.275,
              width: _discSize * 1.55,
              height: _discSize * 1.55,
              child: IgnorePointer(
                child: Lottie.asset(
                  kVeloraFeaturedGlowLottie,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ),
            ArcoriCylinder(
              look: ArcoriLook(
                designId: featured.internalId,
                imageUrl:
                    featured.hasLottieFace ? null : featured.imageUrl,
                colorHex: featured.color,
              ),
              size: _discSize,
              face: featured.hasLottieFace
                  ? KinSceneStack(
                      lottieUrl: featured.lottieUrl,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ],
        ),
      ),
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_idle.value);
        final bounceY = (0.5 - t) * 2 * _bouncePx;
        final swivel = (t - 0.5) * 2 * _swivelRad;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(swivel)
            ..translate(0.0, bounceY),
          child: child,
        );
      },
    );

    final stage = SizedBox(
      width: _discSize * 1.55,
      height: _discSize * 0.95 + 58,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: _discSize * 0.92,
            left: 0,
            right: 0,
            child: Image.asset(
              kVeloraPedestalAsset,
              height: 58,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          disc,
        ],
      ),
    );

    final body = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        stage,
        AppSpacing.gapSm,
        Text(
          featured.displayName,
          style: context.appTypography.h3.copyWith(
            color: AppChrome.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
          AppSpacing.gapXxs,
          Text(
            widget.subtitle!.trim(),
            style: context.appTypography.caption.copyWith(
              color: AppChrome.accentGold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    if (widget.onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: body,
      ),
    );
  }
}
