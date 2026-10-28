import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/screen.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../velora_assets.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';

/// Velora entry: series list (Creation → Civilizations).
class VeloraScreen extends ConsumerStatefulWidget {
  const VeloraScreen({super.key});

  @override
  ConsumerState<VeloraScreen> createState() => _VeloraScreenState();
}

class _VeloraScreenState extends ConsumerState<VeloraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(veloraProvider.notifier).loadSeries(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final velora = ref.watch(veloraProvider);
    final auth = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (!next.isBootstrapping &&
          next.isAuthenticated &&
          previous?.isAuthenticated != true) {
        ref.read(veloraProvider.notifier).loadSeries(force: true);
      }
    });

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Velora', iconAsset: AppMarks.velora),
      ],
      child: AppChromePage(
        child: !auth.isAuthenticated && !auth.isBootstrapping
            ? AppChromeCentered(
                child: Text(
                  'Sign in to browse Velora',
                  style: context.appTypography.body.copyWith(
                    color: AppChrome.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(veloraProvider.notifier).loadSeries(force: true),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppChromePage.topClearance(context) + AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  children: [
                    const _WorldCard(),
                    AppSpacing.gapMd,
                    if (velora.isLoading && velora.series.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (velora.errorMessage != null &&
                        velora.series.isEmpty)
                      Column(
                        children: [
                          Text(
                            velora.errorMessage!,
                            style: context.appTypography.body.copyWith(
                              color: context.appColors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          AppSpacing.gapMd,
                          FilledButton(
                            style: context.appButtons.primary.filled,
                            onPressed: () => ref
                                .read(veloraProvider.notifier)
                                .loadSeries(force: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    else ...[
                      _SeriesSection(
                        title: 'Arcori',
                        mark: const AppMarkIcon(AppMarks.arcori),
                        series: [
                          for (final series in velora.series)
                            if (!series.slammerSeries) series,
                        ],
                        empty: 'No Arcori series yet',
                      ),
                      AppSpacing.gapMd,
                      _SeriesSection(
                        title: 'Slammers',
                        mark: const AppMarkIcon(AppMarks.slammers),
                        series: [
                          for (final series in velora.series)
                            if (_isSlammerSeries(series)) series,
                        ],
                        empty: 'No Slammer series yet',
                        slammers: true,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _SeriesSection extends StatelessWidget {
  const _SeriesSection({
    required this.title,
    required this.mark,
    required this.series,
    required this.empty,
    this.slammers = false,
  });

  final String title;
  final Widget mark;
  final List<CatalogSeriesEntry> series;
  final String empty;
  final bool slammers;

  @override
  Widget build(BuildContext context) {
    return AppChromeSection(
      title: title,
      mark: mark,
      goldFrame: true,
      child: series.isEmpty
          ? Text(
              empty,
              style: context.appTypography.bodySmall.copyWith(
                color: AppChrome.onSurfaceMuted,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < series.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppChrome.panelBorder.withValues(alpha: 0.35),
                    ),
                  _SeriesRow(series: series[i], slammers: slammers),
                ],
              ],
            ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.series, this.slammers = false});

  final CatalogSeriesEntry series;
  final bool slammers;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final seriesId = series.seriesKey.trim().isNotEmpty
            ? series.seriesKey
            : series.key;
        if (slammers) {
          Nav.push(
            context,
            Uri(
              path: AppPaths.veloraTheme,
              queryParameters: {
                'code': 'SLM',
                'name': series.label,
                'series': seriesId,
                'seriesName': series.label,
              },
            ).toString(),
          );
          return;
        }
        Nav.push(
          context,
          Uri(
            path: AppPaths.veloraSeries,
            queryParameters: {'key': seriesId, 'name': series.label},
          ).toString(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                series.label,
                style: context.appTypography.title.copyWith(
                  color: AppChrome.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppChrome.accentGold),
          ],
        ),
      ),
    );
  }
}

bool _isSlammerSeries(CatalogSeriesEntry series) {
  if (series.slammerSeries) return true;
  final key = series.key.trim().toLowerCase();
  final seriesKey = series.seriesKey.trim().toLowerCase();
  return key == 'genesis' || seriesKey == 'genesis';
}

class _WorldCard extends StatelessWidget {
  const _WorldCard();

  @override
  Widget build(BuildContext context) {
    return AppChromeSection(
      title: 'The world',
      mark: const AppMarkIcon(AppMarks.velora),
      goldFrame: true,
      background: const _WorldMapCover(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.62,
              child: Text(
                'Five known lands, and what the Chronicle still cannot prove.',
                style: context.appTypography.bodySmall.copyWith(
                  color: AppChrome.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ),
          AppSpacing.gapSm,
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              style: context.appButtons.primary.filled,
              onPressed: () => Nav.push(context, AppPaths.veloraWorld),
              child: const Text('Learn the world'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldMapCover extends StatelessWidget {
  const _WorldMapCover();

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          kVeloraWorldBackgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => ColoredBox(color: AppChrome.fieldFill),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                ink.withValues(alpha: 0.94),
                ink.withValues(alpha: 0.72),
                ink.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.28, 0.5],
            ),
          ),
        ),
      ],
    );
  }
}
