import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/http/media_url.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
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

class _AvariProfileScreenState extends ConsumerState<AvariProfileScreen> {
  static const double _avatarSize = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated) {
        ref.read(avariProfileProvider.notifier).load(force: true);
      }
      ref.read(kinActiveSaveProvider.notifier).refresh();
    });
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
        ref.read(avariProfileProvider.notifier).load(force: true);
      }
    });

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Avari', icon: Icons.person_outline),
      ],
      child: !auth.isAuthenticated && !auth.isBootstrapping
          ? Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign in to view your Avari profile',
                      style: context.appTypography.body,
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapMd,
                    FilledButton(
                      onPressed: () => Nav.push(context, AppPaths.account),
                      child: const Text('Open Account'),
                    ),
                  ],
                ),
              ),
            )
          : state.isLoading && state.profile == null
              ? const Center(child: CircularProgressIndicator())
              : state.errorMessage != null && state.profile == null
                  ? Center(
                      child: Padding(
                        padding: AppSpacing.screenPadding,
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
                              onPressed: () => ref
                                  .read(avariProfileProvider.notifier)
                                  .load(force: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
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
                        padding: AppSpacing.screenPadding,
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
    );
  }

  List<Widget> _profileBody(
    BuildContext context,
    AvariProfile profile,
    KinActiveSaveState localKin,
  ) {
    final identity = profile.identity;
    final scheme = context.appColorScheme;
    final localDraft = localKin.draft;
    return [
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
              style: context.appTypography.h3,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapXxs,
            Text(
              identity.title,
              style: context.appTypography.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      AppSpacing.gapLg,
      _SectionTitle(text: 'Wallet'),
      Text(
        '4 Gold Fragments = 1 Gold Arcori',
        style: context.appTypography.bodySmall,
      ),
      AppSpacing.gapSm,
      _KeyValue('Gold Arcori', '${profile.economy.goldArcori}'),
      _KeyValue('Gold Fragments', '${profile.economy.goldFragments}'),
      AppSpacing.gapMd,
      _SectionTitle(text: 'Rank & XP'),
      _KeyValue('Level', '${profile.rank.level}'),
      _KeyValue('XP', '${profile.rank.xp}'),
      if (profile.rank.label != null && profile.rank.label!.isNotEmpty)
        _KeyValue('Rank', profile.rank.label!),
      AppSpacing.gapMd,
      _SectionTitle(text: 'Titles'),
      Text(
        profile.titles.isEmpty ? 'None yet' : profile.titles.join(' · '),
        style: context.appTypography.body,
      ),
      AppSpacing.gapMd,
      _SectionTitle(text: 'Kin'),
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
              scene: KinBackgroundScene.fromClaimJson(profile.kin!.background),
            ),
          ),
        ),
        AppSpacing.gapSm,
        Text(
          profile.kin!.chosenName,
          style: context.appTypography.body,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXxs,
        Text(
          profile.kin!.masteryOverMintReach,
          textAlign: TextAlign.center,
          style: context.appTypography.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapXxs,
        Text(
          [
            profile.kin!.subtheme,
            if (profile.kin!.regionCode != null) profile.kin!.regionCode!,
            if (profile.kin!.series != null) profile.kin!.series!,
            if (profile.kin!.generationRoman != null)
              'Gen ${profile.kin!.generationRoman}',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: context.appTypography.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapXxs,
        Text(
          profile.kin!.genesisDesignId,
          textAlign: TextAlign.center,
          style: context.appTypography.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ] else if (localDraft != null) ...[
        _LocalKinDisc(localKin: localKin),
        AppSpacing.gapSm,
        Text(
          localDraft.displayName,
          style: context.appTypography.body,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXxs,
        Text(
          '0/500',
          textAlign: TextAlign.center,
          style: context.appTypography.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapXxs,
        Text(
          'Local draft ${localDraft.serial} · base ${localDraft.kinSerial}',
          textAlign: TextAlign.center,
          style: context.appTypography.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ] else
        Text(
          'Not claimed yet',
          style: context.appTypography.bodyMuted,
        ),
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
      AppSpacing.gapMd,
      _SectionTitle(text: 'Stats'),
      _KeyValue('Matches', '${profile.stats.matchesPlayed}'),
      _KeyValue('Wins', '${profile.stats.wins}'),
      _KeyValue('Flips', '${profile.stats.flips}'),
      AppSpacing.gapMd,
      _SectionTitle(text: 'Arcori'),
      Text(
        'Circulating designs you can play — mastery / mint reach per design.',
        style: context.appTypography.bodySmall,
      ),
      AppSpacing.gapSm,
      Builder(
        builder: (context) {
          final items = _arcoriAccessWithKinFirst(
            profile,
            localDraft: localDraft,
          );
          if (items.isEmpty) {
            return Text('None yet', style: context.appTypography.bodyMuted);
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
      AppSpacing.gapMd,
      _SectionTitle(text: 'Slammers'),
      Text(
        'Slammers you own — Game Controls equips from this list.',
        style: context.appTypography.bodySmall,
      ),
      AppSpacing.gapSm,
      if (profile.slammers.isEmpty)
        Text('None yet', style: context.appTypography.bodyMuted)
      else
        for (final item in profile.slammers) ...[
          SlammerInventoryTile(item: item),
          AppSpacing.gapSm,
        ],
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
    final scheme = context.appColorScheme;
    return ClipOval(
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: url.isEmpty
            ? Icon(
                Icons.person_outline,
                size: AppSpacing.xxl,
                color: scheme.onSurfaceVariant,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_outline,
                  size: AppSpacing.xxl,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: context.appTypography.title),
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
                color: context.appColorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: context.appTypography.body),
        ],
      ),
    );
  }
}
