import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../velora_chrome.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';

/// Arcori Detail — Details + Standings.
class ArcoriDetailScreen extends ConsumerStatefulWidget {
  const ArcoriDetailScreen({
    required this.internalId,
    this.openStandings = false,
    super.key,
  });

  final String internalId;

  /// Opens on the Standings tab (player circulating browse).
  final bool openStandings;

  @override
  ConsumerState<ArcoriDetailScreen> createState() => _ArcoriDetailScreenState();
}

enum _DetailTab { details, standings }

bool _isSlammer(DesignDetail design) {
  final type = (design.type ?? '').trim().toLowerCase();
  final theme = (design.theme ?? '').trim().toLowerCase();
  final code = (design.themeCode ?? '').trim().toUpperCase();
  return type == 'slammer' ||
      type == 'slm' ||
      theme == 'slammers' ||
      code == 'SLM';
}

class _SlammerHeroCover extends StatelessWidget {
  const _SlammerHeroCover();

  static const String _asset =
      'assets/images/backgrounds/individual_slammer.webp';

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => ColoredBox(color: AppChrome.fieldFill),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ink.withValues(alpha: 0.28),
                ink.withValues(alpha: 0.4),
                ink.withValues(alpha: 0.62),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArcoriDetailScreenState extends ConsumerState<ArcoriDetailScreen> {
  late _DetailTab _tab;
  bool _standingsRequested = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.openStandings ? _DetailTab.standings : _DetailTab.details;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(arcoriDetailProvider.notifier).load(widget.internalId);
      if (widget.openStandings) _loadStandings();
    });
  }

  @override
  void didUpdateWidget(covariant ArcoriDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.internalId != widget.internalId) {
      _standingsRequested = false;
      _tab = _DetailTab.details;
      ref.read(arcoriDetailProvider.notifier).load(widget.internalId);
    }
  }

  void _selectTab(_DetailTab tab) {
    setState(() => _tab = tab);
    if (tab == _DetailTab.standings) {
      _loadStandings();
    }
  }

  void _ensureStandings() {
    if (_standingsRequested) return;
    _standingsRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(arcoriStandingsProvider(widget.internalId).notifier)
          .load(force: true);
    });
  }

  void _loadStandings({bool force = false}) {
    final firstVisit = !_standingsRequested;
    _standingsRequested = true;
    ref
        .read(arcoriStandingsProvider(widget.internalId).notifier)
        .load(force: force || firstVisit);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(arcoriDetailProvider);
    final design = detail.design;
    final title = design?.displayName ?? 'Arcori';

    final summary = design == null
        ? null
        : DesignSummary(
            internalId: design.internalId,
            design: design.design,
            theme: design.theme,
            subtheme: design.subtheme,
            themeCode: design.themeCode,
            selectionWeight: design.selectionWeight,
            series: design.series,
            seriesKey: design.seriesKey,
            worldState: design.worldState,
            seasonState: design.seasonState,
            type: design.type,
            imageUrl: design.imageUrl,
            lottieUrl: design.lottieUrl,
            faceMedia: design.faceMedia,
            color: design.color,
            generation: design.generation,
            background: design.background,
          );

    final gen = design?.generation?.display;
    final seriesLabel =
        (design?.seriesKey != null && design!.seriesKey!.isNotEmpty)
            ? design.seriesKey
            : design?.series;
    final subtitle = [
      if ((gen ?? '').isNotEmpty) 'Gen $gen',
      if ((seriesLabel ?? '').isNotEmpty) seriesLabel,
    ].join(' · ');

    final slammer = design != null && _isSlammer(design);
    if (slammer) _ensureStandings();

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(
          text: title,
          iconAsset: slammer ? AppMarks.slammers : AppMarks.arcori,
        ),
      ],
      child: AppChromePage(
        child: detail.isLoading && design == null
            ? const AppChromeCentered(child: CircularProgressIndicator())
            : detail.errorMessage != null && design == null
                ? AppChromeCentered(
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
                          style: context.appButtons.primary.filled,
                          onPressed: () => ref
                              .read(arcoriDetailProvider.notifier)
                              .load(widget.internalId),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppChromePage.topClearance(context) + AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    children: [
                      if (design != null && slammer) ...[
                        _slammerHero(summary, subtitle),
                        AppSpacing.gapMd,
                        AppChromeSection(
                          title: 'Details',
                          mark: const AppMarkIcon(AppMarks.slammers),
                          goldFrame: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _detailRows(context, design),
                          ),
                        ),
                        AppSpacing.gapMd,
                        AppChromeSection(
                          title: 'Standings',
                          mark: const AppMarkIcon(AppMarks.slammers),
                          goldFrame: true,
                          child: _StandingsBody(internalId: widget.internalId),
                        ),
                      ] else if (design != null)
                        AppChromeSection(
                          title: 'Arcori',
                          mark: const AppMarkIcon(AppMarks.arcori),
                          goldFrame: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final disc = (constraints.maxWidth / 1.55)
                                      .clamp(120.0, 220.0);
                                  return VeloraFeaturedStage(
                                    design: summary,
                                    subtitle:
                                        subtitle.isEmpty ? null : subtitle,
                                    discSize: disc,
                                  );
                                },
                              ),
                              AppSpacing.gapMd,
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      style: _tab == _DetailTab.details
                                          ? context.appButtons.primary.filled
                                          : context.appButtons.primary.tonal,
                                      onPressed: () =>
                                          _selectTab(_DetailTab.details),
                                      child: const Text('Details'),
                                    ),
                                  ),
                                  AppSpacing.gapSm,
                                  Expanded(
                                    child: FilledButton(
                                      style: _tab == _DetailTab.standings
                                          ? context.appButtons.primary.filled
                                          : context.appButtons.primary.tonal,
                                      onPressed: () =>
                                          _selectTab(_DetailTab.standings),
                                      child: const Text('Standings'),
                                    ),
                                  ),
                                ],
                              ),
                              AppSpacing.gapMd,
                              if (_tab == _DetailTab.details)
                                ..._detailRows(context, design)
                              else
                                _StandingsBody(internalId: widget.internalId),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _slammerHero(DesignSummary? summary, String subtitle) {
    return AppChromeSection(
      title: 'Slammer',
      mark: const AppMarkIcon(AppMarks.slammers),
      goldFrame: true,
      background: const _SlammerHeroCover(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final disc = (constraints.maxWidth / 1.55).clamp(120.0, 220.0);
          return VeloraFeaturedStage(
            design: summary,
            subtitle: subtitle.isEmpty ? null : subtitle,
            discSize: disc,
          );
        },
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
      MapEntry('Selection weight', design.selectionWeight?.toString()),
      MapEntry('Generation', design.generation?.display),
      MapEntry('World', design.worldState),
      MapEntry('Season', design.seasonState),
      MapEntry(
        'Preservation requirement',
        design.legacy?.preservationRequirement?.toString(),
      ),
      MapEntry(
        'Closure milestone',
        design.legacy?.closureMilestone?.toString(),
      ),
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
                  color: AppChrome.accentGold,
                ),
              ),
              AppSpacing.gapXxs,
              Text(
                value,
                style: context.appTypography.body.copyWith(
                  color: AppChrome.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

class _StandingsBody extends ConsumerWidget {
  const _StandingsBody({required this.internalId});

  final String internalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(arcoriStandingsProvider(internalId));
    final muted = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurfaceMuted,
    );
    final body = context.appTypography.body.copyWith(
      color: AppChrome.onSurface,
    );
    final gold = context.appTypography.caption.copyWith(
      color: AppChrome.accentGold,
    );

    if (state.isLoading && state.standings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.standings == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.errorMessage!,
            style: context.appTypography.body.copyWith(
              color: context.appColors.red,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapMd,
          FilledButton(
            style: context.appButtons.primary.filled,
            onPressed: () => ref
                .read(arcoriStandingsProvider(internalId).notifier)
                .load(force: true),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final standings = state.standings;
    if (standings == null || standings.isEmpty) {
      return Text(
        'No standings yet for this generation',
        style: body,
        textAlign: TextAlign.center,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Generation fill', style: gold),
        AppSpacing.gapXxs,
        Text('${standings.fillCurrent} / ${standings.fillCap}', style: body),
        if (standings.leaderWindowEndsAt != null &&
            standings.leaderWindowEndsAt!.isNotEmpty) ...[
          AppSpacing.gapMd,
          Text('Leader window', style: gold),
          AppSpacing.gapXxs,
          Text(standings.leaderWindowEndsAt!, style: body),
        ],
        AppSpacing.gapLg,
        Text(
          'Ranks',
          style: context.appTypography.title.copyWith(
            color: AppChrome.onSurface,
          ),
        ),
        AppSpacing.gapSm,
        if (standings.ranks.isEmpty)
          Text('No ranks yet', style: muted)
        else
          for (final rank in standings.ranks)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: AppSpacing.xl,
                    child: Text('#${rank.rank}', style: body),
                  ),
                  Expanded(child: Text(rank.displayLabel, style: body)),
                  Text('${rank.masteryPoints}', style: muted),
                ],
              ),
            ),
      ],
    );
  }
}
