import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/screen.dart';
import '../../../core/theme/theme.dart';
import '../velora_assets.dart';
import '../velora_chrome.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';

/// Arcori Detail — Details + Standings (Museum / Velora chrome).
class ArcoriDetailScreen extends ConsumerStatefulWidget {
  const ArcoriDetailScreen({required this.internalId, super.key});

  final String internalId;

  @override
  ConsumerState<ArcoriDetailScreen> createState() => _ArcoriDetailScreenState();
}

enum _DetailTab { details, standings }

class _ArcoriDetailScreenState extends ConsumerState<ArcoriDetailScreen> {
  _DetailTab _tab = _DetailTab.details;
  bool _standingsRequested = false;

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
    final bg = veloraContentCanvas();

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
            color: design.color,
            generation: design.generation,
          );

    final gen = design?.generation?.display;
    final seriesLabel = (design?.seriesKey != null &&
            design!.seriesKey!.isNotEmpty)
        ? design.seriesKey
        : design?.series;
    final subtitle = [
      if ((gen ?? '').isNotEmpty) 'Gen $gen',
      if ((seriesLabel ?? '').isNotEmpty) seriesLabel,
    ].join(' · ');

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: title, icon: Icons.auto_awesome_outlined),
      ],
      child: AppScreenTemplate001(
        backgroundAsset: kVeloraWorldBackgroundAsset,
        scrimOpacity: 0,
        appBarForeground: Colors.white,
        banner: Stack(
          fit: StackFit.expand,
          children: [
            veloraBannerFade(),
            if (detail.isLoading && design == null)
              const Center(child: CircularProgressIndicator())
            else if (design != null)
              VeloraFeaturedStage(
                design: summary,
                subtitle: subtitle.isEmpty ? null : subtitle,
              )
            else
              Center(
                child: Text(
                  detail.errorMessage ?? 'Design not found',
                  style: context.appTypography.bodyMuted.copyWith(
                    color: AppColors.onSurfaceMutedDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        slivers: [
          if (detail.errorMessage != null && design == null)
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
                ),
              ),
            )
          else if (design != null) ...[
            SliverToBoxAdapter(
              child: ColoredBox(
                color: bg,
                child: Padding(
                  padding: AppSpacing.screenPaddingCompact,
                  child: Row(
                    children: [
                      Expanded(
                        child: VeloraChromeButton(
                          label: 'Details',
                          selected: _tab == _DetailTab.details,
                          onTap: () => _selectTab(_DetailTab.details),
                        ),
                      ),
                      AppSpacing.gapSm,
                      Expanded(
                        child: VeloraChromeButton(
                          label: 'Standings',
                          selected: _tab == _DetailTab.standings,
                          onTap: () => _selectTab(_DetailTab.standings),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_tab == _DetailTab.details)
              DecoratedSliver(
                decoration: BoxDecoration(color: bg),
                sliver: SliverPadding(
                  padding: AppSpacing.screenPaddingCompact,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      _detailRows(context, design),
                    ),
                  ),
                ),
              )
            else
              DecoratedSliver(
                decoration: BoxDecoration(color: bg),
                sliver: SliverFillRemaining(
                  hasScrollBody: true,
                  child: ColoredBox(
                    color: bg,
                    child: _StandingsBody(internalId: widget.internalId),
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
      MapEntry(
        'Selection weight',
        design.selectionWeight?.toString(),
      ),
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
                  color: AppSurfaces.frameGold(Brightness.dark),
                ),
              ),
              AppSpacing.gapXxs,
              Text(
                value,
                style: context.appTypography.body.copyWith(
                  color: AppColors.onSurfaceDark,
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

    if (state.isLoading && state.standings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.standings == null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                onPressed: () => ref
                    .read(arcoriStandingsProvider(internalId).notifier)
                    .load(force: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final standings = state.standings;
    if (standings == null || standings.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'No standings yet for this generation',
            style: context.appTypography.body.copyWith(
              color: AppColors.onSurfaceDark,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: AppSpacing.screenPaddingCompact,
      children: [
        Text(
          'Generation fill',
          style: context.appTypography.caption.copyWith(
            color: AppSurfaces.frameGold(Brightness.dark),
          ),
        ),
        AppSpacing.gapXxs,
        Text(
          '${standings.fillCurrent} / ${standings.fillCap}',
          style: context.appTypography.body.copyWith(
            color: AppColors.onSurfaceDark,
          ),
        ),
        if (standings.leaderWindowEndsAt != null &&
            standings.leaderWindowEndsAt!.isNotEmpty) ...[
          AppSpacing.gapMd,
          Text(
            'Leader window',
            style: context.appTypography.caption.copyWith(
              color: AppSurfaces.frameGold(Brightness.dark),
            ),
          ),
          AppSpacing.gapXxs,
          Text(
            standings.leaderWindowEndsAt!,
            style: context.appTypography.body.copyWith(
              color: AppColors.onSurfaceDark,
            ),
          ),
        ],
        AppSpacing.gapLg,
        Text(
          'Ranks',
          style: context.appTypography.title.copyWith(
            color: AppColors.onSurfaceDark,
          ),
        ),
        AppSpacing.gapSm,
        if (standings.ranks.isEmpty)
          Text(
            'No ranks yet',
            style: context.appTypography.bodyMuted.copyWith(
              color: AppColors.onSurfaceMutedDark,
            ),
          )
        else
          for (final rank in standings.ranks)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: AppSpacing.xl,
                    child: Text(
                      '#${rank.rank}',
                      style: context.appTypography.body.copyWith(
                        color: AppColors.onSurfaceDark,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rank.displayLabel,
                      style: context.appTypography.body.copyWith(
                        color: AppColors.onSurfaceDark,
                      ),
                    ),
                  ),
                  Text(
                    '${rank.masteryPoints}',
                    style: context.appTypography.bodyMuted.copyWith(
                      color: AppColors.onSurfaceMutedDark,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
