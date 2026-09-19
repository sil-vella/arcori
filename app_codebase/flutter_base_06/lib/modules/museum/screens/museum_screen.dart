import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../avari/avari_models.dart';
import '../../avari/widgets/inventory_face_chip.dart';
import '../museum_api.dart';
import '../museum_detail_modal.dart';
import '../museum_models.dart';

enum _MuseumFilter { all, preserved, lost }

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
  String? _error;
  _MuseumFilter _filter = _MuseumFilter.all;
  String _q = '';
  List<MuseumItem> _items = const [];
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _outcomeParam {
    switch (_filter) {
      case _MuseumFilter.all:
        return 'all';
      case _MuseumFilter.preserved:
        return 'preserved';
      case _MuseumFilter.lost:
        return 'lost';
    }
  }

  Future<void> _load({required bool reset, String? cursor}) async {
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
      });
      return;
    }

    final outcome = await _api.fetchList(
      accessToken: token,
      outcome: _outcomeParam,
      q: _q.isEmpty ? null : _q,
      limit: 30,
      cursor: cursor,
    );

    if (!mounted) return;

    if (!outcome.isSuccess) {
      final message = outcome.isNetworkError
          ? 'Network error — try again'
          : (outcome.error?.message ?? 'Could not load Museum');
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = message;
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
    });
  }

  void _setFilter(_MuseumFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _load(reset: true);
  }

  void _applySearch() {
    final next = _searchController.text.trim();
    if (next == _q) return;
    setState(() => _q = next);
    _load(reset: true);
  }

  Future<void> _openDetail(MuseumItem item) async {
    await showMuseumItemDetail(context, item: item);
  }

  @override
  Widget build(BuildContext context) {
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Museum', icon: Icons.account_balance_outlined),
      ],
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screenPaddingCompact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Closed Legacy generations — Preserved and Lost.',
                style: context.appTypography.bodySmall,
              ),
              AppSpacing.gapSm,
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == _MuseumFilter.all,
                    onTap: () => _setFilter(_MuseumFilter.all),
                  ),
                  _FilterChip(
                    label: 'Preserved',
                    selected: _filter == _MuseumFilter.preserved,
                    onTap: () => _setFilter(_MuseumFilter.preserved),
                  ),
                  _FilterChip(
                    label: 'Lost',
                    selected: _filter == _MuseumFilter.lost,
                    onTap: () => _setFilter(_MuseumFilter.lost),
                  ),
                ],
              ),
              AppSpacing.gapSm,
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _applySearch,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _applySearch(),
              ),
            ],
          ),
        ),
        Expanded(child: _buildList(context)),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: context.appTypography.body),
              AppSpacing.gapMd,
              FilledButton(
                onPressed: () => _load(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      final empty = switch (_filter) {
        _MuseumFilter.preserved => 'No Preserved generations yet.',
        _MuseumFilter.lost => 'No Lost generations yet.',
        _MuseumFilter.all => 'The Museum is empty — no closed generations yet.',
      };
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(empty, style: context.appTypography.bodyMuted),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120 &&
            !_loadingMore &&
            (_nextCursor ?? '').isNotEmpty) {
          _load(reset: false, cursor: _nextCursor);
        }
        return false;
      },
      child: ListView.separated(
        padding: AppSpacing.screenPaddingCompact,
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => AppSpacing.gapSm,
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[index];
          return _MuseumRow(
            item: item,
            onTap: () => _openDetail(item),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _MuseumRow extends StatelessWidget {
  const _MuseumRow({
    required this.item,
    required this.onTap,
  });

  final MuseumItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inventory = AvariInventoryItem(
      designId: item.designId,
      displayName: item.displayName,
      imageUrl: item.imageUrl,
      color: item.color,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InventoryFaceChip(
              item: inventory,
              captionOverride: item.genCaption,
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: context.appTypography.subtitle,
                  ),
                  AppSpacing.gapXxs,
                  Text(
                    item.historySummary.isNotEmpty
                        ? item.historySummary
                        : item.genCaption,
                    style: context.appTypography.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
