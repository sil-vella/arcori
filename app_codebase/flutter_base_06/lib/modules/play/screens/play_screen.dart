import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/errors/error_policy.dart';
import '../../../core/http/media_url.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../avari/avari_api.dart';
import '../../avari/avari_models.dart';
import '../../avari/avari_notifier.dart';
import '../../hub/hub_bottom_nav.dart';
import '../../match/widgets/arcori_image_prefetch.dart';
import '../../match/widgets/practice_match_surface.dart';
import '../../matchmaking/widgets/matchmaking_lobby_modal.dart';
import '../../special_events/active_window_picker_modal.dart';
import '../../special_events/high_mastery_picker_modal.dart';
import '../../special_events/special_event_picker_modal.dart';
import '../../special_events/special_events_api.dart';
import '../../special_events/special_events_models.dart';
import '../play_models.dart';
import '../play_notifier.dart';
import '../widgets/invite_setup_modal.dart';
import '../widgets/match_fee_confirm_modal.dart';
import '../widgets/play_failure_modal.dart';
import '../widgets/post_match_modal.dart';
import '../widgets/practice_loadout_modal.dart';

/// Play hub — start and end of the match pipeline.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  final _eventsApi = SpecialEventsApiClient();
  SpecialEventEntry? _featuredEvent;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _warmArcoriArt();
      await _loadFeaturedEvent();
    });
  }

  List<String> _artUrlsFor(AvariProfile? profile) {
    return collectArcoriArtUrls(
      extra: [
        if (profile != null) ...[
          ...profile.access.map((e) => e.imageUrl),
          ...profile.slammers.map((e) => e.imageUrl),
        ],
      ],
    );
  }

  Future<void> _warmArcoriArt() async {
    await ref.read(avariProfileProvider.notifier).load();
    if (!mounted) return;
    unawaited(
      precacheArcoriArt(
        context,
        _artUrlsFor(ref.read(avariProfileProvider).profile),
      ),
    );
  }

  Future<void> _loadFeaturedEvent() async {
    final token = ref.read(authProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) return;
    final outcome = await _eventsApi.fetchCatalog(accessToken: token);
    if (!mounted || !outcome.isSuccess || outcome.data == null) return;
    final events = outcome.data!.events;
    SpecialEventEntry? featured;
    for (final e in events) {
      if (e.homeFeatured && e.eligible) {
        featured = e;
        break;
      }
    }
    featured ??= () {
      for (final e in events) {
        if (e.eligible) return e;
      }
      return events.isNotEmpty ? events.first : null;
    }();
    setState(() => _featuredEvent = featured);
  }

  Future<void> _onMatchTypePressed(MatchType type) async {
    if (_starting) return;
    final notifier = ref.read(matchFlowProvider.notifier);
    if (!ref.read(matchFlowProvider).isIdle) return;

    setState(() => _starting = true);
    notifier.startPlay();

    try {
      PracticeLoadout? loadout;
      if (type == MatchType.practice) {
        loadout = await showPracticeLoadoutModal(context);
        if (!mounted) return;
        if (loadout == null) {
          await notifier.cancelSelection();
          return;
        }
      }

      if (type == MatchType.invite) {
        final setup = await showInviteSetupModal(context: context, ref: ref);
        if (!mounted) return;
        if (setup == null ||
            setup.inviteId.trim().isEmpty ||
            setup.invitedUserId.trim().isEmpty) {
          await notifier.cancelSelection();
          return;
        }
        await notifier.selectType(
          type,
          inviteId: setup.inviteId,
          invitedUserId: setup.invitedUserId,
        );
        return;
      }

      if (type == MatchType.specialEvent) {
        final event =
            await showSpecialEventPickerModal(context: context, ref: ref);
        if (!mounted) return;
        if (event == null || event.id.trim().isEmpty) {
          await notifier.cancelSelection();
          return;
        }

        List<String> arcoriIds = const [];
        if (event.requiresArcoriHardPick) {
          final AvariInventoryItem? picked;
          if (event.requiresActiveWindowPick) {
            picked = await showActiveWindowPickerModal(
              context: context,
              ref: ref,
            );
          } else {
            picked = await showHighMasteryPickerModal(
              context: context,
              ref: ref,
              minMasteryRatio: event.minMasteryRatio ?? 0.8,
            );
          }
          if (!mounted) return;
          if (picked == null || picked.designId.trim().isEmpty) {
            await notifier.cancelSelection();
            return;
          }
          arcoriIds = [picked.designId.trim()];
        }

        if (event.feeFragments > 0) {
          final confirmed = await showMatchFeeConfirmModal(
            context,
            feeFragments: event.feeFragments,
            matchLabel: event.name,
          );
          if (!mounted) return;
          if (!confirmed) {
            await notifier.cancelSelection();
            return;
          }
          final token = ref.read(authProvider).accessToken ?? '';
          if (token.isEmpty) {
            await notifier.cancelSelection();
            return;
          }
          final feeIntentId =
              'fee_${DateTime.now().toUtc().microsecondsSinceEpoch}_'
              '${Random().nextInt(1 << 32)}';
          final pay = await AvariApiClient().payMatchFee(
            accessToken: token,
            matchType: 'specialEvent',
            feeIntentId: feeIntentId,
            eventId: event.id,
          );
          if (!mounted) return;
          if (!pay.isSuccess) {
            final err = pay.error;
            if (err != null) {
              actionForApiError(err, isWebSocket: false);
            }
            await notifier.cancelSelection();
            return;
          }
          final paid = pay.data!;
          notifier.recordFeePaid(
            feeIntentId: feeIntentId,
            feeFragments: paid.feeFragments > 0
                ? paid.feeFragments
                : event.feeFragments,
            matchType: 'specialEvent',
          );
          unawaited(ref.read(avariProfileProvider.notifier).load(force: true));
        }
        await notifier.selectType(
          type,
          eventId: event.id,
          eventSubtype: event.subtype,
          arcoriIds: arcoriIds,
        );
        return;
      }

      await notifier.selectType(type, practiceLoadout: loadout);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(matchFlowProvider);
    final canSelect = flow.isIdle && flow.errorMessage == null && !_starting;

    ref.listen(avariProfileProvider, (prev, next) {
      if (next.profile == null) return;
      if (identical(prev?.profile, next.profile)) return;
      unawaited(
        precacheArcoriArt(
          context,
          _artUrlsFor(next.profile),
        ),
      );
    });

    ref.listen(matchFlowProvider, (prev, next) {
      final enteredOnlineLobby = next.phase == MatchFlowPhase.typeSetup &&
          (next.selectedType == MatchType.quickStart ||
              next.selectedType == MatchType.specialEvent ||
              next.selectedType == MatchType.invite) &&
          prev?.phase != MatchFlowPhase.typeSetup;
      if (enteredOnlineLobby && context.mounted) {
        unawaited(showMatchmakingLobbyModal(context, ref));
      }

      final enteredInMatch = next.phase == MatchFlowPhase.inMatch &&
          prev?.phase != MatchFlowPhase.inMatch;
      if (enteredInMatch && context.mounted) {
        // Let the lobby modal pop first (same-frame promote → inMatch race).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          unawaited(showPracticeMatchSurface(context, ref));
        });
      }

      final enteredPostMatch = next.phase == MatchFlowPhase.postMatch &&
          prev?.phase != MatchFlowPhase.postMatch;
      if (enteredPostMatch && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          unawaited(showPostMatchModal(context, ref));
        });
      }

      final error = next.errorMessage;
      if (error != null &&
          error.isNotEmpty &&
          error != prev?.errorMessage &&
          context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) return;
          await showPlayFailureModal(context, error);
          if (!context.mounted) return;
          ref.read(matchFlowProvider.notifier).clearError();
        });
      }
    });

    final featuredEvent = _featuredEvent;
    final featuredSubtitle = <MatchType, String>{
      for (final type in kPlayFeaturedTypes)
        type: type == MatchType.specialEvent && featuredEvent != null
            ? featuredEvent.name
            : type.shortBlurb,
    };

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Match', icon: Icons.sports_esports_outlined),
      ],
      bottomNavModuleId: hubSinkBottomNavModuleId,
      bottomNavItems: hubSinkBottomNavItems(context),
      child: AppChromePage(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppChromePage.topClearance(context) + AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Choose a game mode and enter the arena.',
              style: context.appTypography.bodyMuted.copyWith(
                color: AppChrome.onSurfaceMuted,
              ),
            ),
            AppSpacing.gapMd,
            if (!flow.isIdle) ...[
              Text(
                flow.phase.label,
                style: context.appTypography.bodyMuted.copyWith(
                  color: AppChrome.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
              if (flow.selectedType != null) ...[
                AppSpacing.gapXxs,
                Text(
                  flow.selectedType!.label,
                  style: context.appTypography.bodySmall.copyWith(
                    color: AppChrome.onSurfaceMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              AppSpacing.gapMd,
            ],
            AppChromeSection(
              title: 'Featured',
              icon: Icons.auto_awesome,
              goldFrame: true,
              background: const _FeaturedCover(),
              child: Column(
                children: [
                  for (var i = 0; i < kPlayFeaturedTypes.length; i++) ...[
                    if (i > 0) AppSpacing.gapSm,
                    _MatchTypeCard(
                      type: kPlayFeaturedTypes[i],
                      subtitle: featuredSubtitle[kPlayFeaturedTypes[i]],
                      featured: true,
                      wide: true,
                      enabled: canSelect,
                      bannerUrl: kPlayFeaturedTypes[i] ==
                                  MatchType.specialEvent &&
                              featuredEvent?.banner != null &&
                              featuredEvent!.banner!.isValid
                          ? resolveMediaUrl(featuredEvent.banner!.value)
                          : null,
                      onTap: () => _onMatchTypePressed(kPlayFeaturedTypes[i]),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.gapMd,
            AppChromeSection(
              title: 'Match types',
              icon: Icons.grid_view,
              child: _MatchTypeGrid(
                types: MatchType.values,
                enabled: canSelect,
                onTap: _onMatchTypePressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchTypeGrid extends StatelessWidget {
  const _MatchTypeGrid({
    required this.types,
    required this.enabled,
    required this.onTap,
  });

  final List<MatchType> types;
  final bool enabled;
  final ValueChanged<MatchType> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < types.length; i += 2) {
      if (i > 0) rows.add(AppSpacing.gapSm);
      final left = types[i];
      final right = i + 1 < types.length ? types[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MatchTypeCard(
                type: left,
                subtitle: left.shortBlurb,
                enabled: enabled,
                onTap: () => onTap(left),
              ),
            ),
            AppSpacing.gapSm,
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _MatchTypeCard(
                      type: right,
                      subtitle: right.shortBlurb,
                      enabled: enabled,
                      onTap: () => onTap(right),
                    ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

const String _quickStartArtAsset =
    'assets/images/backgrounds/quick_start_card.webp';

class _FeaturedCover extends StatelessWidget {
  const _FeaturedCover();

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _quickStartArtAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                ink.withValues(alpha: 0.72),
                ink.withValues(alpha: 0.42),
                ink.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchTypeCard extends StatelessWidget {
  const _MatchTypeCard({
    required this.type,
    required this.enabled,
    required this.onTap,
    this.subtitle,
    this.featured = false,
    this.wide = false,
    this.bannerUrl,
  });

  final MatchType type;
  final String? subtitle;
  final bool featured;
  final bool wide;
  final bool enabled;
  final String? bannerUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.md);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(type.icon, size: 18, color: AppChrome.accentGold),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                type.label,
                style: (featured
                        ? context.appTypography.h3
                        : context.appTypography.body)
                    .copyWith(
                  color: featured ? AppChrome.accentGold : AppChrome.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          AppSpacing.gapXxs,
          Text(
            subtitle!,
            maxLines: featured ? 3 : 3,
            overflow: TextOverflow.ellipsis,
            style: context.appTypography.caption.copyWith(
              color: AppChrome.onSurfaceMuted,
            ),
          ),
        ],
        if (wide) ...[
          AppSpacing.gapSm,
          FilledButton.icon(
            style: context.appButtons.primary.filled,
            onPressed: enabled ? onTap : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Now'),
          ),
        ],
      ],
    );
    final art = featured
        ? ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              width: wide ? 120 : double.infinity,
              height: wide ? 120 : 72,
              child: _featuredArt(),
            ),
          )
        : null;
    final child = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              const SizedBox(width: AppSpacing.sm),
              if (art != null) art,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (art != null) ...[art, AppSpacing.gapSm],
              copy,
            ],
          );

    return Material(
      color: AppChrome.fieldFill.withValues(alpha: enabled ? 0.55 : 0.28),
      borderRadius: radius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: featured
                  ? AppChrome.panelBorderGold
                  : AppChrome.panelBorder,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _featuredArt() {
    if (type == MatchType.quickStart) {
      return Image.asset(
        _quickStartArtAsset,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _typeArt(type),
      );
    }
    if (bannerUrl != null && bannerUrl!.isNotEmpty) {
      return Image.network(
        bannerUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _typeArt(type),
      );
    }
    return _typeArt(type);
  }

  Widget _typeArt(MatchType type) {
    return ColoredBox(
      color: AppChrome.fieldFill,
      child: Icon(type.icon, color: AppChrome.accentGold, size: 36),
    );
  }
}
