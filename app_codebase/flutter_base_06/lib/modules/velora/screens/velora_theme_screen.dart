import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../../market/slammer_market_action.dart';
import '../velora_chrome.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';

/// Circulating designs for one theme inside a series.
class VeloraThemeScreen extends ConsumerStatefulWidget {
  const VeloraThemeScreen({
    required this.themeCode,
    required this.seriesKey,
    this.themeName,
    this.seriesName,
    super.key,
  });

  final String themeCode;
  final String seriesKey;
  final String? themeName;
  final String? seriesName;

  @override
  ConsumerState<VeloraThemeScreen> createState() => _VeloraThemeScreenState();
}

class _VeloraThemeScreenState extends ConsumerState<VeloraThemeScreen> {
  VeloraThemeBrowseArgs get _args => VeloraThemeBrowseArgs(
    seriesKey: widget.seriesKey,
    themeCode: widget.themeCode,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(veloraProvider.notifier).loadSeries();
      ref.read(veloraThemeBrowseProvider(_args).notifier).load(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant VeloraThemeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeCode != widget.themeCode ||
        oldWidget.seriesKey != widget.seriesKey) {
      ref.read(veloraThemeBrowseProvider(_args).notifier).load(force: true);
    }
  }

  bool _onScroll(ScrollNotification n) {
    final browse = ref.read(veloraThemeBrowseProvider(_args));
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120 &&
        browse.hasMore &&
        !browse.isLoadingMore &&
        !browse.isLoading) {
      ref.read(veloraThemeBrowseProvider(_args).notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final browse = ref.watch(veloraThemeBrowseProvider(_args));
    final title = (widget.themeName != null && widget.themeName!.isNotEmpty)
        ? widget.themeName!
        : widget.themeCode;
    final muted = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurfaceMuted,
    );

    String? lore;
    for (final theme in ref.watch(veloraProvider).themes) {
      if (theme.themeCode == widget.themeCode) {
        final text = theme.loreDescription?.trim();
        if (text != null && text.isNotEmpty) lore = text;
        break;
      }
    }

    final featured = browse.featured;
    final gen = featured?.generation?.display;
    final seriesLabel =
        (widget.seriesName != null && widget.seriesName!.trim().isNotEmpty)
        ? widget.seriesName!.trim()
        : widget.seriesKey.trim();
    final isSlammer = widget.themeCode.trim().toUpperCase() == 'SLM';
    final screenTitle = isSlammer && seriesLabel.isNotEmpty
        ? seriesLabel
        : title;
    final seriesCardTitle = isSlammer && seriesLabel.isNotEmpty
        ? seriesLabel
        : 'Arcori';
    final subtitle = [
      if ((gen ?? '').isNotEmpty) 'Gen $gen',
      if (seriesLabel.isNotEmpty) seriesLabel,
    ].join(' · ');

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(
          text: screenTitle,
          icon: isSlammer ? null : Icons.category_outlined,
          iconAsset: isSlammer ? AppMarks.slammers : null,
        ),
      ],
      child: AppChromePage(
        child: browse.isLoading && browse.designs.isEmpty
            ? const AppChromeCentered(child: CircularProgressIndicator())
            : browse.errorMessage != null && browse.designs.isEmpty
            ? AppChromeCentered(
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
                      style: context.appButtons.primary.filled,
                      onPressed: () => ref
                          .read(veloraThemeBrowseProvider(_args).notifier)
                          .load(force: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(veloraThemeBrowseProvider(_args).notifier)
                      .load(force: true),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppChromePage.topClearance(context) + AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppChromeSection(
                          title: 'Featured',
                          mark: AppMarkIcon(
                            isSlammer ? AppMarks.slammers : AppMarks.arcori,
                          ),
                          goldFrame: true,
                          child: Column(
                            children: [
                              VeloraFeaturedStage(
                                design: featured,
                                subtitle: subtitle.isEmpty ? null : subtitle,
                                footer: !isSlammer || featured == null
                                    ? null
                                    : SlammerMarketAction(
                                        designId: featured.internalId,
                                      ),
                                onTap: featured == null
                                    ? null
                                    : () => Nav.push(
                                        context,
                                        '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(featured.internalId)}',
                                      ),
                              ),
                              if (lore != null) ...[
                                AppSpacing.gapSm,
                                Text(lore, style: muted),
                              ],
                            ],
                          ),
                        ),
                      ),
                      AppChromeSection(
                        title: seriesCardTitle,
                        goldFrame: true,
                        child: browse.designs.isEmpty
                            ? Text(
                                isSlammer
                                    ? 'No slammers in this series'
                                    : 'No circulating Arcori in this theme',
                                style: muted,
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: isSlammer ? 2 : 3,
                                      mainAxisSpacing: AppSpacing.sm,
                                      crossAxisSpacing: AppSpacing.sm,
                                      childAspectRatio: isSlammer ? 0.5 : 0.72,
                                    ),
                                itemCount: browse.designs.length,
                                itemBuilder: (context, i) {
                                  final design = browse.designs[i];
                                  return _DesignTile(
                                    design: design,
                                    showMarket: isSlammer,
                                    onTap: () => Nav.push(
                                      context,
                                      '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(design.internalId)}',
                                    ),
                                  );
                                },
                              ),
                      ),
                      if (browse.isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.md),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _DesignTile extends StatelessWidget {
  const _DesignTile({
    required this.design,
    required this.onTap,
    this.showMarket = false,
  });

  final DesignSummary design;
  final VoidCallback onTap;
  final bool showMarket;

  @override
  Widget build(BuildContext context) {
    final gold = AppChrome.accentGold;
    final radius = BorderRadius.circular(AppRadii.md);
    final gen = design.generation?.display;
    final seriesLabel =
        (design.seriesKey != null && design.seriesKey!.trim().isNotEmpty)
        ? design.seriesKey!.trim()
        : (design.series ?? '').trim();
    final lineage = [
      if ((gen ?? '').isNotEmpty) 'Gen $gen',
      if (seriesLabel.isNotEmpty) seriesLabel,
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 4, AppSpacing.xs, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final box = constraints.biggest.shortestSide;
                          final size =
                              (box / (1 + kArcoriThicknessFactor * 0.55)).clamp(
                                1.0,
                                box,
                              );
                          return Center(
                            child: ArcoriCylinder(
                              look: ArcoriLook(
                                designId: design.internalId,
                                imageUrl: design.hasLottieFace
                                    ? null
                                    : design.imageUrl,
                                colorHex: design.color,
                              ),
                              size: size,
                              face: design.hasLottieFace
                                  ? KinSceneStack(
                                      lottieUrl: design.lottieUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      design.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.appTypography.caption.copyWith(
                        color: AppChrome.onSurface,
                      ),
                    ),
                    if (showMarket && lineage.isNotEmpty)
                      Text(
                        lineage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.appTypography.caption.copyWith(
                          color: gold,
                        ),
                      ),
                    if ((design.worldState ?? '').toLowerCase() == 'closed')
                      Text(
                        'Closed',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: context.appTypography.caption.copyWith(
                          color: gold.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (showMarket) SlammerMarketAction(designId: design.internalId),
          ],
        ),
      ),
    );
  }
}
