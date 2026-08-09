import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/theme/theme.dart';
import '../state/match_notifier.dart';

/// Full-screen practice match — Flutter-only; auto stub loop (readout only).
Future<void> showPracticeMatchSurface(BuildContext context, WidgetRef ref) {
  return AppModal.showFullScreenShell<void>(
    context,
    title: 'Practice match',
    showCloseButton: false,
    barrierDismissible: false,
    child: const _PracticeMatchBody(),
  );
}

class _PracticeMatchBody extends ConsumerWidget {
  const _PracticeMatchBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(matchSnapshotProvider);

    ref.listen(matchSnapshotProvider, (prev, next) {
      if (next.isEnded && context.mounted) {
        AppModal.dismiss(context);
      }
    });

    final lastEvent = snap.lastEvent;
    final seats = snap.seats;

    return Column(
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
            ' (offline auto)',
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
        const Spacer(),
        Text(
          snap.isEnded ? 'Match ended' : 'Auto-running stub slams…',
          style: context.appTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
