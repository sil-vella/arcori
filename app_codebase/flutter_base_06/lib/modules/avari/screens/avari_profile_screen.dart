import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../../../core/widgets/economy_icon.dart';
import '../../kin/kin_backgrounds.dart';
import '../../kin/kin_models.dart';
import '../../kin/kin_notifier.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../../market/market_api.dart';
import '../../market/market_spend_modal.dart';
import '../../play/game_controls_prefs.dart';
import '../../match/input/slam_resolver.dart' show ensureGen001DesignId;
import '../avari_models.dart';
import '../avari_notifier.dart';
import '../widgets/arcori_container_bank.dart';
import '../widgets/slammer_inventory_tile.dart';

String _arcoriCanisterCountLabel(int canisters) {
  final noun = canisters == 1 ? 'Canister' : 'Canisters';
  return '$canisters Arcori $noun';
}

class AvariProfileScreen extends ConsumerStatefulWidget {
  const AvariProfileScreen({super.key});

  @override
  ConsumerState<AvariProfileScreen> createState() => _AvariProfileScreenState();
}

class _AvariProfileScreenState extends ConsumerState<AvariProfileScreen>
    with RouteAware {
  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    // First paint before RouteAware.didPush — covers cold open.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
      _routeSubscribed = false;
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returned here after Play / Kin / etc. were popped — reload Arcori stats.
    _refreshProfile();
  }

  void _refreshProfile() {
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) {
      unawaited(ref.read(avariProfileProvider.notifier).load(force: true));
    }
    unawaited(ref.read(kinActiveSaveProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(avariProfileProvider);
    final localKin = ref.watch(kinActiveSaveProvider);

    ref.listen(authProvider, (previous, next) {
      if (!next.isBootstrapping &&
          next.isAuthenticated &&
          previous?.isAuthenticated != true) {
        _refreshProfile();
      }
    });

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Avari', iconAsset: AppMarks.avari),
      ],
      child: AppChromePage(
        child: !auth.isAuthenticated && !auth.isBootstrapping
            ? AppChromeCentered(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign in to view your Avari profile',
                      style: context.appTypography.body.copyWith(
                        color: AppChrome.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapMd,
                    FilledButton(
                      style: context.appButtons.primary.filled,
                      onPressed: () => Nav.push(context, AppPaths.account),
                      child: const Text('Open Account'),
                    ),
                  ],
                ),
              )
            : state.isLoading && state.profile == null
            ? const AppChromeCentered(child: CircularProgressIndicator())
            : state.errorMessage != null && state.profile == null
            ? AppChromeCentered(
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
                      style: context.appButtons.primary.filled,
                      onPressed: _refreshProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(avariProfileProvider.notifier)
                      .load(force: true);
                  await ref.read(kinActiveSaveProvider.notifier).refresh();
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppChromePage.topClearance(context) + AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  children: [
                    if (state.profile != null)
                      ..._profileBody(context, state.profile!, localKin),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _profileBody(
    BuildContext context,
    AvariProfile profile,
    KinActiveSaveState localKin,
  ) {
    final identity = profile.identity;
    final muted = context.appTypography.caption.copyWith(
      color: AppChrome.onSurfaceMuted,
    );
    final bodySmall = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurfaceMuted,
    );

    Widget gapSection(Widget section) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: section,
    );

    final circulating = ArcoriContainerBank.countTowardContainers(
      profile.access,
    );
    final canisters = circulating ~/ ArcoriContainerBank.perContainer + 1;
    final titlesLine = profile.titles.isEmpty
        ? 'None yet'
        : profile.titles.join(' · ');
    final kin = profile.kin;
    final hasKin = kin != null && kin.genesisDesignId.trim().isNotEmpty;
    final draft = localKin.draft;

    void openCatalogDesign(String designId) {
      final id = designId.trim();
      if (id.isEmpty) return;
      Nav.push(
        context,
        '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(id)}',
      );
    }

    Future<void> chargeSlammer(AvariInventoryItem item) async {
      final token = ref.read(authProvider).accessToken?.trim() ?? '';
      if (token.isEmpty || item.designId.isEmpty) return;
      final price = item.rechargePriceGoldArcori ?? 4;
      final added = item.rechargeCharges ?? 100;
      final ok = await showMarketSpendModal(
        context,
        title: 'Charge slammer',
        confirmBody:
            'Add $added uses to ${item.displayName} for $price Gold Arcori.',
        confirmLabel: 'Charge · $price Gold Arcori',
        send: () => MarketApiClient().recharge(
          accessToken: token,
          designId: item.designId,
        ),
        successBody: (result) =>
            'Done — ${result.chargesRemaining} uses · '
            '${result.goldArcori} Gold Arcori left',
      );
      if (!ok || !context.mounted) return;
      await ref.read(avariProfileProvider.notifier).load(force: true);
    }

    return [
      gapSection(
        AppChromeSection(
          title: 'Avari',
          mark: const AppMarkIcon(AppMarks.avari),
          goldFrame: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    _KinPortrait(
                      kin: hasKin ? kin : null,
                      draft: hasKin ? null : draft,
                      lottieFile: hasKin ? null : localKin.lottieFile,
                      onOpenDesign: openCatalogDesign,
                      onOpenDraft: () => _openKinDraft(context, localKin),
                    ),
                    AppSpacing.gapSm,
                    Text(
                      identity.displayName,
                      style: context.appTypography.h3.copyWith(
                        color: AppChrome.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (hasKin)
                      ..._kinDetailLines(context, kin, identity.displayName),
                    if (!hasKin && draft != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          _draftKinLabel(draft),
                          textAlign: TextAlign.center,
                          style: context.appTypography.caption.copyWith(
                            color: AppChrome.accentGold,
                          ),
                        ),
                      ),
                    AppSpacing.gapXxs,
                    Text(
                      '${profile.mastery.masteryValue}',
                      textAlign: TextAlign.center,
                      style: context.appTypography.h1.copyWith(
                        color: AppChrome.accentGold,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Mastery · ${profile.mastery.masteryValueLabel}',
                      textAlign: TextAlign.center,
                      style: context.appTypography.caption.copyWith(
                        color: AppChrome.accentGold,
                      ),
                    ),
                    AppSpacing.gapXxs,
                    Text(titlesLine, style: muted, textAlign: TextAlign.center),
                    if (!hasKin) ...[
                      AppSpacing.gapSm,
                      FilledButton(
                        style: context.appButtons.primary.filled,
                        onPressed: () => _openKinDraft(context, localKin),
                        child: Text(
                          draft == null ? 'Create Kin' : 'Continue Kin draft',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppSpacing.gapMd,
              _AvariWallet(
                goldArcori: profile.economy.goldArcori,
                goldFragments: profile.economy.goldFragments,
                matches: profile.stats.matchesPlayed,
                flips: profile.stats.flips,
              ),
              AppSpacing.gapMd,
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: context.appButtons.primary.filled,
                      onPressed: () => Nav.push(context, AppPaths.achievements),
                      child: const Text('Achievements'),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: FilledButton(
                      style: context.appButtons.primary.filled,
                      onPressed: () => Nav.push(context, AppPaths.trove),
                      child: const Text('Trove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Slammers',
          mark: const AppMarkIcon(AppMarks.slammers),
          goldFrame: true,
          background: const _SlammerCover(),
          child: profile.slammers.isEmpty
              ? _LeftHalf(child: Text('None yet', style: bodySmall))
              : _SlammerPager(
                  items: profile.slammers,
                  equippedId: ref.watch(gameControlsProvider).equippedSlammerId,
                  onOpen: (item) => openCatalogDesign(item.designId),
                  onEquip: (item) {
                    unawaited(
                      ref
                          .read(gameControlsProvider.notifier)
                          .setEquippedSlammerId(item.designId),
                    );
                  },
                  onCharge: (item) {
                    unawaited(chargeSlammer(item));
                  },
                ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Arcori',
          mark: const AppMarkIcon(AppMarks.arcori),
          goldFrame: true,
          background: const _ArcoriCover(),
          trailing: Text(
            '$circulating',
            style: context.appTypography.title.copyWith(
              color: AppChrome.accentGold,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Circulating Arcori you have mastered.',
                      style: bodySmall,
                    ),
                  ),
                  AppSpacing.gapSm,
                  FilledButton(
                    style: context.appButtons.primary.filled,
                    onPressed: () =>
                        Nav.push(context, AppPaths.avariCirculating),
                    child: const Text('Browse'),
                  ),
                ],
              ),
              AppSpacing.gapXxs,
              Text(
                _arcoriCanisterCountLabel(canisters),
                style: context.appTypography.h2.copyWith(
                  color: AppChrome.accentGold,
                  height: 1.1,
                ),
              ),
              AppSpacing.gapSm,
              ArcoriContainerBank(count: circulating),
            ],
          ),
        ),
      ),
    ];
  }
}

/// One owned slammer at a time. Swipe, or use the arrows. Equip uses Game Controls.
class _SlammerPager extends StatefulWidget {
  const _SlammerPager({
    required this.items,
    required this.equippedId,
    required this.onOpen,
    required this.onEquip,
    required this.onCharge,
  });

  final List<AvariInventoryItem> items;
  final String equippedId;
  final ValueChanged<AvariInventoryItem> onOpen;
  final ValueChanged<AvariInventoryItem> onEquip;
  final ValueChanged<AvariInventoryItem> onCharge;

  @override
  State<_SlammerPager> createState() => _SlammerPagerState();
}

class _SlammerPagerState extends State<_SlammerPager> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant _SlammerPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final equippedChanged = !_sameSlammer(
      widget.equippedId,
      oldWidget.equippedId,
    );
    if (equippedChanged && _index != 0) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
    final last = widget.items.length - 1;
    if (last < 0) return;
    if (_index > last) {
      _index = last;
      if (_controller.hasClients) _controller.jumpToPage(last);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int next) {
    if (next < 0 || next >= _ordered.length) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  List<AvariInventoryItem> get _ordered {
    final items = widget.items;
    if (items.length < 2) return items;
    final equippedAt = items.indexWhere(
      (item) => _sameSlammer(item.designId, widget.equippedId),
    );
    if (equippedAt <= 0) return items;
    return [
      items[equippedAt],
      ...items.take(equippedAt),
      ...items.skip(equippedAt + 1),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _ordered;
    final count = items.length;
    final gold = AppChrome.accentGold;
    final current = items[_index];
    final equipped = _sameSlammer(current.designId, widget.equippedId);
    return Column(
      children: [
        SizedBox(
          height: SlammerInventoryTile.pageHeight,
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.none,
            itemCount: count,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final item = items[index];
              return SlammerInventoryTile(
                item: item,
                onTap: () => widget.onOpen(item),
                onCharge: item.permanent == true
                    ? null
                    : () => widget.onCharge(item),
              );
            },
          ),
        ),
        AppSpacing.gapSm,
        FilledButton(
          style: equipped
              ? context.appButtons.primary.tonal
              : context.appButtons.primary.filled,
          onPressed: current.designId.isEmpty || equipped
              ? null
              : () => widget.onEquip(current),
          child: Text(equipped ? 'Equipped' : 'Equip'),
        ),
        if (count > 1) ...[
          AppSpacing.gapXxs,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _index > 0 ? () => _go(_index - 1) : null,
                icon: const Icon(Icons.chevron_left),
                color: gold,
                disabledColor: AppChrome.onSurfaceMuted,
              ),
              Text(
                '${_index + 1} / $count',
                style: context.appTypography.caption.copyWith(
                  color: AppChrome.onSurfaceMuted,
                ),
              ),
              IconButton(
                onPressed: _index < count - 1 ? () => _go(_index + 1) : null,
                icon: const Icon(Icons.chevron_right),
                color: gold,
                disabledColor: AppChrome.onSurfaceMuted,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

bool _sameSlammer(String designId, String equippedId) {
  if (designId.isEmpty || equippedId.isEmpty) return false;
  if (designId == equippedId) return true;
  return ensureGen001DesignId(designId) == equippedId;
}

class _LeftHalf extends StatelessWidget {
  const _LeftHalf({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

class _ArcoriCover extends StatelessWidget {
  const _ArcoriCover();

  static const String _asset =
      'assets/images/backgrounds/029_arcori_sanctuary_desktop_21x9.webp';

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => ColoredBox(color: AppChrome.fieldFill),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ink.withValues(alpha: 0.82),
                ink.withValues(alpha: 0.62),
                ink.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlammerCover extends StatelessWidget {
  const _SlammerCover();

  static const String _kSlammerCardBackground =
      'assets/images/backgrounds/slammer_card_back.webp';

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _kSlammerCardBackground,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => ColoredBox(color: AppChrome.fieldFill),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                ink.withValues(alpha: 0.78),
                ink.withValues(alpha: 0.5),
                ink.withValues(alpha: 0.62),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _openKinDraft(BuildContext context, KinActiveSaveState localKin) {
  final serial = localKin.draft?.kinSerial.trim() ?? '';
  if (serial.isEmpty) {
    Nav.push(context, AppPaths.kinTypes);
    return;
  }
  Nav.push(
    context,
    Uri(
      path: AppPaths.kinCustomize,
      queryParameters: {'kin': serial, 'resume': '1'},
    ).toString(),
  );
}

String _draftKinLabel(KinSaveDraft draft) {
  final name = (draft.chosenName ?? draft.displayName).trim();
  return name.isEmpty ? 'Kin draft' : name;
}

/// Kin name and mastery under the username. Skips a name that matches the player.
List<Widget> _kinDetailLines(
  BuildContext context,
  AvariKin kin,
  String displayName,
) {
  final name = kin.chosenName.trim();
  final showName =
      name.isNotEmpty && name.toLowerCase() != displayName.trim().toLowerCase();
  final meta = <String>[
    if (kin.style.trim().isNotEmpty) kin.style.trim(),
    if ((kin.series ?? '').trim().isNotEmpty) kin.series!.trim(),
    if ((kin.generationRoman ?? '').trim().isNotEmpty)
      kin.generationRoman!.trim(),
  ].join(' · ');
  final gold = context.appTypography.caption.copyWith(
    color: AppChrome.accentGold,
  );
  final muted = context.appTypography.caption.copyWith(
    color: AppChrome.onSurfaceMuted,
  );
  return [
    AppSpacing.gapXxs,
    Text(
      showName
          ? '$name · ${kin.masteryOverMintReach}'
          : kin.masteryOverMintReach,
      textAlign: TextAlign.center,
      style: gold,
    ),
    if (meta.isNotEmpty) Text(meta, textAlign: TextAlign.center, style: muted),
  ];
}

/// Full Kin disc (rim, scene, face) in place of the profile picture.
class _KinPortrait extends StatelessWidget {
  const _KinPortrait({
    required this.kin,
    required this.draft,
    required this.lottieFile,
    required this.onOpenDesign,
    required this.onOpenDraft,
  });

  static const double _size = 128;

  final AvariKin? kin;
  final KinSaveDraft? draft;
  final File? lottieFile;
  final ValueChanged<String> onOpenDesign;
  final VoidCallback onOpenDraft;

  @override
  Widget build(BuildContext context) {
    final saved = kin;
    if (saved != null && saved.genesisDesignId.trim().isNotEmpty) {
      final id = saved.genesisDesignId.trim();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onOpenDesign(id),
        child: _disc(
          designId: id,
          colorHex: saved.color,
          face: KinSceneStack(
            lottieUrl: saved.lottieUrl,
            scene: KinBackgroundScene.fromClaimJson(saved.background),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final pending = draft;
    if (pending == null) return const SizedBox.shrink();
    final id = pending.serial.trim().isNotEmpty
        ? pending.serial.trim()
        : pending.kinSerial.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenDraft,
      child: _disc(
        designId: id.isEmpty ? 'kin-draft' : id,
        colorHex: pending.colorHex,
        face: KinSceneStack(
          file: lottieFile,
          scene: KinBackgroundScene.fromClaimJson(pending.background),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _disc({
    required String designId,
    required String? colorHex,
    required Widget face,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ArcoriCylinder(
        look: ArcoriLook(designId: designId, colorHex: colorHex),
        size: _size,
        face: face,
      ),
    );
  }
}

/// Gold column (fragments convert into Gold Arcori) beside matches and flips.
///
/// Four fragments convert to one Gold Arcori.
class _AvariWallet extends StatelessWidget {
  const _AvariWallet({
    required this.goldArcori,
    required this.goldFragments,
    required this.matches,
    required this.flips,
  });

  final int goldArcori;
  final int goldFragments;
  final int matches;
  final int flips;

  static const int _fragmentsPerArcori = 4;

  @override
  Widget build(BuildContext context) {
    final filled = goldFragments.clamp(0, _fragmentsPerArcori);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppChrome.fieldFill.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppChrome.panelBorderGold),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WalletSlot(
                      icon: const EconomyIcon(EconomyMark.goldArcori, size: 40),
                      amount: '$goldArcori',
                      label: 'Gold Arcori',
                    ),
                    AppSpacing.gapSm,
                    _WalletSlot(
                      icon: const EconomyIcon(EconomyMark.fragment, size: 40),
                      amount: '$goldFragments',
                      label: 'Fragments',
                      footer: Row(
                        children: [
                          for (var i = 0; i < _fragmentsPerArcori; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.xxs),
                            EconomyIcon(
                              EconomyMark.fragment,
                              size: 14,
                              opacity: i < filled ? 1 : 0.28,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppChrome.accentBronze.withValues(alpha: 0.45),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WalletSlot(
                      icon: const EconomyIcon(EconomyMark.match, size: 40),
                      amount: '$matches',
                      label: 'Matches',
                    ),
                    AppSpacing.gapSm,
                    _WalletSlot(
                      icon: const EconomyIcon(EconomyMark.flip, size: 40),
                      amount: '$flips',
                      label: 'Flips',
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

class _WalletSlot extends StatelessWidget {
  const _WalletSlot({
    required this.icon,
    required this.amount,
    required this.label,
    this.footer,
  });

  final Widget icon;
  final String amount;
  final String label;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 40, height: 40, child: icon),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.h3.copyWith(
                  color: AppChrome.accentGold,
                  height: 1,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.caption.copyWith(
                  color: AppChrome.onSurfaceMuted,
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                footer!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
