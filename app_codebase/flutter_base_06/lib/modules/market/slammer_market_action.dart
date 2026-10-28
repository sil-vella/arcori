import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth/auth_providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/economy_icon.dart';
import '../avari/avari_notifier.dart';
import 'market_api.dart';
import 'market_spend_modal.dart';

/// Shop shelf, shared by every Buy / Charge button on screen.
final marketSlammerShelfProvider = FutureProvider<List<MarketSlammerSku>>((
  ref,
) async {
  final token = ref.watch(authProvider).accessToken?.trim() ?? '';
  if (token.isEmpty) return const [];
  final outcome = await MarketApiClient().fetchSlammers(accessToken: token);
  if (!outcome.isSuccess) return const [];
  return outcome.data?.slammers ?? const [];
});

/// Buy or charge for one shop slammer. Sits on the slammer card.
class SlammerMarketAction extends ConsumerStatefulWidget {
  const SlammerMarketAction({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<SlammerMarketAction> createState() =>
      _SlammerMarketActionState();
}

class _SlammerMarketActionState extends ConsumerState<SlammerMarketAction> {
  final _api = MarketApiClient();
  bool _busy = false;

  MarketSlammerSku? _skuIn(List<MarketSlammerSku> shelf) {
    for (final sku in shelf) {
      if (sku.designId == widget.designId) return sku;
    }
    return null;
  }

  Future<void> _buy(MarketSlammerSku sku) async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await showMarketSpendModal(
      context,
      title: 'Buy slammer',
      confirmBody:
          'Buy ${sku.displayName} for ${sku.shopPriceGoldArcori} Gold Arcori. '
          'You get ${sku.maxCharges} uses.',
      confirmLabel: 'Buy · ${sku.shopPriceGoldArcori} Gold Arcori',
      send: () => _api.purchase(accessToken: token, designId: sku.designId),
      successBody: (result) =>
          'Done — ${result.chargesRemaining} uses · '
          '${result.goldArcori} Gold Arcori left',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    ref.invalidate(marketSlammerShelfProvider);
    await ref.read(avariProfileProvider.notifier).load(force: true);
  }

  Future<void> _charge(MarketSlammerSku sku) async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await showMarketSpendModal(
      context,
      title: 'Charge slammer',
      confirmBody:
          'Add ${sku.rechargeCharges} uses to ${sku.displayName} for '
          '${sku.rechargePriceGoldArcori} Gold Arcori.',
      confirmLabel: 'Charge · ${sku.rechargePriceGoldArcori} Gold Arcori',
      send: () => _api.recharge(accessToken: token, designId: sku.designId),
      successBody: (result) =>
          'Done — ${result.chargesRemaining} uses · '
          '${result.goldArcori} Gold Arcori left',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    ref.invalidate(marketSlammerShelfProvider);
    await ref.read(avariProfileProvider.notifier).load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final shelf = ref.watch(marketSlammerShelfProvider);
    final sku = shelf.asData == null ? null : _skuIn(shelf.asData!.value);
    if (shelf.isLoading || sku == null || sku.permanent) {
      return const SizedBox.shrink();
    }
    final label = !sku.owned
        ? 'Buy · ${sku.shopPriceGoldArcori} Gold Arcori'
        : 'Top up +${sku.rechargeCharges} · '
              '${sku.rechargePriceGoldArcori} Gold Arcori';
    final enabled = !sku.owned
        ? !_busy && sku.canAffordPurchase
        : !_busy && sku.canAffordRecharge;
    final button = FilledButton(
      onPressed: enabled ? () => !sku.owned ? _buy(sku) : _charge(sku) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EconomyIcon(EconomyMark.goldArcori, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: button,
    );
  }
}
