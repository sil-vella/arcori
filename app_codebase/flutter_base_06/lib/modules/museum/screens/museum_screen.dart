import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/screen.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_visuals.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../museum_api.dart';
import '../museum_assets.dart';
import '../museum_detail_modal.dart';
import '../museum_models.dart';

enum _MuseumFilter { legacies, lostGenerations }

/// World Museum — closed Preserved / Lost Legacy generations.
class MuseumScreen extends ConsumerStatefulWidget {
  const MuseumScreen({super.key});

  @override
  ConsumerState<MuseumScreen> createState() => _MuseumScreenState();
}

class _MuseumScreenState extends ConsumerState<MuseumScreen> {
  final _api = MuseumApiClient();
  final _searchController = TextEditingController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _seriesLoading = true;
  String? _error;
  String? _seriesError;
  _MuseumFilter _filter = _MuseumFilter.legacies;
  MuseumSeriesOption? _series;
  List<MuseumSeriesOption> _availableSeries = const [];
  String _q = '';
  List<MuseumItem> _items = const [];
  String? _nextCursor;
  MuseumItem? _featuredItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _outcomeParam {
    switch (_filter) {
      case _MuseumFilter.legacies:
        return 'preserved';
      case _MuseumFilter.lostGenerations:
        return 'lost';
    }
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadFeaturedOnly(),
      _loadAvailableSeries(),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = null;
      _items = const [];
      _nextCursor = null;
    });
  }

  MuseumItem? _pickFeatured(List<MuseumItem> candidates) {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;
    return candidates[Random().nextInt(candidates.length)];
  }

  Future<void> _loadFeaturedOnly() async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _featuredItem = null;
        _error = 'Sign in to view the Museum';
      });
      return;
    }
    final featured = await _api.fetchBanner(accessToken: token);
    if (!mounted) return;
    if (featured.isSuccess) {
      setState(
        () => _featuredItem = _pickFeatured(featured.data?.items ?? const []),
      );
    }
  }

  Future<void> _loadAvailableSeries() async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _seriesLoading = false;
        _availableSeries = const [];
        _seriesError = 'Sign in to view the Museum';
      });
      return;
    }

    setState(() {
      _seriesLoading = true;
      _seriesError = null;
    });

    final outcome = await _api.fetchSeries(
      accessToken: token,
      outcome: _outcomeParam,
    );
    if (!mounted) return;

    if (!outcome.isSuccess) {
      setState(() {
        _seriesLoading = false;
        _availableSeries = const [];
        _seriesError = outcome.isNetworkError
            ? 'Network error — try again'
            : (outcome.error?.message ?? 'Could not load series');
      });
      return;
    }

    final series = outcome.data?.series ?? const <MuseumSeriesOption>[];
    final selected = _series;
    final stillValid =
        selected != null && series.any((s) => s.key == selected.key);
    setState(() {
      _seriesLoading = false;
      _availableSeries = series;
      _seriesError = null;
      if (!stillValid) {
        _series = null;
        if (_q.isEmpty) {
          _items = const [];
          _nextCursor = null;
        }
      }
    });
  }

  Future<void> _load({required bool reset, String? cursor}) async {
    final searching = _q.isNotEmpty;
    final series = searching ? null : _series;
    if (!searching && series == null) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = null;
        _items = const [];
        _nextCursor = null;
      });
      return;
    }

    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items = const [];
        _nextCursor = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Sign in to view the Museum';
        _featuredItem = null;
      });
      return;
    }

    final listFuture = _api.fetchList(
      accessToken: token,
      outcome: _outcomeParam,
      series: series?.key,
      q: searching ? _q : null,
      limit: 30,
      cursor: cursor,
    );
    final bannerFuture = reset ? _api.fetchBanner(accessToken: token) : null;

    final outcome = await listFuture;
    MuseumItem? featuredItem = _featuredItem;
    if (bannerFuture != null) {
      final featured = await bannerFuture;
      if (featured.isSuccess) {
        featuredItem = _pickFeatured(featured.data?.items ?? const []);
      } else if (reset) {
        featuredItem = null;
      }
    }

    if (!mounted) return;

    if (!outcome.isSuccess) {
      final message = outcome.isNetworkError
          ? 'Network error — try again'
          : (outcome.error?.message ?? 'Could not load Museum');
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = message;
        if (reset) _featuredItem = featuredItem;
      });
      return;
    }

    final page = outcome.data!;
    setState(() {
      _loading = false;
      _loadingMore = false;
      _error = null;
      _items = reset ? page.items : [..._items, ...page.items];
      _nextCursor = page.nextCursor;
      if (reset) _featuredItem = featuredItem;
    });
  }

  void _setFilter(_MuseumFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _series = null;
      if (_q.isEmpty) {
        _items = const [];
        _nextCursor = null;
      }
    });
    _loadAvailableSeries();
    if (_q.isNotEmpty) {
      _load(reset: true);
    }
  }

  void _selectSeries(MuseumSeriesOption series) {
    if (_series?.key == series.key && _q.isEmpty) return;
    setState(() {
      _series = series;
      _q = '';
      _searchController.clear();
    });
    _load(reset: true);
  }

  void _clearSeries() {
    if (_series == null) return;
    setState(() {
      _series = null;
      _items = const [];
      _nextCursor = null;
      _error = null;
      _loading = false;
    });
    if (_q.isNotEmpty) {
      _load(reset: true);
    }
  }

  void _applySearch() {
    final next = _searchController.text.trim();
    if (next == _q) return;
    setState(() {
      _q = next;
      // Global search — leave series browse behind.
      if (next.isNotEmpty) {
        _series = null;
      }
    });
    _load(reset: true);
  }

  Future<void> _openDetail(MuseumItem item) async {
    await showMuseumItemDetail(context, item: item);
  }

  bool get _showingResults => _q.isNotEmpty || _series != null;

  bool _onScroll(ScrollNotification n) {
    if (!_showingResults) return false;
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120 &&
        !_loadingMore &&
        (_nextCursor ?? '').isNotEmpty) {
      _load(reset: false, cursor: _nextCursor);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Museum', icon: Icons.account_balance_outlined),
      ],
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: AppScreenTemplate001(
          backgroundAsset: kMuseumHallBackgroundAsset,
          scrimOpacity: 0,
          appBarForeground: Colors.white,
          banner: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [
                          _contentCanvasBase.withValues(alpha: 0.8),
                          _contentCanvasBase.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _FeaturedBanner(
                item: _featuredItem,
                onTap: _featuredItem == null
                    ? null
                    : () => _openDetail(_featuredItem!),
              ),
            ],
          ),
          slivers: [
            SliverToBoxAdapter(
              child: ColoredBox(
                color: _contentCanvas,
                child: _buildHeader(context),
              ),
            ),
            ..._buildContentSlivers(context),
          ],
        ),
      ),
    );
  }

  /// Museum content panel — dark theme canvas at 80% so the hall mural shows through.
  Color get _contentCanvasBase => AppSurfaces.canvas(Brightness.dark);

  Color get _contentCanvas => _contentCanvasBase.withValues(alpha: 0.8);

  Widget _buildHeader(BuildContext context) {
    final series = _series;
    final searching = _q.isNotEmpty;
    return Padding(
      padding: AppSpacing.screenPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            style: context.appTypography.body.copyWith(
              color: AppColors.onSurfaceDark,
            ),
            cursorColor: AppSurfaces.frameGold(Brightness.dark),
            decoration: InputDecoration(
              hintText: 'Search any Arcori',
              hintStyle: context.appTypography.bodyMuted.copyWith(
                color: AppColors.onSurfaceMutedDark,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceDark,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(
                  color: AppSurfaces.frameBronze(Brightness.dark),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(
                  color: AppSurfaces.frameGold(Brightness.dark),
                  width: 1.5,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.search,
                  color: AppSurfaces.frameGold(Brightness.dark),
                ),
                onPressed: _applySearch,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applySearch(),
          ),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: _MuseumChromeButton(
                  label: 'Legacies',
                  selected: _filter == _MuseumFilter.legacies,
                  onTap: () => _setFilter(_MuseumFilter.legacies),
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: _MuseumChromeButton(
                  label: 'Lost Generations',
                  selected: _filter == _MuseumFilter.lostGenerations,
                  onTap: () => _setFilter(_MuseumFilter.lostGenerations),
                ),
              ),
            ],
          ),
          if (series != null && !searching) ...[
            AppSpacing.gapSm,
            Row(
              children: [
                IconButton(
                  tooltip: 'All series',
                  onPressed: _clearSeries,
                  color: AppColors.onSurfaceDark,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    series.label,
                    style: context.appTypography.subtitle.copyWith(
                      color: AppColors.onSurfaceDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(BuildContext context) {
    final bg = _contentCanvas;
    final searching = _q.isNotEmpty;

    if (!_showingResults) {
      if (_seriesLoading) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ColoredBox(
              color: bg,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ];
      }
      if (_seriesError != null) {
        return [
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
                        _seriesError!,
                        style: context.appTypography.body.copyWith(
                          color: AppColors.onSurfaceDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapMd,
                      FilledButton(
                        onPressed: _loadAvailableSeries,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];
      }
      if (_availableSeries.isEmpty) {
        final empty = switch (_filter) {
          _MuseumFilter.legacies => 'No Legacies yet.',
          _MuseumFilter.lostGenerations => 'No Lost Generations yet.',
        };
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ColoredBox(
              color: bg,
              child: AppEmptyState(
                message: empty,
                icon: Icons.account_balance_outlined,
              ),
            ),
          ),
        ];
      }
      return [
        DecoratedSliver(
          decoration: BoxDecoration(color: bg),
          sliver: SliverPadding(
            padding: AppSpacing.screenPaddingCompact,
            sliver: SliverList.separated(
              itemCount: _availableSeries.length,
              separatorBuilder: (_, __) => AppSpacing.gapSm,
              itemBuilder: (context, index) {
                final series = _availableSeries[index];
                return _MuseumChromeButton(
                  label: series.label,
                  selected: false,
                  onTap: () => _selectSeries(series),
                  textStyle: context.appTypography.title.copyWith(
                    color: AppColors.onSurfaceDark,
                  ),
                );
              },
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(color: bg),
        ),
      ];
    }

    if (_loading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: bg,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
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
                      _error!,
                      style: context.appTypography.body.copyWith(
                        color: AppColors.onSurfaceDark,
                      ),
                    ),
                    AppSpacing.gapMd,
                    FilledButton(
                      onPressed: () => _load(reset: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      final empty = searching
          ? 'No matches for “$_q”.'
          : switch (_filter) {
              _MuseumFilter.legacies => 'No Legacies in this series yet.',
              _MuseumFilter.lostGenerations =>
                'No Lost Generations in this series yet.',
            };
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: bg,
            child: AppEmptyState(
              message: empty,
              icon: Icons.account_balance_outlined,
            ),
          ),
        ),
      ];
    }

    return [
      DecoratedSliver(
        decoration: BoxDecoration(color: bg),
        sliver: SliverPadding(
          padding: AppSpacing.screenPaddingCompact,
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _items[index];
                return _MuseumTile(
                  item: item,
                  onTap: () => _openDetail(item),
                );
              },
              childCount: _items.length,
            ),
          ),
        ),
      ),
      if (_loadingMore)
        SliverToBoxAdapter(
          child: ColoredBox(
            color: bg,
            child: const Padding(
              padding: AppSpacing.screenPaddingCompact,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      SliverFillRemaining(
        hasScrollBody: false,
        child: ColoredBox(color: bg),
      ),
    ];
  }
}

class _FeaturedBanner extends StatefulWidget {
  const _FeaturedBanner({
    required this.item,
    this.onTap,
  });

  final MuseumItem? item;
  final VoidCallback? onTap;

  @override
  State<_FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<_FeaturedBanner>
    with SingleTickerProviderStateMixin {
  static const double _discSize = 140;
  static const Duration _cycle = Duration(milliseconds: 4800);
  static const double _bouncePx = 7;
  static const double _swivelRad = 0.32; // ~18°

  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: _cycle)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featured = widget.item;
    if (featured == null) {
      return Center(
        child: Text(
          'No featured Arcori',
          style: context.appTypography.bodyMuted,
          textAlign: TextAlign.center,
        ),
      );
    }

    final disc = AnimatedBuilder(
      animation: _idle,
      child: SizedBox(
        width: _discSize,
        height: _discSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -_discSize * 0.275,
              top: -_discSize * 0.275,
              width: _discSize * 1.55,
              height: _discSize * 1.55,
              child: IgnorePointer(
                child: Lottie.asset(
                  kMuseumFeaturedGlowLottie,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ),
            ArcoriCylinder(
              look: ArcoriLook(
                designId: featured.designId,
                imageUrl: featured.imageUrl,
                colorHex: featured.color,
              ),
              size: _discSize,
            ),
          ],
        ),
      ),
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_idle.value);
        final bounceY = (0.5 - t) * 2 * _bouncePx;
        final swivel = (t - 0.5) * 2 * _swivelRad;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(swivel)
            ..translate(0.0, bounceY),
          child: child,
        );
      },
    );

    final stage = SizedBox(
      width: _discSize * 1.55,
      height: _discSize * 0.95 + 58,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: _discSize * 0.92,
            left: 0,
            right: 0,
            child: Image.asset(
              kMuseumPedestalAsset,
              height: 58,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          disc,
        ],
      ),
    );

    final body = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        stage,
        AppSpacing.gapSm,
        Text(
          featured.displayName,
          style: context.appTypography.h3.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        AppSpacing.gapXxs,
        Text(
          _featuredSubline(featured),
          style: context.appTypography.caption.copyWith(
            color: context.appSurfaces.frameGold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (widget.onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: body,
      ),
    );
  }

  static String _featuredSubline(MuseumItem item) {
    final gen = 'Gen ${item.generationNumber}';
    final name = (item.actorDisplayName ?? '').trim();
    if (name.isEmpty) return gen;
    if (item.isPreserved || item.actorRole == 'legacy_owner') {
      return '$gen · Legacy Owner: $name';
    }
    return gen;
  }
}

class _MuseumChromeButton extends StatelessWidget {
  const _MuseumChromeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  static const _brightness = Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final gold = AppSurfaces.frameGold(_brightness);
    final bronze = AppSurfaces.frameBronze(_brightness);
    final fill = selected
        ? AppColors.primaryContainerDark
        : AppColors.surfaceDark;
    final border = selected ? gold : bronze;
    final labelStyle = (textStyle ?? context.appTypography.subtitle).copyWith(
      color: selected ? gold : AppColors.onSurfaceDark,
    );

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: labelStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _MuseumTile extends StatelessWidget {
  const _MuseumTile({
    required this.item,
    required this.onTap,
  });

  final MuseumItem item;
  final VoidCallback onTap;

  static const double _discSize = 72;
  static const double _pedestalHeight = 34;

  @override
  Widget build(BuildContext context) {
    final gold = AppSurfaces.frameGold(Brightness.dark);
    final radius = BorderRadius.circular(AppRadii.md);
    final stageHeight = _discSize * 0.72 + _pedestalHeight;
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
              padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 4, AppSpacing.xs, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _discSize + 16,
                    height: stageHeight,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: _discSize * 0.72,
                          left: 0,
                          right: 0,
                          child: Image.asset(
                            kMuseumPedestalAsset,
                            height: _pedestalHeight,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                        ArcoriCylinder(
                          look: ArcoriLook(
                            designId: item.designId,
                            imageUrl: item.imageUrl,
                            colorHex: item.color,
                          ),
                          size: _discSize,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.displayName,
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
