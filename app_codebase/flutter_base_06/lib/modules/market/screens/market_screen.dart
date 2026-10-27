import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../../../core/widgets/economy_icon.dart';
import '../../avari/avari_api.dart';
import '../../avari/avari_notifier.dart';
import '../../hub/hub_bottom_nav.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../market_api.dart';
import '../market_spend_modal.dart';

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
  bool _busy = false;
  String? _error;

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

  Future<void> _purchase(MarketSlammerSku sku) async {
    await _spend(
      title: 'Buy slammer',
      confirmBody:
          'Buy ${sku.displayName} for ${sku.shopPriceGoldArcori} Gold Arcori. '
          'You get ${sku.maxCharges} uses.',
      confirmLabel: 'Buy · ${sku.shopPriceGoldArcori} Gold Arcori',
      send: (token) =>
          _api.purchase(accessToken: token, designId: sku.designId),
    );
  }

  Future<void> _recharge(MarketSlammerSku sku) async {
    await _spend(
      title: 'Charge slammer',
      confirmBody:
          'Add ${sku.rechargeCharges} uses to ${sku.displayName} for '
          '${sku.rechargePriceGoldArcori} Gold Arcori.',
      confirmLabel: 'Charge · ${sku.rechargePriceGoldArcori} Gold Arcori',
      send: (token) =>
          _api.recharge(accessToken: token, designId: sku.designId),
    );
  }

  Future<void> _spend({
    required String title,
    required String confirmBody,
    required String confirmLabel,
    required Future<AvariApiOutcome<MarketPurchaseResult>> Function(
      String token,
    )
    send,
  }) async {
    if (_busy) return;
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) return;
    setState(() => _busy = true);
    final ok = await showMarketSpendModal(
      context,
      title: title,
      confirmBody: confirmBody,
      confirmLabel: confirmLabel,
      send: () => send(token),
      successBody: (result) =>
          'Done — ${result.chargesRemaining} uses · '
          '${result.goldArcori} Gold Arcori left',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    await ref.read(avariProfileProvider.notifier).load(force: true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final gold = _list?.goldArcori;
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
                        onPressed: _busy ? null : _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else ...[
                if ((_list?.slammers.isNotEmpty ?? false))
                  _FeaturedSlammer(
                    sku: _list!.slammers.first,
                    busy: _busy,
                    onBuy: () => _purchase(_list!.slammers.first),
                    onRecharge: () => _recharge(_list!.slammers.first),
                  ),
                if ((_list?.slammers.length ?? 0) > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppChromeSection(
                    title: 'More slammers',
                    mark: const AppMarkIcon(AppMarks.slammers),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 1; i < _list!.slammers.length; i++)
                          _SlammerSkuCard(
                            sku: _list!.slammers[i],
                            busy: _busy,
                            compact: true,
                            onBuy: () => _purchase(_list!.slammers[i]),
                            onRecharge: () => _recharge(_list!.slammers[i]),
                          ),
                      ],
                    ),
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

class _FeaturedSlammer extends StatelessWidget {
  const _FeaturedSlammer({
    required this.sku,
    required this.busy,
    required this.onBuy,
    required this.onRecharge,
  });

  final MarketSlammerSku sku;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return AppChromeSection(
      title: 'Featured slammer',
      mark: const AppMarkIcon(AppMarks.slammers),
      goldFrame: true,
      child: _SlammerSkuCard(
        sku: sku,
        busy: busy,
        onBuy: onBuy,
        onRecharge: onRecharge,
      ),
    );
  }
}

class _SlammerSkuCard extends StatelessWidget {
  const _SlammerSkuCard({
    required this.sku,
    required this.busy,
    required this.onBuy,
    required this.onRecharge,
    this.compact = false,
  });

  final MarketSlammerSku sku;
  final bool busy;
  final bool compact;
  final VoidCallback onBuy;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                size: compact ? 56 : 88,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sku.displayName,
                      style:
                          (compact
                                  ? context.appTypography.subtitle
                                  : context.appTypography.h3)
                              .copyWith(
                                color: compact
                                    ? AppChrome.onSurface
                                    : AppChrome.accentGold,
                              ),
                    ),
                    if (!compact) ...[
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
          const SizedBox(height: AppSpacing.md),
          if (!sku.owned)
            FilledButton.icon(
              onPressed: busy || !sku.canAffordPurchase ? null : onBuy,
              icon: const EconomyIcon(EconomyMark.goldArcori, size: 22),
              label: Text('Buy · ${sku.shopPriceGoldArcori} Gold Arcori'),
            )
          else if (!sku.permanent)
            FilledButton.icon(
              onPressed: busy || !sku.canAffordRecharge ? null : onRecharge,
              icon: const EconomyIcon(EconomyMark.goldArcori, size: 22),
              label: Text(
                'Top up +${sku.rechargeCharges} · '
                '${sku.rechargePriceGoldArcori} Gold Arcori',
              ),
            ),
        ],
      ),
    );
  }
}
