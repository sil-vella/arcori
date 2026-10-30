import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/economy_icon.dart';
import '../../../utils/dev_logger.dart';
import '../../hub/hub_bottom_nav.dart';
import '../store_api.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Buy Gold Fragment packs from Play or the App Store.
class FragmentStoreScreen extends ConsumerStatefulWidget {
  const FragmentStoreScreen({super.key});

  @override
  ConsumerState<FragmentStoreScreen> createState() => _FragmentStoreScreenState();
}

class _FragmentStoreScreenState extends ConsumerState<FragmentStoreScreen> {
  final _api = StoreApiClient();
  final InAppPurchase _store = InAppPurchase.instance;

  FragmentCatalog? _catalog;
  Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  bool _loading = true;
  bool _storeReady = false;
  String? _error;
  String? _busyProductId;
  FragmentPurchaseResult? _wallet;

  bool get _nativeStore =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _purchases?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sign in to buy Gold Fragments';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final outcome = await _api.fetchCatalog(accessToken: token);
    if (!mounted) return;
    if (!outcome.isSuccess || outcome.data == null) {
      setState(() {
        _loading = false;
        _error = outcome.isNetworkError
            ? 'Network error'
            : (outcome.error?.message ?? 'Could not load fragment packs');
      });
      return;
    }
    setState(() {
      _loading = false;
      _catalog = outcome.data;
    });
    await _openStore(outcome.data!);
  }

  Future<void> _openStore(FragmentCatalog catalog) async {
    if (!_nativeStore) return;
    final available = await _store.isAvailable();
    if (!mounted) return;
    setState(() => _storeReady = available);
    if (!available) return;
    await _purchases?.cancel();
    _purchases = _store.purchaseStream.listen(_onPurchases);
    final ids = catalog.packs.map((pack) => pack.productId).toSet();
    if (ids.isEmpty) return;
    final response = await _store.queryProductDetails(ids);
    if (!mounted) return;
    setState(() {
      _products = {for (final item in response.productDetails) item.id: item};
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
        final message = purchase.error?.message;
        if (message != null && message.isNotEmpty && mounted) {
          _snack(message);
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verify(purchase);
      }
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) {
      _snack('Sign in to finish this purchase');
      return;
    }
    final outcome = await _api.verifyPurchase(
      accessToken: token,
      purchase: purchase,
    );
    if (!mounted) return;
    if (!outcome.isSuccess || outcome.data == null) {
      _snack(
        outcome.isNetworkError
            ? 'Network error. Reopen this screen to retry.'
            : (outcome.error?.message ?? 'Could not confirm the purchase'),
      );
      return;
    }
    if (purchase.pendingCompletePurchase) {
      await _store.completePurchase(purchase);
    }
    final result = outcome.data!;
    if (LOGGING_SWITCH) {
      customlog(
        'store: verified product=${result.productId} '
        'fragments=${result.fragmentsCredited} '
        'goldArcori=${result.goldArcori}',
      );
    }
    setState(() => _wallet = result);
    _snack('+${result.fragmentsCredited} Gold Fragments');
  }

  Future<void> _buy(FragmentPack pack) async {
    final details = _products[pack.productId];
    if (details == null) {
      _snack('This pack is not available in the store yet');
      return;
    }
    setState(() => _busyProductId = pack.productId);
    try {
      final started = await _store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started && mounted) {
        _snack('Could not start the purchase');
      }
    } catch (_) {
      if (mounted) _snack('Purchase failed. Try again.');
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final packs = _catalog?.packs ?? const <FragmentPack>[];
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Gold Fragments', icon: Icons.toll_outlined),
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
              if (_wallet != null) ...[
                _WalletLine(result: _wallet!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                AppChromeSection(
                  title: 'Fragment packs',
                  child: Text(
                    _error!,
                    style: context.appTypography.body.copyWith(
                      color: AppChrome.onSurfaceMuted,
                    ),
                  ),
                )
              else ...[
                if (!_nativeStore)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Buy Gold Fragments in the iOS or Android app.',
                      style: context.appTypography.body.copyWith(
                        color: AppChrome.onSurfaceMuted,
                      ),
                    ),
                  )
                else if (!_storeReady)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'The store is not available on this device.',
                      style: context.appTypography.body.copyWith(
                        color: AppChrome.onSurfaceMuted,
                      ),
                    ),
                  ),
                for (final pack in packs) ...[
                  _PackCard(
                    pack: pack,
                    storePrice: _products[pack.productId]?.price,
                    busy: _busyProductId == pack.productId,
                    enabled: _nativeStore &&
                        _storeReady &&
                        _products.containsKey(pack.productId) &&
                        _busyProductId == null,
                    onBuy: () => _buy(pack),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletLine extends StatelessWidget {
  const _WalletLine({required this.result});

  final FragmentPurchaseResult result;

  @override
  Widget build(BuildContext context) {
    return AppChromeSection(
      title: 'Your wallet',
      icon: Icons.account_balance_wallet_outlined,
      goldFrame: true,
      child: Text(
        '${result.goldArcori} Gold Arcori · ${result.goldFragments} fragments',
        style: context.appTypography.body.copyWith(color: AppChrome.onSurface),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.storePrice,
    required this.busy,
    required this.enabled,
    required this.onBuy,
  });

  final FragmentPack pack;
  final String? storePrice;
  final bool busy;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final price = (storePrice != null && storePrice!.isNotEmpty)
        ? storePrice!
        : pack.priceLabel;
    return AppChromeSection(
      title: pack.label,
      mark: const EconomyIcon(EconomyMark.fragment, size: 28),
      goldFrame: pack.isPopular,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pack.description,
            style: context.appTypography.body.copyWith(
              color: AppChrome.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: enabled ? onBuy : null,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(price.isEmpty ? 'Buy' : 'Buy $price'),
          ),
        ],
      ),
    );
  }
}
