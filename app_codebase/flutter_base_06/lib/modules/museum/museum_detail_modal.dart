import 'package:flutter/material.dart';

import '../../core/modal/app_modal.dart';
import '../../core/theme/theme.dart';
import '../avari/avari_models.dart';
import '../avari/widgets/inventory_face_chip.dart';
import 'museum_models.dart';

Future<void> showMuseumItemDetail(
  BuildContext context, {
  required MuseumItem item,
}) {
  return AppModal.showCentered(
    context,
    builder: (dialogContext) {
      return AppCenteredModal(
        title: item.displayName,
        child: _MuseumDetailBody(item: item),
      );
    },
  );
}

class _MuseumDetailBody extends StatelessWidget {
  const _MuseumDetailBody({required this.item});

  final MuseumItem item;

  @override
  Widget build(BuildContext context) {
    final inventory = AvariInventoryItem(
      designId: item.designId,
      displayName: item.displayName,
      imageUrl: item.imageUrl,
      color: item.color,
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: InventoryFaceChip(
              item: inventory,
              captionOverride: item.genCaption,
            ),
          ),
          AppSpacing.gapMd,
          Text(
            item.outcomeLabel,
            style: context.appTypography.subtitle,
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapSm,
          Text(
            item.historySummary.isNotEmpty
                ? item.historySummary
                : 'No write history recorded.',
            style: context.appTypography.body,
            textAlign: TextAlign.center,
          ),
          if ((item.closedAt ?? '').isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(
              'Closed ${item.closedAt}',
              style: context.appTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
          if ((item.actorDisplayName ?? '').isNotEmpty) ...[
            AppSpacing.gapXs,
            Text(
              item.isPreserved
                  ? 'Legacy owner & generation ${item.generationNumber + 1} echoer: ${item.actorDisplayName}'
                  : 'Master: ${item.actorDisplayName}',
              style: context.appTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
