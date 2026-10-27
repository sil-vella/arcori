import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';

/// Themes circulating inside one series.
class VeloraSeriesScreen extends ConsumerStatefulWidget {
  const VeloraSeriesScreen({
    required this.seriesKey,
    this.seriesName,
    this.slammersOnly = false,
    super.key,
  });

  final String seriesKey;
  final String? seriesName;

  /// Slammers series: only the Slammers theme. Arcori series omit it.
  final bool slammersOnly;

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
    final themes = [
      for (final theme in browse.themes)
        if (widget.slammersOnly
            ? _isSlammerTheme(theme)
            : !_isSlammerTheme(theme))
          theme,
    ];
    final seriesLabel =
        (widget.seriesName != null && widget.seriesName!.isNotEmpty)
            ? widget.seriesName!
            : widget.seriesKey;
    final title =
        widget.slammersOnly ? '$seriesLabel Slammers' : seriesLabel;
    final muted = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurfaceMuted,
    );

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: title, icon: Icons.auto_stories_outlined),
      ],
      child: AppChromePage(
        child: browse.isLoading && browse.themes.isEmpty
            ? const AppChromeCentered(child: CircularProgressIndicator())
            : browse.errorMessage != null && browse.themes.isEmpty
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
                              .read(
                                veloraSeriesBrowseProvider(widget.seriesKey)
                                    .notifier,
                              )
                              .load(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(
                          veloraSeriesBrowseProvider(widget.seriesKey).notifier,
                        )
                        .load(force: true),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppChromePage.topClearance(context) + AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      children: [
                        AppChromeSection(
                          title: widget.slammersOnly ? 'Slammers' : 'Themes',
                          icon: Icons.category_outlined,
                          goldFrame: true,
                          child: themes.isEmpty
                              ? Text(
                                  widget.slammersOnly
                                      ? 'No slammers in this series'
                                      : 'No circulating themes in this series',
                                  style: muted,
                                )
                              : Column(
                                  children: [
                                    for (var i = 0; i < themes.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          color: AppChrome.panelBorder
                                              .withValues(alpha: 0.35),
                                        ),
                                      _ThemeRow(
                                        theme: themes[i],
                                        seriesKey: widget.seriesKey,
                                        seriesName: widget.seriesName,
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.theme,
    required this.seriesKey,
    this.seriesName,
  });

  final VeloraThemeInSeries theme;
  final String seriesKey;
  final String? seriesName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Nav.push(
          context,
          Uri(
            path: AppPaths.veloraTheme,
            queryParameters: {
              'code': theme.themeCode,
              'name': theme.label,
              'series': seriesKey,
              if ((seriesName ?? '').isNotEmpty) 'seriesName': seriesName!,
            },
          ).toString(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                theme.label,
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

bool _isSlammerTheme(VeloraThemeInSeries theme) {
  return theme.themeCode.trim().toUpperCase() == 'SLM' ||
      theme.theme.trim().toLowerCase() == 'slammers';
}
