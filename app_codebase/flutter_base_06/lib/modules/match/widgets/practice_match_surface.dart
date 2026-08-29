import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ws/ws_connection_manager.dart';
import '../input/match_grace.dart';
import '../input/slam_input_capture.dart';
import '../input/slam_input_models.dart';
import '../input/slam_motion_capability.dart';
import '../match_action_client.dart';
import '../state/match_notifier.dart';
import '../state/match_snapshot_state.dart';
import '../state/slam_motion_capability_provider.dart';
import 'arcori_stack_surface.dart';
import 'slam_result_modal.dart';

const _dartWsId = 'dart';

/// Match surface — gesture input on your turn; readout for all seats.
Future<void> showPracticeMatchSurface(BuildContext context, WidgetRef ref) {
  return AppModal.showFullScreenShell<void>(
    context,
    title: 'Match',
    showCloseButton: false,
    barrierDismissible: false,
    child: const _PracticeMatchBody(),
  );
}

class _PracticeMatchBody extends ConsumerStatefulWidget {
  const _PracticeMatchBody();

  @override
  ConsumerState<_PracticeMatchBody> createState() => _PracticeMatchBodyState();
}

class _PracticeMatchBodyState extends ConsumerState<_PracticeMatchBody> {
  Timer? _graceTicker;
  Map<String, dynamic>? _predictiveImpulse;
  int? _lastSlamResultModalVersion;

  @override
  void dispose() {
    _graceTicker?.cancel();
    super.dispose();
  }

  void _syncGraceTicker(bool inGrace) {
    if (inGrace && _graceTicker == null) {
      _graceTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!inGrace && _graceTicker != null) {
      _graceTicker?.cancel();
      _graceTicker = null;
    }
  }

  bool _isLocal(String? matchId) =>
      matchId != null && matchId.startsWith('local_practice_');

  int? _mySeatIndex(MatchSnapshotState snap, String? userId) {
    if (userId == null || userId.isEmpty) return null;
    for (final seat in snap.seats) {
      if (seat.userId == userId) return seat.seatIndex;
    }
    return null;
  }

  bool _isMyTurn(MatchSnapshotState snap, String? userId) {
    final active = snap.active?['seatIndex'];
    if (active is! int) return false;
    return _mySeatIndex(snap, userId) == active;
  }

  int _scoreFor(MatchSnapshotState snap, String userId) {
    for (final seat in snap.seats) {
      if (seat.userId == userId) return seat.score;
    }
    return 0;
  }

  bool _simHasFrames(Map<String, dynamic>? sim) {
    final frames = sim?['frames'];
    return frames is List && frames.length >= 2;
  }

  Future<void> _commitSlam(SlamInputPayload payload) async {
    final snap = ref.read(matchSnapshotProvider);
    final matchId = snap.matchId;
    if (matchId == null || matchId.isEmpty || snap.isEnded) return;

    final userId = ref.read(authProvider).userId?.trim();
    if (userId == null || userId.isEmpty) return;
    if (!_isMyTurn(snap, userId)) return;

    final input = payload.toJson();
    // Predictive spring only until authority sim arrives.
    setState(() {
      _predictiveImpulse = {
        'vx': payload.trajectory.dx * payload.speed,
        'vy': payload.trajectory.dy * payload.speed,
        'spin': payload.speed * 1.5,
        'power': payload.speed,
      };
    });

    if (_isLocal(matchId)) {
      ref.read(matchSnapshotProvider.notifier).localSlam(
            actorUserId: userId,
            input: input,
          );
      return;
    }

    final manager = ref.read(wsConnectionManagerProvider.notifier);
    await sendMatchAction(
      manager: manager,
      matchId: matchId,
      action: 'slam',
      input: input,
    );
  }

  Future<void> _endOnline() async {
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
  Widget build(BuildContext context) {
    final snap = ref.watch(matchSnapshotProvider);
    final local = _isLocal(snap.matchId);
    final userId = ref.watch(authProvider.select((a) => a.userId?.trim()));
    final inGrace = activeInGracePeriod(snap.active);
    _syncGraceTicker(inGrace);
    final graceLeft = graceRemaining(snap.active);
    final myTurn = _isMyTurn(snap, userId);
    final armed =
        snap.phase == 'playing' && !snap.isEnded && myTurn && !inGrace;

    ref.listen(matchSnapshotProvider, (prev, next) {
      if (next.isEnded && prev?.isEnded != true && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppModal.dismiss(context);
        });
      }

      final event = next.lastEvent;
      if (event == null || event['type'] != 'slam') return;
      final version = event['version'];
      if (version is! int) return;
      if (_lastSlamResultModalVersion == version) return;

      final outcome = event['outcome'];
      final hasSim = outcome is Map &&
          outcome['sim'] is Map &&
          _simHasFrames(Map<String, dynamic>.from(outcome['sim'] as Map));
      if (hasSim && _predictiveImpulse != null && mounted) {
        setState(() => _predictiveImpulse = null);
      }

      final actorId = event['actorUserId']?.toString();
      final me = ref.read(authProvider).userId?.trim();
      if (me == null || me.isEmpty || actorId != me) return;

      _lastSlamResultModalVersion = version;
      final delta =
          prev == null ? 0 : _scoreFor(next, me) - _scoreFor(prev, me);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showSlamResultModal(
          context,
          lastEvent: Map<String, dynamic>.from(event),
          actorScoreDelta: delta,
        );
      });
    });

    final lastEvent = snap.lastEvent;
    final seats = snap.seats;
    final input = lastEvent?['input'];
    final inputSummary = input is Map
        ? 'speed=${input['speed']} angle=${(input['trajectory'] as Map?)?['angleDeg']}'
        : '';
    final outcome = lastEvent?['outcome'];
    final authorityImpulse = outcome is Map && outcome['impulse'] is Map
        ? Map<String, dynamic>.from(outcome['impulse'] as Map)
        : null;
    final authoritySim = outcome is Map && outcome['sim'] is Map
        ? Map<String, dynamic>.from(outcome['sim'] as Map)
        : null;
    final simReady = _simHasFrames(authoritySim);
    // Prefer authority sim; predictive/authority impulse only as fallback.
    final stackImpulse =
        simReady ? null : (authorityImpulse ?? _predictiveImpulse);

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inGrace) ...[
          Text(
            'Get ready…',
            style: context.appTypography.label,
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapXs,
          Text(
            graceLeft != null && graceLeft.inSeconds > 0
                ? 'Match starts in ${graceLeft.inSeconds}s'
                : 'Match starting…',
            style: context.appTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapSm,
        ] else if (armed) ...[
          ...() {
            final shakeProbe = ref.watch(slamShakeAvailableProvider);
            final shakeAvailable = shakeProbe.value ?? false;
            final hints = slamTurnHints(shakeAvailable: shakeAvailable);
            return [
              Text(
                hints.primary,
                style: context.appTypography.label,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXs,
              Text(
                hints.secondary,
                style: context.appTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
            ];
          }(),
        ] else if (!snap.isEnded && snap.phase == 'playing') ...[
          Text(
            'Waiting for other player…',
            style: context.appTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapSm,
        ],
        Text('Stack', style: context.appTypography.label),
        AppSpacing.gapXs,
        ArcoriStackSurface(
          key: ValueKey('stack-${snap.matchId}-v${snap.version}'),
          pieces: snap.pieces,
          impulse: stackImpulse,
          sim: authoritySim,
        ),
        AppSpacing.gapMd,
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
            '${local ? ' (offline)' : ' (online)'}',
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
                  '${lastEvent['actorUserId'] != null ? ' · ${lastEvent['actorUserId']}' : ''}'
                  '${inputSummary.isNotEmpty ? ' · $inputSummary' : ''}',
          style: context.appTypography.bodySmall,
        ),
        AppSpacing.gapLg,
        Text(
          snap.isEnded
              ? 'Match ended'
              : local
                  ? 'Practice match'
                  : 'Online match',
          style: context.appTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (!local && !snap.isEnded) ...[
          AppSpacing.gapSm,
          OutlinedButton(
            onPressed: _endOnline,
            child: const Text('End match'),
          ),
        ],
      ],
    );

    // Key by turn identity so a rejected grace swipe cannot leave capture
    // stuck committed for the real first turn.
    return SlamInputCapture(
      key: ValueKey(
        'slam-${snap.matchId}-r${snap.round}-'
        's${snap.active?['seatIndex']}-v${snap.version}-'
        '${inGrace ? 'grace' : 'live'}',
      ),
      armed: armed,
      onCommit: (payload) => unawaited(_commitSlam(payload)),
      child: body,
    );
  }
}
