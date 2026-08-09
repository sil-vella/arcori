import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ws/ws_connection_manager.dart';
import '../state/match_notifier.dart';

const _dartWsId = 'dart';

/// Match surface — practice auto-run readout; online shows End for caller.
Future<void> showPracticeMatchSurface(BuildContext context, WidgetRef ref) {
  return AppModal.showFullScreenShell<void>(
    context,
    title: 'Match',
    showCloseButton: false,
    barrierDismissible: false,
    child: const _PracticeMatchBody(),
  );
}

class _PracticeMatchBody extends ConsumerWidget {
  const _PracticeMatchBody();

  bool _isLocal(String? matchId) =>
      matchId != null && matchId.startsWith('local_practice_');

  Future<void> _endOnline(WidgetRef ref) async {
    final snap = ref.read(matchSnapshotProvider);
    final matchId = snap.matchId;
    if (matchId == null || matchId.isEmpty || snap.isEnded) return;
    final userId = ref.read(authProvider).userId?.trim();
    if (userId == null || userId.isEmpty || snap.callerUserId != userId) {
      return;
    }
    final manager = ref.read(wsConnectionManagerProvider.notifier);
    await manager.send(
      _dartWsId,
      type: 'event',
      channel: 'match/end',
      payload: {'matchId': matchId},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(matchSnapshotProvider);
    final local = _isLocal(snap.matchId);

    ref.listen(matchSnapshotProvider, (prev, next) {
      // Edge-trigger only: multiple ended WS frames must not pop go_router.
      if (!next.isEnded || prev?.isEnded == true || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        AppModal.dismiss(context);
      });
    });

    final lastEvent = snap.lastEvent;
    final seats = snap.seats;

    // Shrink-wrap: full-screen shell puts this Column in a scroll view
    // (unbounded height) — Spacer/Expanded are invalid there.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Arena: ${snap.arenaId ?? '—'}',
          style: context.appTypography.bodySmall,
        ),
        AppSpacing.gapXs,
        Text(
          'Phase: ${snap.phase ?? '—'} · round ${snap.round}/${snap.roundsTotal}',
          style: context.appTypography.body,
        ),
        if (snap.matchType.isNotEmpty) ...[
          AppSpacing.gapXs,
          Text(
            'Type: ${snap.matchType['code'] ?? '—'}'
            '${snap.matchType['subtype'] != null ? ' / ${snap.matchType['subtype']}' : ''}'
            '${local ? ' (offline auto)' : ' (online)'}',
            style: context.appTypography.bodySmall,
          ),
        ],
        AppSpacing.gapMd,
        Text('Seats', style: context.appTypography.label),
        AppSpacing.gapXs,
        for (final seat in seats)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '#${seat.seatIndex} ${seat.kind} ${seat.userId} '
              'score=${seat.score} '
              'arcori=${seat.arcoriIds.isEmpty ? '—' : seat.arcoriIds.join(",")} '
              'slammer=${seat.slammerId.isEmpty ? '—' : seat.slammerId}'
              '${snap.active?['seatIndex'] == seat.seatIndex ? ' ← active' : ''}',
              style: context.appTypography.bodySmall,
            ),
          ),
        AppSpacing.gapMd,
        Text(
          lastEvent == null
              ? 'Last event: —'
              : 'Last event: ${lastEvent['type']} '
                  '(${lastEvent['result'] ?? ''})'
                  '${lastEvent['actorUserId'] != null ? ' · ${lastEvent['actorUserId']}' : ''}',
          style: context.appTypography.bodySmall,
        ),
        AppSpacing.gapLg,
        Text(
          snap.isEnded
              ? 'Match ended'
              : local
                  ? 'Auto-running stub slams…'
                  : 'Online match (stub end available)',
          style: context.appTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (!local && !snap.isEnded) ...[
          AppSpacing.gapSm,
          OutlinedButton(
            onPressed: () => _endOnline(ref),
            child: const Text('End match'),
          ),
        ],
      ],
    );
  }
}
