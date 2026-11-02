import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth/auth_providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/economy_icon.dart';
import '../avari/avari_notifier.dart';
import 'market_api.dart';
import 'market_spend_modal.dart';

/// Shop hands, shared by the Market shelf and the hand detail Buy button.
final marketHandShelfProvider = FutureProvider<List<MarketHandSku>>((ref) async {
  final token = ref.watch(authProvider).accessToken?.trim() ?? '';
  if (token.isEmpty) return const [];
  final outcome = await MarketApiClient().fetchHands(accessToken: token);
  if (!outcome.isSuccess) return const [];
  return outcome.data?.hands ?? const [];
});

/// Buy one shop hand. Owned hands have no charge top-up.
class HandMarketAction extends ConsumerStatefulWidget {
  const HandMarketAction({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<HandMarketAction> createState() => _HandMarketActionState();
}

class _HandMarketActionState extends ConsumerState<HandMarketAction> {
  final _api = MarketApiClient();
  bool _busy = false;

  MarketHandSku? _skuIn(List<MarketHandSku> shelf) {
    for (final sku in shelf) {
      if (sku.designId == widget.designId) return sku;
    }
    return null;
  }

  Future<void> _buy(MarketHandSku sku) async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await showMarketSpendModal(
      context,
      title: 'Buy hand',
      confirmBody:
          'Buy ${sku.displayName} for ${sku.shopPriceGoldArcori} Gold Arcori.',
      confirmLabel: 'Buy · ${sku.shopPriceGoldArcori} Gold Arcori',
      send: () => _api.purchaseHand(accessToken: token, designId: sku.designId),
      successBody: (result) => 'Owned · ${result.goldArcori} Gold Arcori left',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    ref.invalidate(marketHandShelfProvider);
    await ref.read(avariProfileProvider.notifier).load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final shelf = ref.watch(marketHandShelfProvider);
    final sku = shelf.asData == null ? null : _skuIn(shelf.asData!.value);
    if (shelf.isLoading || sku == null || sku.owned) {
      return sku != null && sku.owned
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Owned',
                textAlign: TextAlign.center,
                style: context.appTypography.body.copyWith(
                  color: AppChrome.accentGold,
                ),
              ),
            )
          : const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: FilledButton(
        onPressed: !_busy && sku.canAffordPurchase ? () => _buy(sku) : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EconomyIcon(EconomyMark.goldArcori, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Buy · ${sku.shopPriceGoldArcori} Gold Arcori',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
