import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../../match/state/match_notifier.dart';
import '../../match/state/match_snapshot_state.dart';
import '../../play/play_models.dart';
import '../../play/play_notifier.dart';
import '../state/lobby_notifier.dart';
import '../state/lobby_snapshot_state.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Thin waiting modal while matchmaking lobby fills / timers out.
Future<void> showMatchmakingLobbyModal(BuildContext context, WidgetRef ref) {
  if (LOGGING_SWITCH) {
    customlog('MatchmakingLobbyModal: show');
  }
  return AppModal.showCenteredShell<void>(
    context,
    title: 'Finding players…',
    barrierDismissible: false,
    showCloseButton: false,
    child: const _LobbyBody(),
  );
}

class _LobbyBody extends ConsumerStatefulWidget {
  const _LobbyBody();

  @override
  ConsumerState<_LobbyBody> createState() => _LobbyBodyState();
}

class _LobbyBodyState extends ConsumerState<_LobbyBody> {
  bool _dismissed = false;

  bool _shouldClose(
    LobbySnapshotState lobby,
    MatchFlowState flow,
    MatchSnapshotState match,
  ) {
    if (match.matchId != null && match.matchId!.isNotEmpty) return true;
    if (lobby.isPromoted) return true;
    if (lobby.phase == 'cancelled') return true;
    if (flow.errorMessage != null && flow.errorMessage!.isNotEmpty) {
      return true;
    }
    if (flow.phase == MatchFlowPhase.inMatch ||
        flow.phase == MatchFlowPhase.postMatch) {
      return true;
    }
    // Invite: both humans joined — promote/match WS can lag behind server start.
    if (flow.selectedType == MatchType.invite &&
        lobby.targetSeats > 0 &&
        lobby.members.length >= lobby.targetSeats) {
      return true;
    }
    // Waiting UI is only valid during online typeSetup.
    if (flow.phase != MatchFlowPhase.typeSetup) return true;
    return false;
  }

  void _closeOnce({required String reason}) {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    if (LOGGING_SWITCH) {
      customlog('MatchmakingLobbyModal: dismiss reason=$reason');
    }
    AppModal.dismiss(context);
  }

  void _maybeClose(
    LobbySnapshotState lobby,
    MatchFlowState flow,
    MatchSnapshotState match,
    String via,
  ) {
    if (!_shouldClose(lobby, flow, match)) return;
    final reason = via +
        ' lobbyId=${lobby.lobbyId} phase=${lobby.phase} '
        'promoted=${lobby.isPromoted} members=${lobby.members.length}/'
        '${lobby.targetSeats} flowPhase=${flow.phase.name} '
        'matchId=${match.matchId ?? '-'} '
        'error=${flow.errorMessage ?? '-'}';
    _closeOnce(reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbySnapshotProvider);
    final flow = ref.watch(matchFlowProvider);
    final match = ref.watch(matchSnapshotProvider);

    ref.listen(lobbySnapshotProvider, (prev, next) {
      _maybeClose(
        next,
        ref.read(matchFlowProvider),
        ref.read(matchSnapshotProvider),
        'lobby',
      );
    });
    ref.listen(matchFlowProvider, (prev, next) {
      _maybeClose(
        ref.read(lobbySnapshotProvider),
        next,
        ref.read(matchSnapshotProvider),
        'flow',
      );
    });
    ref.listen(matchSnapshotProvider, (prev, next) {
      _maybeClose(
        ref.read(lobbySnapshotProvider),
        ref.read(matchFlowProvider),
        next,
        'match',
      );
    });

    _maybeClose(lobby, flow, match, 'build');

    final ends = lobby.endsAt;
    final remaining = ends == null
        ? null
        : ends.difference(DateTime.now().toUtc()).inSeconds;

    final lobbyFull = lobby.targetSeats > 0 &&
        lobby.members.length >= lobby.targetSeats;
    final starting = lobby.isPromoted ||
        lobbyFull ||
        (match.matchId != null && match.matchId!.isNotEmpty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lobby ${lobby.lobbyId ?? '—'}',
          style: context.appTypography.bodySmall,
        ),
        AppSpacing.gapXs,
        Text(
          'Players ${lobby.members.length}/${lobby.targetSeats}'
          '${remaining != null ? ' · ~${remaining.clamp(0, 99)}s' : ''}',
          style: context.appTypography.body,
        ),
        AppSpacing.gapSm,
        for (final m in lobby.members)
          Text(
            '• ${m['userId'] ?? '—'}',
            style: context.appTypography.bodySmall,
          ),
        AppSpacing.gapMd,
        Text(
          starting ? 'Match starting…' : 'Waiting for players or timer…',
          style: context.appTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
