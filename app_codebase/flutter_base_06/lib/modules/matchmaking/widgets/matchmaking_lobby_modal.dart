import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/theme/theme.dart';
import '../../play/play_models.dart';
import '../../play/play_notifier.dart';
import '../state/lobby_notifier.dart';
import '../state/lobby_snapshot_state.dart';

/// Thin waiting modal while matchmaking lobby fills / timers out.
Future<void> showMatchmakingLobbyModal(BuildContext context, WidgetRef ref) {
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

  bool _shouldClose(LobbySnapshotState lobby, MatchFlowState flow) {
    if (lobby.isPromoted) return true;
    if (flow.errorMessage != null && flow.errorMessage!.isNotEmpty) {
      return true;
    }
    // Waiting UI is only valid during online typeSetup. Promote can land
    // before this widget mounts — phase / idle catch that race.
    if (flow.phase != MatchFlowPhase.typeSetup) return true;
    return false;
  }

  void _closeOnce() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppModal.dismiss(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbySnapshotProvider);
    final flow = ref.watch(matchFlowProvider);

    ref.listen(lobbySnapshotProvider, (prev, next) {
      if (_shouldClose(next, ref.read(matchFlowProvider))) _closeOnce();
    });
    ref.listen(matchFlowProvider, (prev, next) {
      if (_shouldClose(ref.read(lobbySnapshotProvider), next)) _closeOnce();
    });

    if (_shouldClose(lobby, flow)) {
      _closeOnce();
    }

    final ends = lobby.endsAt;
    final remaining = ends == null
        ? null
        : ends.difference(DateTime.now().toUtc()).inSeconds;

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
          lobby.isPromoted ? 'Match starting…' : 'Waiting for players or timer…',
          style: context.appTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
