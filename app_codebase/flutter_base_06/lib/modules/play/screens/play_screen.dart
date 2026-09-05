import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../../avari/avari_models.dart';
import '../../avari/avari_notifier.dart';
import '../../match/widgets/arcori_image_prefetch.dart';
import '../../match/widgets/practice_match_surface.dart';
import '../../matchmaking/widgets/matchmaking_lobby_modal.dart';
import '../play_models.dart';
import '../play_notifier.dart';
import '../widgets/match_type_select_modal.dart';
import '../widgets/invite_setup_modal.dart';
import '../widgets/play_failure_modal.dart';
import '../widgets/practice_loadout_modal.dart';

/// Play hub — start and end of the match pipeline.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_warmArcoriArt);
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

  Future<void> _onPlayPressed() async {
    final notifier = ref.read(matchFlowProvider.notifier);
    notifier.startPlay();
    final type = await showMatchTypeSelectModal(context);
    if (!mounted) return;
    if (type == null) {
      notifier.cancelSelection();
      return;
    }

    PracticeLoadout? loadout;
    if (type == MatchType.practice) {
      loadout = await showPracticeLoadoutModal(context);
      if (!mounted) return;
      if (loadout == null) {
        notifier.cancelSelection();
        return;
      }
    }

    if (type == MatchType.invite) {
      final setup = await showInviteSetupModal(context: context, ref: ref);
      if (!mounted) return;
      if (setup == null ||
          setup.inviteId.trim().isEmpty ||
          setup.invitedUserId.trim().isEmpty) {
        notifier.cancelSelection();
        return;
      }
      await notifier.selectType(
        type,
        inviteId: setup.inviteId,
        invitedUserId: setup.invitedUserId,
      );
      return;
    }

    await notifier.selectType(type, practiceLoadout: loadout);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(matchFlowProvider);
    final canPlay = flow.isIdle && flow.errorMessage == null;

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

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Play', icon: Icons.sports_esports_outlined),
      ],
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Play',
                style: context.appTypography.h2,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
              Text(
                flow.isIdle
                    ? 'Press Play to choose a match type.'
                    : flow.phase.label,
                style: context.appTypography.body,
                textAlign: TextAlign.center,
              ),
              if (flow.selectedType != null) ...[
                AppSpacing.gapXs,
                Text(
                  flow.selectedType!.label,
                  style: context.appTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              AppSpacing.gapLg,
              FilledButton(
                onPressed: canPlay ? _onPlayPressed : null,
                child: const Text('Play'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
