import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/http/media_url.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../kin/kin_backgrounds.dart';
import '../../kin/kin_models.dart';
import '../../kin/kin_notifier.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../../match/widgets/arcori_palette.dart';
import '../avari_models.dart';
import '../avari_notifier.dart';
import '../widgets/inventory_face_chip.dart';
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
    final body = context.appTypography.body.copyWith(
      color: AppChrome.onSurface,
    );
    final bodySmall = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurfaceMuted,
    );

    Widget gapSection(Widget section) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: section,
        );

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
                      child: _IdentityAvatar(avatarUrl: identity.avatarUrl),
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
                    Text(identity.title, style: muted),
                  ],
                ),
              ),
              AppSpacing.gapMd,
              _KeyValue('Gold Arcori', '${profile.economy.goldArcori}'),
              _KeyValue(
                'Gold Fragments',
                '${profile.economy.goldFragments} of 4 toward next Gold Arcori',
              ),
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Titles',
          child: Text(
            profile.titles.isEmpty ? 'None yet' : profile.titles.join(' · '),
            style: body,
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Achievements',
          actionLabel: 'View',
          onAction: () => Nav.push(context, AppPaths.achievements),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Catalog unlocks from matches — separate from titles.',
                style: bodySmall,
              ),
              AppSpacing.gapSm,
              OutlinedButton(
                onPressed: () => Nav.push(context, AppPaths.achievements),
                child: const Text('View Achievements'),
              ),
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Kin',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile.kin != null) ...[
                Center(
                  child: ArcoriCylinder(
                    look: ArcoriLook(
                      designId: profile.kin!.genesisDesignId,
                      colorHex: profile.kin!.color,
                    ),
                    size: 200,
                    face: KinSceneStack(
                      lottieUrl: profile.kin!.lottieUrl,
                      file: (profile.kin!.lottieUrl == null ||
                              profile.kin!.lottieUrl!.isEmpty)
                          ? localKin.lottieFile
                          : null,
                      scene: KinBackgroundScene.fromClaimJson(
                        profile.kin!.background,
                      ),
                    ),
                  ),
                ),
                AppSpacing.gapSm,
                Text(
                  profile.kin!.chosenName,
                  style: body,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXxs,
                Text(
                  profile.kin!.masteryOverMintReach,
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                AppSpacing.gapXxs,
                Text(
                  [
                    profile.kin!.subtheme,
                    if (profile.kin!.regionCode != null)
                      profile.kin!.regionCode!,
                    if (profile.kin!.series != null) profile.kin!.series!,
                    if (profile.kin!.generationRoman != null)
                      'Gen ${profile.kin!.generationRoman}',
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                AppSpacing.gapXxs,
                Text(
                  profile.kin!.genesisDesignId,
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ] else if (localDraft != null) ...[
                _LocalKinDisc(localKin: localKin),
                AppSpacing.gapSm,
                Text(
                  localDraft.displayName,
                  style: body,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXxs,
                Text('0/500', textAlign: TextAlign.center, style: muted),
                AppSpacing.gapXxs,
                Text(
                  'Local draft ${localDraft.serial} · base ${localDraft.kinSerial}',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ] else
                Text('Not claimed yet', style: bodySmall),
              if (profile.kin == null) ...[
                AppSpacing.gapSm,
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () => Nav.push(context, AppPaths.kinTypes),
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
          title: 'Stats',
          child: Column(
            children: [
              _KeyValue('Matches', '${profile.stats.matchesPlayed}'),
              _KeyValue('Flips', '${profile.stats.flips}'),
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Mastery Value',
          goldFrame: true,
          child: Column(
            children: [
              _KeyValue('Value', '${profile.mastery.masteryValue}'),
              _KeyValue('Standing', profile.mastery.masteryValueLabel),
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Trove',
          actionLabel: 'Open',
          onAction: () => Nav.push(context, AppPaths.trove),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Minted Legacy pieces live in your Trove — not circulating play stock.',
                style: bodySmall,
              ),
              AppSpacing.gapSm,
              OutlinedButton(
                onPressed: () => Nav.push(context, AppPaths.trove),
                child: const Text('Open Trove'),
              ),
            ],
          ),
        ),
      ),
      gapSection(
        AppChromeSection(
          title: 'Arcori',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Circulating designs you can play — mastery / mint reach per design.',
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
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final item in items)
                        InventoryFaceChip(
                          item: item,
                          lottieFile: (profile.kin == null &&
                                  draftId.isNotEmpty &&
                                  item.designId == draftId)
                              ? localKin.lottieFile
                              : null,
                        ),
                    ],
                  );
                },
              ),
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

/// Kin first in Arcori wrap; uses claimed Kin, else local draft chip.
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

  return List<AvariInventoryItem>.from(profile.access);
}

class _LocalKinDisc extends ConsumerWidget {
  const _LocalKinDisc({required this.localKin});

  final KinActiveSaveState localKin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = localKin.draft;
    if (draft == null) return const SizedBox.shrink();
    final bgCatalog =
        ref.watch(kinBackgroundCatalogProvider).asData?.value ??
            KinBackgroundCatalog.empty;
    final bg = bgCatalog.byId(draft.backgroundId);
    return Center(
      child: ArcoriCylinder(
        look: ArcoriLook(
          designId: draft.kinSerial,
          colorHex: draft.colorHex,
        ),
        size: 200,
        face: KinSceneStack(
          file: localKin.lottieFile,
          backgroundColor: bg?.isColor == true
              ? parseCatalogColor(bg!.colorHex)
              : null,
          backgroundImageUrl:
              bg?.isImage == true ? bg!.imageUrl : null,
        ),
      ),
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(avatarUrl);
    return ClipOval(
      child: ColoredBox(
        color: AppChrome.fieldFill,
        child: url.isEmpty
            ? Icon(
                Icons.person_outline,
                size: AppSpacing.xxl,
                color: AppChrome.onSurfaceMuted,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_outline,
                  size: AppSpacing.xxl,
                  color: AppChrome.onSurfaceMuted,
                ),
              ),
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
