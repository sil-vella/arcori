import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../avari_models.dart';

/// Owned slammer row — cylinder + name + catalog gameplay attributes.
class SlammerInventoryTile extends StatelessWidget {
  const SlammerInventoryTile({required this.item, super.key});

  final AvariInventoryItem item;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final scheme = context.appColorScheme;
    final attrs = item.gameplayAttributes;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
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
                  if (attrs != null && attrs.labeledValues.isNotEmpty) ...[
                    AppSpacing.gapXxs,
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        for (final row in attrs.labeledValues)
                          _AttrStat(label: row.$1, value: row.$2),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttrStat extends StatelessWidget {
  const _AttrStat({required this.label, required this.value});

  final String label;
  final int value;

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
            text: '$value',
            style: context.appTypography.body,
          ),
        ],
      ),
    );
  }
}
