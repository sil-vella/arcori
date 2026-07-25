import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';
import '../widgets/circle_crop_image.dart';

/// Lazy-loaded circulating designs for one theme (series subsections).
class VeloraThemeScreen extends ConsumerStatefulWidget {
  const VeloraThemeScreen({
    required this.themeCode,
    this.themeName,
    super.key,
  });

  final String themeCode;
  final String? themeName;

  @override
  ConsumerState<VeloraThemeScreen> createState() => _VeloraThemeScreenState();
}

class _VeloraThemeScreenState extends ConsumerState<VeloraThemeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(veloraThemeBrowseProvider(widget.themeCode).notifier)
          .load(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant VeloraThemeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeCode != widget.themeCode) {
      ref
          .read(veloraThemeBrowseProvider(widget.themeCode).notifier)
          .load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final browse = ref.watch(veloraThemeBrowseProvider(widget.themeCode));
    final title = (widget.themeName != null && widget.themeName!.isNotEmpty)
        ? widget.themeName!
        : widget.themeCode;

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: title, icon: Icons.category_outlined),
      ],
      child: browse.isLoading && browse.seriesGroups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : browse.errorMessage != null && browse.seriesGroups.isEmpty
              ? Center(
                  child: Padding(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          browse.errorMessage!,
                          style: context.appTypography.body.copyWith(
                            color: context.appColors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        AppSpacing.gapMd,
                        FilledButton(
                          onPressed: () => ref
                              .read(
                                veloraThemeBrowseProvider(widget.themeCode)
                                    .notifier,
                              )
                              .load(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : browse.seriesGroups.isEmpty
                  ? Center(
                      child: Text(
                        'No circulating Arcori in this theme',
                        style: context.appTypography.body,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(
                            veloraThemeBrowseProvider(widget.themeCode)
                                .notifier,
                          )
                          .load(force: true),
                      child: ListView.builder(
                        padding: AppSpacing.screenPadding,
                        itemCount: browse.seriesGroups.length,
                        itemBuilder: (context, index) {
                          return _SeriesSection(
                            group: browse.seriesGroups[index],
                          );
                        },
                      ),
                    ),
    );
  }
}

class _SeriesSection extends StatelessWidget {
  const _SeriesSection({required this.group});

  final VeloraSeriesGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.seriesKey,
            style: context.appTypography.title.copyWith(
              color: context.appColorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapXs,
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.72,
            ),
            itemCount: group.designs.length,
            itemBuilder: (context, i) {
              final design = group.designs[i];
              return _DesignTile(
                design: design,
                onTap: () => Nav.push(
                  context,
                  '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(design.internalId)}',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DesignTile extends StatelessWidget {
  const _DesignTile({required this.design, required this.onTap});

  final DesignSummary design;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CircleCropImage(imageUrl: design.imageUrl),
          ),
          AppSpacing.gapXxs,
          Text(
            design.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.appTypography.caption,
          ),
        ],
      ),
    );
  }
}
