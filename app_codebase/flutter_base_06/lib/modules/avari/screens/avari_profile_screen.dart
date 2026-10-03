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
import '../../kin/kin_models.dart';
import '../../kin/kin_notifier.dart';
import '../avari_models.dart';
import '../avari_notifier.dart';
import '../widgets/inventory_face_chip.dart';
import '../widgets/profile_face_avatar.dart';
import '../widgets/slammer_inventory_tile.dart';

class AvariProfileScreen extends ConsumerStatefulWidget {
  const AvariProfileScreen({super.key});

  @override
  ConsumerState<AvariProfileScreen> createState() => _AvariProfileScreenState();
}

class _AvariProfileScreenState extends ConsumerState<AvariProfileScreen>
    with RouteAware {
  static const double _avatarSize = 120;
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
        AppBarTitle(text: 'Avari', icon: Icons.person_outline),
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
                      onPressed: () => Nav.push(context, AppPaths.account),
                      child: const Text('Open Account'),
                    ),
                  ],
                ),
              )
            : state.isLoading && state.profile == null
                ? const AppChromeCentered(
                    child: CircularProgressIndicator(),
                  )
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
                          await ref
                              .read(kinActiveSaveProvider.notifier)
                              .refresh();
                        },
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppChromePage.topClearance(context) +
                                AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xxl,
                          ),
                          children: [
                            if (state.profile != null)
                              ..._profileBody(
                                context,
                                state.profile!,
                                localKin,
                              ),
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
    final localDraft = localKin.draft;
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

    final titlesLine = profile.titles.isEmpty
        ? 'None yet'
        : profile.titles.join(' · ');

    return [
      gapSection(
        AppChromeSection(
          title: 'Avari',
          goldFrame: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: _avatarSize,
                      height: _avatarSize,
                      child: ProfileFaceAvatar(
                        avatarUrl: identity.avatarUrl,
                        size: _avatarSize,
                      ),
                    ),
                    AppSpacing.gapSm,
                    Text(
                      identity.displayName,
                      style: context.appTypography.h3.copyWith(
                        color: AppChrome.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      titlesLine,
                      style: muted,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapMd,
              _KeyValue('Gold Arcori', '${profile.economy.goldArcori}'),
              _KeyValue(
                'Gold Fragments',
                '${profile.economy.goldFragments} of 4 toward next Gold Arcori',
              ),
              AppSpacing.gapSm,
              _KeyValue('Matches', '${profile.stats.matchesPlayed}'),
              _KeyValue('Flips', '${profile.stats.flips}'),
              AppSpacing.gapMd,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Nav.push(context, AppPaths.achievements),
                      child: const Text('Achievements'),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: OutlinedButton(
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
          title: 'Arcori',
          goldFrame: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KeyValue('Mastery Value', '${profile.mastery.masteryValue}'),
              _KeyValue('Standing', profile.mastery.masteryValueLabel),
              AppSpacing.gapSm,
              Text(
                'Circulating designs you can play — Kin first, then by mastery.',
                style: bodySmall,
              ),
              AppSpacing.gapSm,
              Builder(
                builder: (context) {
                  final items = _arcoriAccessWithKinFirst(
                    profile,
                    localDraft: localDraft,
                  );
                  if (items.isEmpty) {
                    return Text('None yet', style: bodySmall);
                  }
                  final draftId = localDraft?.serial.trim() ?? '';
                  return _ArcoriThreeRowScroll(
                    items: items,
                    lottieFileFor: (item) {
                      if (profile.kin == null &&
                          draftId.isNotEmpty &&
                          item.designId == draftId) {
                        return localKin.lottieFile;
                      }
                      return null;
                    },
                    onOpen: (item) {
                      final id = item.designId.trim();
                      if (id.isEmpty) return;
                      // Draft Kin is not a catalog design yet.
                      if (item.source == 'kin-draft') {
                        final kinSerial =
                            localDraft?.kinSerial.trim() ?? '';
                        if (kinSerial.isEmpty) {
                          Nav.push(context, AppPaths.kinTypes);
                          return;
                        }
                        Nav.push(
                          context,
                          Uri(
                            path: AppPaths.kinCustomize,
                            queryParameters: {
                              'kin': kinSerial,
                              'resume': '1',
                            },
                          ).toString(),
                        );
                        return;
                      }
                      Nav.push(
                        context,
                        '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(id)}',
                      );
                    },
                  );
                },
              ),
              if (profile.kin == null) ...[
                AppSpacing.gapMd,
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () {
                      if (localDraft != null &&
                          localDraft.kinSerial.trim().isNotEmpty) {
                        Nav.push(
                          context,
                          Uri(
                            path: AppPaths.kinCustomize,
                            queryParameters: {
                              'kin': localDraft.kinSerial.trim(),
                              'resume': '1',
                            },
                          ).toString(),
                        );
                      } else {
                        Nav.push(context, AppPaths.kinTypes);
                      }
                    },
                    child: Text(
                      localDraft == null ? 'Create Kin' : 'Continue Kin draft',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Slammers',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Slammers you own — Game Controls equips from this list.',
                style: bodySmall,
              ),
              AppSpacing.gapSm,
              if (profile.slammers.isEmpty)
                Text('None yet', style: bodySmall)
              else
                for (final item in profile.slammers) ...[
                  SlammerInventoryTile(item: item),
                  AppSpacing.gapSm,
                ],
            ],
          ),
        ),
      ),
    ];
  }
}

void _sortByMasteryDesc(List<AvariInventoryItem> items) {
  items.sort((a, b) {
    final byMastery = b.masteryPoints.compareTo(a.masteryPoints);
    if (byMastery != 0) return byMastery;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
}

/// Kin first; remaining circulating access sorted mastery high → low.
List<AvariInventoryItem> _arcoriAccessWithKinFirst(
  AvariProfile profile, {
  KinSaveDraft? localDraft,
}) {
  final kin = profile.kin;
  final kinId = kin?.genesisDesignId.trim() ?? '';
  if (kin != null && kinId.isNotEmpty) {
    AvariInventoryItem? fromAccess;
    final rest = <AvariInventoryItem>[];
    for (final item in profile.access) {
      if (item.designId == kinId) {
        fromAccess ??= item;
      } else {
        rest.add(item);
      }
    }
    _sortByMasteryDesc(rest);
    final kinItem = fromAccess ??
        AvariInventoryItem(
          designId: kinId,
          displayName: kin.chosenName.trim().isNotEmpty
              ? kin.chosenName.trim()
              : kinId,
          lottieUrl: kin.lottieUrl,
          faceMedia: 'lottie',
          background: kin.background,
          color: kin.color,
          source: 'kin',
          masteryPoints: kin.masteryPoints,
          mintReach: kin.mintReach ?? 500,
        );
    // Ensure Lottie face even if access row omitted it.
    if (!kinItem.hasLottieFace &&
        (kin.lottieUrl != null && kin.lottieUrl!.trim().isNotEmpty)) {
      return [
        AvariInventoryItem(
          designId: kinItem.designId,
          displayName: kinItem.displayName,
          imageUrl: kinItem.imageUrl,
          lottieUrl: kin.lottieUrl,
          faceMedia: 'lottie',
          background: kinItem.background ?? kin.background,
          color: kinItem.color ?? kin.color,
          source: kinItem.source ?? 'kin',
          masteryPoints: kinItem.masteryPoints,
          mintReach: kinItem.mintReach ?? kin.mintReach ?? 500,
        ),
        ...rest,
      ];
    }
    return [kinItem, ...rest];
  }

  if (localDraft != null) {
    final draftId = localDraft.serial.trim().isNotEmpty
        ? localDraft.serial.trim()
        : localDraft.kinSerial.trim();
    if (draftId.isNotEmpty) {
      final rest = profile.access
          .where((i) => i.designId != draftId)
          .toList();
      _sortByMasteryDesc(rest);
      return [
        AvariInventoryItem(
          designId: draftId,
          displayName: localDraft.displayName.trim().isNotEmpty
              ? localDraft.displayName.trim()
              : draftId,
          faceMedia: 'lottie',
          color: localDraft.colorHex,
          source: 'kin-draft',
          masteryPoints: 0,
          mintReach: 500,
        ),
        ...rest,
      ];
    }
  }

  final all = List<AvariInventoryItem>.from(profile.access);
  _sortByMasteryDesc(all);
  return all;
}

/// Three-row catalog: order reads left→right per row, then next row; scroll sideways.
class _ArcoriThreeRowScroll extends StatelessWidget {
  const _ArcoriThreeRowScroll({
    required this.items,
    required this.lottieFileFor,
    required this.onOpen,
  });

  static const int _rows = 3;

  final List<AvariInventoryItem> items;
  final File? Function(AvariInventoryItem item) lottieFileFor;
  final ValueChanged<AvariInventoryItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final columnCount = (items.length / _rows).ceil().clamp(1, 9999);
    final height = InventoryFaceChip.chipHeight * _rows +
        AppSpacing.sm * (_rows - 1);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: columnCount,
        separatorBuilder: (_, __) => AppSpacing.gapSm,
        itemBuilder: (context, col) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < _rows; row++) ...[
                if (row > 0) AppSpacing.gapSm,
                Builder(
                  builder: (context) {
                    // Row-major: fill across each row left→right, then next row.
                    final index = row * columnCount + col;
                    if (index >= items.length) {
                      return SizedBox(
                        width: InventoryFaceChip.chipWidth,
                        height: InventoryFaceChip.chipHeight,
                      );
                    }
                    final item = items[index];
                    return InventoryFaceChip(
                      item: item,
                      lottieFile: lottieFileFor(item),
                      onTap: () => onOpen(item),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.appTypography.caption.copyWith(
                color: AppChrome.onSurfaceMuted,
              ),
            ),
          ),
          Text(
            value,
            style: context.appTypography.body.copyWith(
              color: AppChrome.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
