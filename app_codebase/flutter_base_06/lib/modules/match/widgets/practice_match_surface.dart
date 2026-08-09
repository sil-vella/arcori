import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../state/match_notifier.dart';

/// Full-screen practice match — Flutter-only local snapshot; Slam / End.
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

  void _slam(WidgetRef ref) {
    final userId = ref.read(authProvider).userId?.trim();
    final actor =
        (userId != null && userId.isNotEmpty) ? userId : 'local';
    ref.read(matchSnapshotProvider.notifier).localSlam(actorUserId: actor);
  }

  void _end(BuildContext context, WidgetRef ref) {
    ref.read(matchSnapshotProvider.notifier).localEnd();
  }

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
            ' (offline)',
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
              'arcori=${seat.arcoriIds.join(",")} '
              'slammer=${seat.slammerId}'
              '${snap.active?['seatIndex'] == seat.seatIndex ? ' ← active' : ''}',
              style: context.appTypography.bodySmall,
            ),
          ),
        AppSpacing.gapMd,
        Text(
          lastEvent == null
              ? 'Last event: —'
              : 'Last event: ${lastEvent['type']} '
                  '(${lastEvent['result'] ?? ''})',
          style: context.appTypography.bodySmall,
        ),
        const Spacer(),
        FilledButton(
          onPressed: snap.isEnded ? null : () => _slam(ref),
          child: const Text('Slam'),
        ),
        AppSpacing.gapSm,
        OutlinedButton(
          onPressed: snap.isEnded ? null : () => _end(context, ref),
          child: const Text('End match'),
        ),
      ],
    );
  }
}
