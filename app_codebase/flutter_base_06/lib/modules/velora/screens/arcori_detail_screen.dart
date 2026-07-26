import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../velora_models.dart';
import '../velora_notifier.dart';
import '../widgets/circle_crop_image.dart';

/// Arcori Detail SSOT — Details + Standings (My Mastery deferred).
class ArcoriDetailScreen extends ConsumerStatefulWidget {
  const ArcoriDetailScreen({required this.internalId, super.key});

  final String internalId;

  @override
  ConsumerState<ArcoriDetailScreen> createState() => _ArcoriDetailScreenState();
}

class _ArcoriDetailScreenState extends ConsumerState<ArcoriDetailScreen>
    with SingleTickerProviderStateMixin {
  static const double _artSize = 200;

  late final TabController _tabs;
  bool _standingsRequested = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(arcoriDetailProvider.notifier).load(widget.internalId);
    });
  }

  @override
  void didUpdateWidget(covariant ArcoriDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.internalId != widget.internalId) {
      _standingsRequested = false;
      ref.read(arcoriDetailProvider.notifier).load(widget.internalId);
      if (_tabs.index == 1) {
        _loadStandings();
      }
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.index == 1 && !_tabs.indexIsChanging) {
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
                  : Column(
                      children: [
                        Padding(
                          padding: AppSpacing.screenPaddingCompact,
                          child: Column(
                            children: [
                              SizedBox(
                                width: _artSize,
                                height: _artSize,
                                child: CircleCropImage(
                                  imageUrl: design.imageUrl,
                                ),
                              ),
                              AppSpacing.gapSm,
                              Text(
                                design.displayName,
                                style: context.appTypography.h3,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        TabBar(
                          controller: _tabs,
                          tabs: const [
                            Tab(text: 'Details'),
                            Tab(text: 'Standings'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _DetailsTab(design: design),
                              _StandingsTab(internalId: widget.internalId),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.design});

  final DesignDetail design;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: _detailRows(context, design),
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

class _StandingsTab extends ConsumerWidget {
  const _StandingsTab({required this.internalId});

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
            style: context.appTypography.body,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(arcoriStandingsProvider(internalId).notifier).load(force: true),
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            'Generation fill',
            style: context.appTypography.caption.copyWith(
              color: context.appColorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapXxs,
          Text(
            '${standings.fillCurrent} / ${standings.fillCap}',
            style: context.appTypography.body,
          ),
          if (standings.leaderWindowEndsAt != null &&
              standings.leaderWindowEndsAt!.isNotEmpty) ...[
            AppSpacing.gapMd,
            Text(
              'Leader window',
              style: context.appTypography.caption.copyWith(
                color: context.appColorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapXxs,
            Text(
              standings.leaderWindowEndsAt!,
              style: context.appTypography.body,
            ),
          ],
          AppSpacing.gapLg,
          Text('Ranks', style: context.appTypography.title),
          AppSpacing.gapSm,
          if (standings.ranks.isEmpty)
            Text(
              'No ranks yet',
              style: context.appTypography.bodyMuted,
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
                        style: context.appTypography.body,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rank.displayLabel,
                        style: context.appTypography.body,
                      ),
                    ),
                    Text(
                      '${rank.masteryPoints}',
                      style: context.appTypography.bodyMuted,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
