import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';
import '../widgets/circle_crop_image.dart';

/// Arcori Detail SSOT — circle art + design fields.
/// Standings / My Mastery tabs: future (see arcori-standings-surface).
class ArcoriDetailScreen extends ConsumerStatefulWidget {
  const ArcoriDetailScreen({required this.internalId, super.key});

  final String internalId;

  @override
  ConsumerState<ArcoriDetailScreen> createState() => _ArcoriDetailScreenState();
}

class _ArcoriDetailScreenState extends ConsumerState<ArcoriDetailScreen> {
  static const double _artSize = 200;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(arcoriDetailProvider.notifier).load(widget.internalId);
    });
  }

  @override
  void didUpdateWidget(covariant ArcoriDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.internalId != widget.internalId) {
      ref.read(arcoriDetailProvider.notifier).load(widget.internalId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(arcoriDetailProvider);
    final design = detail.design;
    final title = design?.displayName ?? 'Arcori';

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: title, icon: Icons.auto_awesome_outlined),
      ],
      child: detail.isLoading
          ? const Center(child: CircularProgressIndicator())
          : detail.errorMessage != null && design == null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          detail.errorMessage!,
                          style: context.appTypography.body.copyWith(
                            color: context.appColors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        AppSpacing.gapMd,
                        FilledButton(
                          onPressed: () => ref
                              .read(arcoriDetailProvider.notifier)
                              .load(widget.internalId),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : design == null
                  ? Center(
                      child: Text(
                        'Design not found',
                        style: context.appTypography.body,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: SizedBox(
                              width: _artSize,
                              height: _artSize,
                              child: CircleCropImage(imageUrl: design.imageUrl),
                            ),
                          ),
                          AppSpacing.gapLg,
                          Text(
                            design.displayName,
                            style: context.appTypography.h3,
                            textAlign: TextAlign.center,
                          ),
                          AppSpacing.gapMd,
                          ..._detailRows(context, design),
                          // Future: Standings + My Mastery submenu
                        ],
                      ),
                    ),
    );
  }

  List<Widget> _detailRows(BuildContext context, DesignDetail design) {
    final seriesLabel =
        (design.seriesKey != null && design.seriesKey!.isNotEmpty)
            ? design.seriesKey
            : design.series;
    final rows = <MapEntry<String, String?>>[
      MapEntry('Theme', design.theme),
      MapEntry('Subtheme', design.subtheme),
      MapEntry('Series', seriesLabel),
      MapEntry('Rarity', design.printedRarity),
      MapEntry('Generation', design.generation?.display),
      MapEntry('World', design.worldState),
      MapEntry('Season', design.seasonState),
      MapEntry('Lore', design.loreDescription),
    ];

    final widgets = <Widget>[];
    for (final row in rows) {
      final value = row.value;
      if (value == null || value.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.key,
                style: context.appTypography.caption.copyWith(
                  color: context.appColorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.gapXxs,
              Text(value, style: context.appTypography.body),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}
