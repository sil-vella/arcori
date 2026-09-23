import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_visuals.dart';
import '../velora_assets.dart';
import '../velora_chrome.dart';
import '../velora_notifier.dart';

/// Themes circulating inside one series.
class VeloraSeriesScreen extends ConsumerStatefulWidget {
  const VeloraSeriesScreen({
    required this.seriesKey,
    this.seriesName,
    super.key,
  });

  final String seriesKey;
  final String? seriesName;

  @override
  ConsumerState<VeloraSeriesScreen> createState() => _VeloraSeriesScreenState();
}

class _VeloraSeriesScreenState extends ConsumerState<VeloraSeriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(veloraSeriesBrowseProvider(widget.seriesKey).notifier)
          .load(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant VeloraSeriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesKey != widget.seriesKey) {
      ref
          .read(veloraSeriesBrowseProvider(widget.seriesKey).notifier)
          .load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final browse = ref.watch(veloraSeriesBrowseProvider(widget.seriesKey));
    final title = (widget.seriesName != null && widget.seriesName!.isNotEmpty)
        ? widget.seriesName!
        : widget.seriesKey;
    final bg = veloraContentCanvas();

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: title, icon: Icons.auto_stories_outlined),
      ],
      child: RefreshIndicator(
        onRefresh: () => ref
            .read(veloraSeriesBrowseProvider(widget.seriesKey).notifier)
            .load(force: true),
        child: AppScreenTemplate001(
          backgroundAsset: kVeloraWorldBackgroundAsset,
          scrimOpacity: 0,
          appBarForeground: Colors.white,
          banner: Stack(
            fit: StackFit.expand,
            children: [veloraBannerFade()],
          ),
          slivers: [
            if (browse.isLoading && browse.themes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: bg,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              )
            else if (browse.errorMessage != null && browse.themes.isEmpty)
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
                                .read(
                                  veloraSeriesBrowseProvider(widget.seriesKey)
                                      .notifier,
                                )
                                .load(force: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (browse.themes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: bg,
                  child: const AppEmptyState(
                    message: 'No circulating themes in this series',
                    icon: Icons.category_outlined,
                  ),
                ),
              )
            else ...[
              DecoratedSliver(
                decoration: BoxDecoration(color: bg),
                sliver: SliverPadding(
                  padding: AppSpacing.screenPaddingCompact,
                  sliver: SliverList.separated(
                    itemCount: browse.themes.length,
                    separatorBuilder: (_, __) => AppSpacing.gapSm,
                    itemBuilder: (context, index) {
                      final theme = browse.themes[index];
                      return VeloraChromeButton(
                        label: theme.label,
                        textStyle: context.appTypography.title.copyWith(
                          color: AppColors.onSurfaceDark,
                        ),
                        onTap: () {
                          final q = {
                            'code': theme.themeCode,
                            'name': theme.label,
                            'series': widget.seriesKey,
                            if ((widget.seriesName ?? '').isNotEmpty)
                              'seriesName': widget.seriesName!,
                          };
                          Nav.push(
                            context,
                            Uri(
                              path: AppPaths.veloraTheme,
                              queryParameters: q,
                            ).toString(),
                          );
                        },
                      );
                    },
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
