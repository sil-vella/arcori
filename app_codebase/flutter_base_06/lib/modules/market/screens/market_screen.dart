import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_visuals.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../../../core/widgets/economy_icon.dart';
import '../../hub/hub_bottom_nav.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../market_api.dart';

/// Market hub — Shop slammers (buy / recharge). Starter is not sold.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final _api = MarketApiClient();
  MarketSlammersList? _list;
  bool _loading = true;
  String? _error;

  /// Open series card. Null follows the latest series. Empty means all collapsed.
  String? _openSeries;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sign in to browse the Market';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final outcome = await _api.fetchSlammers(accessToken: token);
    if (!mounted) return;
    if (!outcome.isSuccess) {
      setState(() {
        _loading = false;
        _error = outcome.isNetworkError
            ? 'Network error'
            : (outcome.error?.message ?? 'Could not load Market');
      });
      return;
    }
    setState(() {
      _loading = false;
      _list = outcome.data;
    });
  }

  void _openDetail(MarketSlammerSku sku) {
    final location =
        '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(sku.designId)}';
    GoRouter.of(context).push(location).then((_) {
      if (mounted) _load();
    });
  }

  List<_SeriesGroup> _seriesGroups(Iterable<MarketSlammerSku> items) {
    final groups = _groupBySeries(items);
    groups.sort((a, b) => b.order.compareTo(a.order));
    return groups;
  }

  String? _shownOpen(List<_SeriesGroup> groups) {
    if (groups.isEmpty) return null;
    final chosen = _openSeries;
    if (chosen == null) return groups.first.series;
    if (chosen.isEmpty) return null;
    if (groups.any((group) => group.series == chosen)) return chosen;
    return groups.first.series;
  }

  void _toggleSeries(String series, String? shownOpen) {
    setState(() {
      _openSeries = shownOpen == series ? '' : series;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gold = _list?.goldArcori;
    final seriesGroups = _list == null
        ? const <_SeriesGroup>[]
        : _seriesGroups(_list!.slammers.skip(1));
    final openSeries = _shownOpen(seriesGroups);
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Market', icon: Icons.storefront_outlined),
      ],
      bottomNavModuleId: hubSinkBottomNavModuleId,
      bottomNavItems: hubSinkBottomNavItems(context),
      child: AppChromePage(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppChromePage.topClearance(context) + AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              AppChromeSection(
                title: 'Your wallet',
                icon: Icons.account_balance_wallet_outlined,
                goldFrame: true,
                child: Row(
                  children: [
                    const EconomyIcon(EconomyMark.goldArcori, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      gold == null ? '—' : '$gold',
                      style: context.appTypography.h2.copyWith(
                        color: AppChrome.accentGold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Gold Arcori',
                      style: context.appTypography.body.copyWith(
                        color: AppChrome.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                AppChromeSection(
                  title: 'Slammers',
                  mark: const AppMarkIcon(AppMarks.slammers),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _error!,
                        style: context.appTypography.body.copyWith(
                          color: AppChrome.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else ...[
                if ((_list?.slammers.isNotEmpty ?? false))
                  _FeaturedSlammer(
                    sku: _list!.slammers.first,
                    onOpen: () => _openDetail(_list!.slammers.first),
                  ),
                for (final group in seriesGroups) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SlammerSeriesGrid(
                    series: group.series,
                    slammers: group.slammers,
                    expanded: group.series == openSeries,
                    onToggle: () => _toggleSeries(group.series, openSeries),
                    onOpen: _openDetail,
                  ),
                ],
                if ((_list?.slammers.isEmpty ?? true))
                  AppChromeSection(
                    title: 'Slammers',
                    mark: const AppMarkIcon(AppMarks.slammers),
                    child: Text(
                      'No slammers for sale yet.',
                      style: context.appTypography.body.copyWith(
                        color: AppChrome.onSurfaceMuted,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesGroup {
  const _SeriesGroup(this.series, this.order, this.slammers);

  final String series;
  final int order;
  final List<MarketSlammerSku> slammers;
}

List<_SeriesGroup> _groupBySeries(Iterable<MarketSlammerSku> items) {
  final order = <String>[];
  final buckets = <String, List<MarketSlammerSku>>{};
  for (final sku in items) {
    final name = sku.series.trim().isEmpty ? 'Series' : sku.series.trim();
    buckets
        .putIfAbsent(name, () {
          order.add(name);
          return <MarketSlammerSku>[];
        })
        .add(sku);
  }
  return [
    for (final name in order)
      _SeriesGroup(
        name,
        buckets[name]!
            .map((sku) => sku.seriesOrder)
            .reduce((best, next) => next > best ? next : best),
        buckets[name]!,
      ),
  ];
}

class _FeaturedSlammer extends StatelessWidget {
  const _FeaturedSlammer({required this.sku, required this.onOpen});

  final MarketSlammerSku sku;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppChromeSection(
      title: 'Featured slammer',
      mark: const AppMarkIcon(AppMarks.slammers),
      goldFrame: true,
      child: _SlammerSkuCard(sku: sku, onOpen: onOpen),
    );
  }
}

class _SlammerSkuCard extends StatelessWidget {
  const _SlammerSkuCard({required this.sku, required this.onOpen});

  final MarketSlammerSku sku;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArcoriCylinder(
                  look: ArcoriLook(
                    designId: sku.designId,
                    imageUrl: sku.imageUrl,
                    colorHex: sku.color,
                  ),
                  size: 88,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sku.displayName,
                        style: context.appTypography.h3.copyWith(
                          color: AppChrome.accentGold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Buy for ${sku.shopPriceGoldArcori} Gold Arcori '
                        '(${sku.maxCharges} uses). Each slam spends 1 use. '
                        'Top up +${sku.rechargeCharges} for '
                        '${sku.rechargePriceGoldArcori} Gold Arcori.',
                        style: context.appTypography.bodyMuted.copyWith(
                          color: AppChrome.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (sku.owned) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                sku.permanent
                    ? 'Owned · permanent'
                    : 'Owned · ${sku.chargesRemaining ?? 0} charges left',
                style: context.appTypography.body.copyWith(
                  color: AppChrome.accentGold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One series of shop slammers, two tiles per row.
class _SlammerSeriesGrid extends StatelessWidget {
  const _SlammerSeriesGrid({
    required this.series,
    required this.slammers,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
  });

  final String series;
  final List<MarketSlammerSku> slammers;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(MarketSlammerSku sku) onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < slammers.length; i += 2) {
      final left = slammers[i];
      final right = i + 1 < slammers.length ? slammers[i + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.sm));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SlammerTile(sku: left, onOpen: () => onOpen(left)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _SlammerTile(sku: right, onOpen: () => onOpen(right)),
            ),
          ],
        ),
      );
    }
    return AppCardFrame(
      gold: true,
      fill: AppChrome.panelFill,
      child: Padding(
        padding: AppSpacing.screenPaddingCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppChrome.accentBronze,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    const AppMarkIcon(AppMarks.slammers),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        series,
                        style: context.appTypography.title.copyWith(
                          color: AppChrome.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppChrome.accentGold,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              AppSpacing.gapSm,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlammerTile extends StatelessWidget {
  const _SlammerTile({required this.sku, required this.onOpen});

  final MarketSlammerSku sku;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ownedLine = sku.permanent
        ? 'Permanent'
        : sku.owned
        ? '${sku.chargesRemaining ?? 0} uses'
        : '${sku.shopPriceGoldArcori} Gold Arcori · ${sku.maxCharges} uses';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppChrome.panelFill,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppChrome.panelBorderGold),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ArcoriCylinder(
                    look: ArcoriLook(
                      designId: sku.designId,
                      imageUrl: sku.imageUrl,
                      colorHex: sku.color,
                    ),
                    size: 72,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  sku.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.appTypography.subtitle.copyWith(
                    color: AppChrome.accentGold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  ownedLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.appTypography.bodySmall.copyWith(
                    color: sku.owned
                        ? AppChrome.accentGold
                        : AppChrome.onSurfaceMuted,
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
