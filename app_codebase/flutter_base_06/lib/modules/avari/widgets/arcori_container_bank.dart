import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../avari_models.dart';

/// Circulating Arcori as sealed containers. One container holds [perContainer].
///
/// The mark is the closed container artwork. The last one shows how far the
/// next container is toward full.
class ArcoriContainerBank extends StatelessWidget {
  const ArcoriContainerBank({required this.count, super.key});

  final int count;

  static const int perContainer = 100;

  static const String asset = 'assets/images/container_closed.webp';

  /// Designs at 0 mastery have left the pool and do not fill a container.
  static int countTowardContainers(Iterable<AvariInventoryItem> access) {
    var total = 0;
    for (final item in access) {
      if (item.masteryPoints > 0) total++;
    }
    return total;
  }

  int get fullContainers => count <= 0 ? 0 : count ~/ perContainer;

  int get towardFull => count <= 0 ? 0 : count % perContainer;

  @override
  Widget build(BuildContext context) {
    final slots = fullContainers + 1;
    return SizedBox(
      height: ArcoriCanisterMark.slotHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots,
        separatorBuilder: (_, __) => AppSpacing.gapSm,
        itemBuilder: (context, index) {
          final filling = index == fullContainers;
          return ArcoriCanisterMark(
            key: ValueKey(
              filling ? 'arcori-container-progress' : 'arcori-container-$index',
            ),
            showProgress: filling,
            filled: filling ? towardFull : perContainer,
          );
        },
      ),
    );
  }
}

/// Closed canister artwork plus the progress bar on the one still filling.
class ArcoriCanisterMark extends StatelessWidget {
  const ArcoriCanisterMark({
    required this.showProgress,
    required this.filled,
    this.artWidth = profileArtWidth,
    this.tapLabel,
    this.onTap,
    super.key,
  });

  /// Profile card size. Circulating uses a larger [artWidth].
  static const double profileArtWidth = 36;

  /// Wide enough for the "n / 100" line under the profile-size canister.
  static const double _progressWidth = 64;
  static const double _barHeight = 6;

  static const double slotHeight = profileArtWidth * 1163 / 540 +
      AppSpacing.xs +
      _barHeight +
      AppSpacing.xxs +
      16;

  final bool showProgress;
  final int filled;
  final double artWidth;
  final String? tapLabel;
  final VoidCallback? onTap;

  double get _artHeight => artWidth * 1163 / 540;

  double get _columnWidth {
    final base = showProgress
        ? (artWidth < _progressWidth ? _progressWidth : artWidth)
        : artWidth;
    if (tapLabel == null) return base;
    return base < 92 ? 92 : base;
  }

  @override
  Widget build(BuildContext context) {
    final fraction =
        (filled / ArcoriContainerBank.perContainer).clamp(0.0, 1.0);
    final mark = SizedBox(
      width: _columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ClosedContainer(width: artWidth, height: _artHeight),
          if (showProgress) ...[
            AppSpacing.gapXs,
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: SizedBox(
                height: _barHeight,
                width: _columnWidth,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppChrome.accentGold.withValues(alpha: 0.28),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fraction,
                      child: ColoredBox(color: AppChrome.accentGold),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.gapXxs,
            SizedBox(
              height: 16,
              child: Text(
                '$filled / ${ArcoriContainerBank.perContainer}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.appTypography.caption.copyWith(
                  color: AppChrome.accentGold,
                  height: 1,
                ),
              ),
            ),
          ],
          if (tapLabel != null) ...[
            AppSpacing.gapXxs,
            Text(
              tapLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.appTypography.caption.copyWith(
                color: AppChrome.accentGold,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return mark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Ink(
          decoration: BoxDecoration(
            color: AppChrome.accentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: AppChrome.accentGold.withValues(alpha: 0.85),
              width: 1.25,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: mark,
          ),
        ),
      ),
    );
  }
}

class _ClosedContainer extends StatelessWidget {
  const _ClosedContainer({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      ArcoriContainerBank.asset,
      width: width,
      height: height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: AppChrome.fieldFill,
        child: SizedBox(width: width, height: height),
      ),
    );
  }
}
