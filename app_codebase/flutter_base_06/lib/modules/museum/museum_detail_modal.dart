import 'package:flutter/material.dart';

import '../../core/modal/app_modal.dart';
import '../../core/theme/theme.dart';
import '../match/widgets/arcori_cylinder.dart';
import '../match/widgets/arcori_look.dart';
import 'museum_models.dart';

Future<void> showMuseumItemDetail(
  BuildContext context, {
  required MuseumItem item,
}) {
  return AppModal.showCentered(
    context,
    builder: (dialogContext) => _MuseumDetailModal(item: item),
  );
}

/// Dark reliquary shell for a single Museum piece.
class _MuseumDetailModal extends StatelessWidget {
  const _MuseumDetailModal({required this.item});

  final MuseumItem item;

  static const _brightness = Brightness.dark;
  static const double _discSize = 120;

  @override
  Widget build(BuildContext context) {
    final gold = AppSurfaces.frameGold(_brightness);
    final bronze = AppSurfaces.frameBronze(_brightness);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Material(
      color: AppColors.surfaceDark,
      elevation: AppModalMetrics.elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: gold.withValues(alpha: 0.75), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppModalMetrics.centeredMaxWidth,
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.displayName,
                      style: context.appTypography.title.copyWith(
                        color: gold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => dismissModalRoute(context),
                    color: AppColors.onSurfaceMutedDark,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: bronze.withValues(alpha: 0.45)),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: AppSpacing.modalPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ArcoriCylinder(
                        look: ArcoriLook(
                          designId: item.designId,
                          imageUrl: item.imageUrl,
                          colorHex: item.color,
                        ),
                        size: _discSize,
                      ),
                    ),
                    AppSpacing.gapMd,
                    Text(
                      item.genCaption,
                      style: context.appTypography.subtitle.copyWith(
                        color: gold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapSm,
                    Text(
                      item.historySummary.isNotEmpty
                          ? item.historySummary
                          : 'No write history recorded.',
                      style: context.appTypography.body.copyWith(
                        color: AppColors.onSurfaceDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if ((item.closedAt ?? '').isNotEmpty) ...[
                      AppSpacing.gapMd,
                      _MetaRow(
                        label: 'Closed',
                        value: item.closedAt!,
                        bronze: bronze,
                      ),
                    ],
                    if ((item.actorDisplayName ?? '').isNotEmpty) ...[
                      AppSpacing.gapSm,
                      _MetaRow(
                        label: item.isPreserved ? 'Legacy Owner' : 'Master',
                        value: item.actorDisplayName!,
                        bronze: bronze,
                        emphasize: true,
                        gold: gold,
                      ),
                      if (item.isPreserved) ...[
                        AppSpacing.gapXs,
                        Text(
                          'Generation ${item.generationNumber + 1} echoer',
                          style: context.appTypography.caption.copyWith(
                            color: AppColors.onSurfaceMutedDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                    if ((item.designId).isNotEmpty) ...[
                      AppSpacing.gapMd,
                      Text(
                        item.designId,
                        style: context.appTypography.caption.copyWith(
                          color: AppColors.onSurfaceMutedDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    required this.bronze,
    this.emphasize = false,
    this.gold,
  });

  final String label;
  final String value;
  final Color bronze;
  final bool emphasize;
  final Color? gold;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: bronze.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: context.appTypography.caption.copyWith(
                color: emphasize
                    ? (gold ?? AppSurfaces.frameGold(Brightness.dark))
                    : AppColors.onSurfaceMutedDark,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapXxs,
            Text(
              value,
              style: context.appTypography.subtitle.copyWith(
                color: emphasize
                    ? (gold ?? AppSurfaces.frameGold(Brightness.dark))
                    : AppColors.onSurfaceDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
