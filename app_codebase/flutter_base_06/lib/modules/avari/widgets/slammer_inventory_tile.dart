import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../avari_models.dart';

/// Owned slammer row — cylinder, name, mastery, and catalog gameplay attributes.
class SlammerInventoryTile extends StatelessWidget {
  const SlammerInventoryTile({
    required this.item,
    this.onTap,
    super.key,
  });

  final AvariInventoryItem item;
  final VoidCallback? onTap;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final scheme = context.appColorScheme;
    final attrs = item.gameplayAttributes;
    final radius = BorderRadius.circular(AppButtonMetrics.radius);
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: radius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArcoriCylinder(
              look: ArcoriLook(
                designId: item.designId,
                imageUrl: item.imageUrl,
                colorHex: item.color,
              ),
              size: _size,
            ),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: context.appTypography.subtitle,
                  ),
                  AppSpacing.gapXxs,
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      _AttrStat(
                        label: 'Mastery',
                        value: item.masteryOverMintReach,
                      ),
                      if (attrs != null)
                        for (final row in attrs.labeledValues)
                          _AttrStat(label: row.$1, value: '${row.$2}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return tile;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: tile,
      ),
    );
  }
}

class _AttrStat extends StatelessWidget {
  const _AttrStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: context.appTypography.caption.copyWith(
              color: context.appColorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: value,
            style: context.appTypography.body,
          ),
        ],
      ),
    );
  }
}
