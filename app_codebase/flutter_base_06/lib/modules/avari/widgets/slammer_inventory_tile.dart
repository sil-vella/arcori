import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../../velora/velora_assets.dart';
import '../avari_models.dart';

const String _kMasteryValueBackground =
    'assets/images/backgrounds/mastery.webp';

/// One owned slammer: details on the left, disc in the center, attributes on the right.
class SlammerInventoryTile extends StatelessWidget {
  const SlammerInventoryTile({
    required this.item,
    this.detail,
    this.onTap,
    this.onCharge,
    super.key,
  });

  final AvariInventoryItem item;

  /// Short line above the name (section blurb on the profile card).
  final String? detail;
  final VoidCallback? onTap;

  /// Top up a shop slammer. Permanent slammers hide the button.
  final VoidCallback? onCharge;

  static const double discSize = 96;

  /// Previous ring, reduced by a quarter. Painted behind the row.
  static const double medallionSize = discSize * 5 / 2 * 3 / 4;

  /// Same glow stage as the featured Arcori / slammer display (1.55× the disc).
  static const double _glowScale = 1.55;

  static const double pageHeight = 228;

  @override
  Widget build(BuildContext context) {
    final tile = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        OverflowBox(
          minWidth: medallionSize,
          maxWidth: medallionSize,
          minHeight: medallionSize,
          maxHeight: medallionSize,
          alignment: Alignment.center,
          child: Opacity(
            opacity: 0.4,
            child: Image.asset(
              _kMasteryValueBackground,
              width: medallionSize,
              height: medallionSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
        IgnorePointer(
          child: SizedBox(
            width: discSize * _glowScale,
            height: discSize * _glowScale,
            child: Lottie.asset(
              kVeloraFeaturedGlowLottie,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _SlammerDetails(
                item: item,
                detail: detail,
                onCharge: onCharge,
              ),
            ),
            SizedBox(
              width: discSize,
              height: discSize,
              child: ArcoriCylinder(
                look: ArcoriLook(
                  designId: item.designId,
                  imageUrl: item.imageUrl,
                  colorHex: item.color,
                ),
                size: discSize,
              ),
            ),
            Expanded(child: _SlammerAttributes(item: item)),
          ],
        ),
      ],
    );
    if (onTap == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: tile,
    );
  }
}

class _SlammerDetails extends StatelessWidget {
  const _SlammerDetails({required this.item, this.detail, this.onCharge});

  final AvariInventoryItem item;
  final String? detail;
  final VoidCallback? onCharge;

  @override
  Widget build(BuildContext context) {
    final blurb = (detail ?? '').trim();
    final reach = item.masteryCap ?? item.mintReach;
    final fraction = reach == null || reach <= 0
        ? 0.0
        : (item.masteryPoints / reach).clamp(0.0, 1.0);
    final muted = context.appTypography.caption.copyWith(
      color: AppChrome.onSurfaceMuted,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blurb.isNotEmpty) ...[
          Text(
            blurb,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
          AppSpacing.gapXs,
        ],
        Text(
          item.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.appTypography.h3.copyWith(color: AppChrome.accentGold),
        ),
        AppSpacing.gapXs,
        Text('Mastery', style: muted),
        Text(
          item.masteryOverMintReach,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.appTypography.h2.copyWith(
            color: AppChrome.accentGold,
            height: 1,
          ),
        ),
        if (reach != null) ...[
          AppSpacing.gapXxs,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: SizedBox(
              height: 6,
              width: double.infinity,
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
        ],
        AppSpacing.gapXs,
        Text(
          item.permanent == true
              ? 'Permanent'
              : '${item.chargesRemaining ?? 0} uses',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.appTypography.bodySmall.copyWith(
            color: AppChrome.accentGold,
          ),
        ),
        if (item.permanent != true && onCharge != null) ...[
          AppSpacing.gapXxs,
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              style: context.appButtons.small(
                context.appButtons.primary.filled,
              ),
              onPressed: onCharge,
              child: const Text('Charge'),
            ),
          ),
        ],
      ],
    );
  }
}

class _SlammerAttributes extends StatelessWidget {
  const _SlammerAttributes({required this.item});

  final AvariInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final rows = item.gameplayAttributes?.labeledValues ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    final labelStyle = context.appTypography.caption.copyWith(
      color: AppChrome.onSurfaceMuted,
    );
    final valueStyle = context.appTypography.bodySmall.copyWith(
      color: AppChrome.accentGold,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: ColoredBox(
                color: AppChrome.accentGold.withValues(alpha: 0.35),
                child: const SizedBox(height: 1, width: double.infinity),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  rows[i].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: labelStyle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('${rows[i].$2}', style: valueStyle),
            ],
          ),
        ],
      ],
    );
  }
}
