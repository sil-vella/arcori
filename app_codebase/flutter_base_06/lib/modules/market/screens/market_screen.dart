import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../avari/avari_api.dart';
import '../../avari/avari_notifier.dart';
import '../../hub/hub_bottom_nav.dart';
import '../market_api.dart';

/// Market hub — Slammers section (Rim buy / recharge).
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
    await _runAction(() => _api.purchase(
          accessToken: ref.read(authProvider).accessToken!.trim(),
          designId: sku.designId,
        ));
  }

  Future<void> _recharge(MarketSlammerSku sku) async {
    await _runAction(() => _api.recharge(
          accessToken: ref.read(authProvider).accessToken!.trim(),
          designId: sku.designId,
        ));
  }

  Future<void> _runAction(
    Future<AvariApiOutcome<MarketPurchaseResult>> Function() send,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await send();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!outcome.isSuccess) {
      final msg = outcome.isNetworkError
          ? 'Network error'
          : (outcome.error?.message ?? 'Purchase failed');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    final result = outcome.data!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Done — ${result.chargesRemaining} charges · '
          '${result.goldArcori} Gold Arcori left',
        ),
      ),
    );
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
              if (gold != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    'Wallet · $gold Gold Arcori',
                    style: context.appTypography.bodyMuted.copyWith(
                      color: AppChrome.onSurfaceMuted,
                    ),
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                AppChromeSection(
                  title: 'Slammers',
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
              else
                AppChromeSection(
                  title: 'Slammers',
                  goldFrame: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final sku in _list?.slammers ?? const <MarketSlammerSku>[])
                        _RimSkuCard(
                          sku: sku,
                          busy: _busy,
                          onBuy: () => _purchase(sku),
                          onRecharge: () => _recharge(sku),
                        ),
                      if ((_list?.slammers.isEmpty ?? true))
                        Text(
                          'No slammers for sale yet.',
                          style: context.appTypography.body.copyWith(
                            color: AppChrome.onSurfaceMuted,
                          ),
                        ),
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

class _RimSkuCard extends StatelessWidget {
  const _RimSkuCard({
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
    final hit = (sku.hitTarget ?? 'edge').toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sku.displayName,
            style: context.appTypography.title.copyWith(
              color: AppChrome.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'High precision · prefers $hit shots · mid power. '
            'Buy for ${sku.shopPriceGoldArcori} Gold Arcori '
            '(${sku.maxCharges} uses). Top up +${sku.rechargeCharges} '
            'for ${sku.rechargePriceGoldArcori} Gold Arcori.',
            style: context.appTypography.bodyMuted.copyWith(
              color: AppChrome.onSurfaceMuted,
            ),
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
            FilledButton(
              onPressed: busy || !sku.canAffordPurchase ? null : onBuy,
              child: Text(
                'Buy · ${sku.shopPriceGoldArcori} Gold Arcori',
              ),
            )
          else if (!sku.permanent)
            FilledButton(
              onPressed: busy || !sku.canAffordRecharge ? null : onRecharge,
              child: Text(
                'Top up +${sku.rechargeCharges} · '
                '${sku.rechargePriceGoldArcori} Gold Arcori',
              ),
            ),
        ],
      ),
    );
  }
}
