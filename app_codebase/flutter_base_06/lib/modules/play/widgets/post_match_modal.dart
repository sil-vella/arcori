import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../../match/state/match_notifier.dart';
import '../../match/state/match_snapshot_state.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../play_models.dart';
import '../play_notifier.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Single post-match shell: celebration stubs + summary + actions.
Future<void> showPostMatchModal(BuildContext context, WidgetRef ref) {
  return AppModal.showCenteredShell<void>(
    context,
    title: 'Match complete',
    barrierDismissible: false,
    showCloseButton: false,
    child: const _PostMatchBody(),
  );
}

class _PostMatchBody extends ConsumerStatefulWidget {
  const _PostMatchBody();

  @override
  ConsumerState<_PostMatchBody> createState() => _PostMatchBodyState();
}

class _PostMatchBodyState extends ConsumerState<_PostMatchBody> {
  bool _exiting = false;

  /// Freeze at open so late WS / clear races cannot swap in a prior match.
  MatchSnapshotState? _frozenSnap;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final snap = ref.read(matchSnapshotProvider);
      setState(() => _frozenSnap = snap);
      if (LOGGING_SWITCH) {
        customlog(
          'postMatchModal: freeze matchId=${snap.matchId} '
          'phase=${snap.phase} seats=${snap.seats.length} '
          'type=${snap.matchType}',
        );
      }
      unawaited(
        ref.read(matchFlowProvider.notifier).requestPostMatchFinalize(),
      );
    });
  }

  Future<void> _exit(void Function() complete) async {
    if (_exiting) return;
    _exiting = true;
    // Dismiss before completing so Play New does not stack lobby/match under
    // a still-visible post-match shell.
    if (mounted) {
      AppModal.dismiss(context);
    }
    complete();
  }

  void _done() {
    unawaited(_exit(() {
      ref.read(matchFlowProvider.notifier).completePostMatchDone();
    }));
  }

  void _playNew() {
    unawaited(_exit(() {
      ref.read(matchFlowProvider.notifier).completePostMatchPlayNew();
    }));
  }

  void _rematch() {
    final flow = ref.read(matchFlowProvider.notifier);
    if (!flow.rematchAvailable()) return;
    unawaited(_exit(() {
      flow.completePostMatchRematch();
    }));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(matchFlowProvider, (prev, next) {
      if (_exiting) return;
      if (prev?.phase == MatchFlowPhase.postMatch &&
          next.phase != MatchFlowPhase.postMatch &&
          context.mounted) {
        if (LOGGING_SWITCH) {
          customlog('postMatchModal: auto-dismiss phase=${next.phase.name}');
        }
        AppModal.dismiss(context);
      }
    });

    final live = ref.watch(matchSnapshotProvider);
    final snap = _frozenSnap ?? live;
    final flow = ref.watch(matchFlowProvider);
    final notifier = ref.read(matchFlowProvider.notifier);
    final rematchOk = notifier.rematchAvailable();
    final rematchReason = notifier.rematchDisabledReason();
    final userId = ref.watch(authProvider).userId?.trim() ?? '';
    final headline = _headlineFor(snap, userId);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: context.appTypography.h3),
          AppSpacing.gapXs,
          Text(
            'Celebration & mastery animations — soon',
            style: context.appTypography.bodySmall,
          ),
          AppSpacing.gapSm,
          _RewardStubRow(),
          AppSpacing.gapMd,
          Text('Summary', style: context.appTypography.label),
          AppSpacing.gapXs,
          _MatchSummaryBlock(snap: snap),
          AppSpacing.gapMd,
          Text('Daily', style: context.appTypography.label),
          AppSpacing.gapXs,
          Text(
            'Daily progress / missions / cache — soon',
            style: context.appTypography.bodySmall,
          ),
          if (flow.postMatchSoftError != null &&
              flow.postMatchSoftError!.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(
              flow.postMatchSoftError!,
              style: context.appTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          AppSpacing.gapLg,
          FilledButton(
            onPressed: rematchOk && !_exiting ? _rematch : null,
            child: const Text('Rematch'),
          ),
          if (!rematchOk && rematchReason != null) ...[
            AppSpacing.gapXs,
            Text(
              rematchReason,
              style: context.appTypography.bodySmall,
            ),
          ],
          AppSpacing.gapSm,
          FilledButton(
            onPressed: _playNew,
            child: const Text('Play New'),
          ),
          AppSpacing.gapSm,
          OutlinedButton(
            onPressed: _done,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _headlineFor(MatchSnapshotState snap, String userId) {
    final result = snap.result;
    if (result == null) return 'Match ended';
    final winners = result['winnerUserIds'];
    if (winners is! List || winners.isEmpty) return 'Match ended';
    final ids = winners.map((e) => e.toString()).toSet();
    if (userId.isNotEmpty && ids.contains(userId)) {
      if (ids.length == 1) return 'Victory';
      return 'You placed among the winners';
    }
    if (userId.isNotEmpty) return 'Defeat';
    return 'Match ended';
  }
}

class _RewardStubRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          label: Text('+0 Fragments', style: context.appTypography.bodySmall),
        ),
        Chip(
          label: Text('+0 Rank XP', style: context.appTypography.bodySmall),
        ),
        Chip(
          label: Text('Mastery — soon', style: context.appTypography.bodySmall),
        ),
      ],
    );
  }
}

class _MatchSummaryBlock extends StatelessWidget {
  const _MatchSummaryBlock({required this.snap});

  final MatchSnapshotState snap;

  @override
  Widget build(BuildContext context) {
    final seats = [...snap.seats]
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    if (seats.isEmpty) {
      return Text('No seat data', style: context.appTypography.bodySmall);
    }

    return Column(
      children: [
        for (final seat in seats) ...[
          Row(
            children: [
              _SeatFace(snap: snap, seat: seat),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seat.kind == 'ai'
                          ? 'AI · seat ${seat.seatIndex + 1}'
                          : 'Seat ${seat.seatIndex + 1}',
                      style: context.appTypography.body,
                    ),
                    Text(
                      _designLabel(seat),
                      style: context.appTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '${seat.score}',
                style: context.appTypography.h3,
              ),
            ],
          ),
          if (seat != seats.last) AppSpacing.gapSm,
        ],
      ],
    );
  }

  String _designLabel(MatchSeatView seat) {
    if (seat.arcoriIds.isEmpty) return '—';
    return seat.arcoriIds.first;
  }
}

class _SeatFace extends StatelessWidget {
  const _SeatFace({required this.snap, required this.seat});

  final MatchSnapshotState snap;
  final MatchSeatView seat;

  @override
  Widget build(BuildContext context) {
    MatchPieceView? piece;
    for (final p in snap.pieces) {
      if (p.seatIndex == seat.seatIndex) {
        piece = p;
        break;
      }
    }
    final designId = piece?.designId.isNotEmpty == true
        ? piece!.designId
        : (seat.arcoriIds.isNotEmpty ? seat.arcoriIds.first : 'unknown');
    return ArcoriCylinder(
      size: 40,
      look: ArcoriLook(
        designId: designId,
        imageUrl: piece?.imageUrl,
        colorHex: piece?.color,
      ),
      faceUp: true,
      showThickness: false,
    );
  }
}
