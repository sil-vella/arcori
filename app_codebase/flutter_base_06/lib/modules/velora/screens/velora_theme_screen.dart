import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_visuals.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../velora_assets.dart';
import '../velora_chrome.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';

/// Circulating designs for one theme inside a series + featured banner.
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

  @override
  Widget build(BuildContext context) {
    final browse = ref.watch(veloraThemeBrowseProvider(_args));
    final title = (widget.themeName != null && widget.themeName!.isNotEmpty)
        ? widget.themeName!
        : widget.themeCode;
    final bg = veloraContentCanvas();

    String? lore;
    for (final theme in ref.watch(veloraProvider).themes) {
      if (theme.themeCode == widget.themeCode) {
        final text = theme.loreDescription?.trim();
        if (text != null && text.isNotEmpty) {
          lore = text;
        }
        break;
      }
    }

    final featured = browse.featured;
    final gen = featured?.generation?.display;
    final seriesLabel = (widget.seriesName != null &&
            widget.seriesName!.trim().isNotEmpty)
        ? widget.seriesName!.trim()
        : widget.seriesKey.trim();
    final subtitle = [
      if ((gen ?? '').isNotEmpty) 'Gen $gen',
      if (seriesLabel.isNotEmpty) seriesLabel,
    ].join(' · ');

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: title, icon: Icons.category_outlined),
      ],
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(veloraThemeBrowseProvider(_args).notifier).load(force: true),
        child: AppScreenTemplate001(
          backgroundAsset: kVeloraWorldBackgroundAsset,
          scrimOpacity: 0,
          appBarForeground: Colors.white,
          banner: Stack(
            fit: StackFit.expand,
            children: [
              veloraBannerFade(),
              VeloraFeaturedStage(
                design: featured,
                subtitle: subtitle.isEmpty ? null : subtitle,
                onTap: featured == null
                    ? null
                    : () => Nav.push(
                          context,
                          '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(featured.internalId)}',
                        ),
              ),
            ],
          ),
          slivers: [
            if (browse.isLoading && browse.designs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: bg,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              )
            else if (browse.errorMessage != null && browse.designs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: bg,
                  child: Center(
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
                                .read(veloraThemeBrowseProvider(_args).notifier)
                                .load(force: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (browse.designs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: bg,
                  child: const AppEmptyState(
                    message: 'No circulating Arcori in this theme',
                    icon: Icons.category_outlined,
                  ),
                ),
              )
            else ...[
              if (lore != null)
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: bg,
                    child: Padding(
                      padding: AppSpacing.screenPaddingCompact,
                      child: Text(
                        lore,
                        style: context.appTypography.bodyMuted.copyWith(
                          color: AppColors.onSurfaceMutedDark,
                        ),
                      ),
                    ),
                  ),
                ),
              DecoratedSliver(
                decoration: BoxDecoration(color: bg),
                sliver: SliverPadding(
                  padding: AppSpacing.screenPaddingCompact,
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final design = browse.designs[i];
                        return _DesignTile(
                          design: design,
                          onTap: () => Nav.push(
                            context,
                            '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(design.internalId)}',
                          ),
                        );
                      },
                      childCount: browse.designs.length,
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(color: bg),
              ),
            ],
          ],
        ),
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
    final gold = AppSurfaces.frameGold(Brightness.dark);
    final radius = BorderRadius.circular(AppRadii.md);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: gold.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                4,
                AppSpacing.xs,
                6,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final box = constraints.biggest.shortestSide;
                        final size =
                            (box / (1 + kArcoriThicknessFactor * 0.55))
                                .clamp(1.0, box);
                        return Center(
                          child: ArcoriCylinder(
                            look: ArcoriLook(
                              designId: design.internalId,
                              imageUrl: design.imageUrl,
                              colorHex: design.color,
                            ),
                            size: size,
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
                      color: AppColors.onSurfaceDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
