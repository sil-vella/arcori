import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/media_url.dart';
import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ws/ws_connection_manager.dart';
import '../../../utils/dev_logger.dart';
import '../input/match_grace.dart';
import '../input/slam_input_capture.dart';
import '../input/slam_input_models.dart';
import '../input/slam_motion_capability.dart';
import '../match_action_client.dart';
import '../state/match_notifier.dart';
import '../state/match_snapshot_state.dart';
import '../state/slam_motion_capability_provider.dart';
import '../../play/game_controls_prefs.dart';
import '../../play/play_models.dart';
import '../../play/play_notifier.dart';
import '../../play/slam_control_mode_ui.dart';
import 'arcori_image_prefetch.dart';
import 'arcori_stack_surface.dart';
import 'arena_pov_backdrop.dart';
import 'slam_result_modal.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const _dartWsId = 'dart';

/// Match surface — gesture input on your turn; readout for all seats.
Future<void> showPracticeMatchSurface(BuildContext context, WidgetRef ref) {
  return AppModal.showFullScreenShell<void>(
    context,
    title: 'Match',
    showCloseButton: false,
    barrierDismissible: false,
    scrollable: false,
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
  Map<String, dynamic>? _pendingSlamResultEvent;
  int _pendingSlamResultDelta = 0;
  SlamAim _liveAim = SlamAim.center;
  double? _powerPreview;
  int? _lastPowerGaugeLogVersion;
  String? _prefetchedArtFp;
  final _stackAreaKey = GlobalKey();
  final _arenaPovScale = ValueNotifier<double>(1.0);

  @override
  void dispose() {
    _graceTicker?.cancel();
    _arenaPovScale.dispose();
    super.dispose();
  }

  void _flushPendingSlamResultModal() {
    final event = _pendingSlamResultEvent;
    if (event == null || !mounted) return;
    _pendingSlamResultEvent = null;
    final delta = _pendingSlamResultDelta;
    showSlamResultModal(
      context,
      lastEvent: Map<String, dynamic>.from(event),
      actorScoreDelta: delta,
    );
  }

  void _onStackAnimComplete(int stackVersion) {
    final pending = _pendingSlamResultEvent;
    if (pending == null) return;
    final pendingVersion = pending['version'];
    if (pendingVersion is! int || pendingVersion != stackVersion) return;
    _flushPendingSlamResultModal();
  }

  /// Close this shell even when another modal is on top (post-match / lobby).
  void _forceCloseShell({required String reason}) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (LOGGING_SWITCH) {
      customlog(
        'matchSurface: forceClose reason=$reason current=${route.isCurrent}',
      );
    }
    if (route.isCurrent) {
      AppModal.dismiss(context);
      return;
    }
    // Orphan under post-match: remove without popping the top route.
    Navigator.of(context, rootNavigator: true).removeRoute(route);
  }

  /// Close the match fullscreen once it is the top route (after slam overlays).
  void _scheduleMatchShellDismiss({int attempts = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        AppModal.dismiss(context);
        return;
      }
      if (attempts >= 25) {
        _forceCloseShell(reason: 'ended-timeout');
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        // Flow already left the match — force-remove even if not current.
        final phase = ref.read(matchFlowProvider).phase;
        if (phase != MatchFlowPhase.inMatch) {
          _forceCloseShell(reason: 'phase=${phase.name}');
          return;
        }
        if (!ref.read(matchSnapshotProvider).isEnded) return;
        _scheduleMatchShellDismiss(attempts: attempts + 1);
      });
    });
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

  void _resetLiveAim(String reason) {
    if (_liveAim.x == 0 && _liveAim.z == 0 && _powerPreview == null) {
      return;
    }
    if (LOGGING_SWITCH) {
      customlog('matchSurface: resetAim reason=$reason');
    }
    setState(() {
      _liveAim = SlamAim.center;
      _powerPreview = null;
    });
  }

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

  /// Live local charge, else last slam commit speed (any seat).
  double _displayedPower({
    required MatchSnapshotState snap,
    required bool armed,
  }) {
    if (armed && _powerPreview != null) {
      return _powerPreview!.clamp(0.0, 1.0);
    }
    final event = snap.lastEvent;
    if (event == null || event['type'] != 'slam') return 0;
    final input = event['input'];
    if (input is Map && input['speed'] is num) {
      return (input['speed'] as num).toDouble().clamp(0.0, 1.0);
    }
    final outcome = event['outcome'];
    if (outcome is Map && outcome['impulse'] is Map) {
      final power = outcome['impulse']['power'];
      if (power is num) return power.toDouble().clamp(0.0, 1.0);
    }
    return 0;
  }

  Future<void> _commitSlam(SlamInputPayload payload) async {
    final snap = ref.read(matchSnapshotProvider);
    final matchId = snap.matchId;
    if (matchId == null || matchId.isEmpty || snap.isEnded) return;

    final userId = ref.read(authProvider).userId?.trim();
    if (userId == null || userId.isEmpty) return;
    if (!_isMyTurn(snap, userId)) return;
    if (activeInputLocked(snap.active) || activeInGracePeriod(snap.active)) {
      return;
    }

    final input = payload.toJson();
    final traj = payload.trajectory ?? SlamTrajectory.fromAim(payload.aim);
    // Predictive spring only until authority sim arrives.
    setState(() {
      _liveAim = payload.aim;
      _predictiveImpulse = {
        'vx': traj.dx * payload.speed,
        'vy': traj.dy * payload.speed,
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

  void _precacheTableArt(MatchSnapshotState snap) {
    final urls = collectArcoriArtUrls(
      extra: [
        ...snap.pieces.map((p) => p.imageUrl),
        snap.arenaImageUrl,
      ],
    );
    final fp = urls.join('|');
    if (fp.isEmpty || fp == _prefetchedArtFp) return;
    _prefetchedArtFp = fp;
    unawaited(precacheArcoriArt(context, urls));
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(matchSnapshotProvider);
    final local = _isLocal(snap.matchId);
    final userId = ref.watch(authProvider.select((a) => a.userId?.trim()));
    final inGrace = activeInGracePeriod(snap.active);
    final inputLocked = activeInputLocked(snap.active);
    _syncGraceTicker(inGrace || inputLocked);
    final graceLeft = graceRemaining(snap.active);
    final myTurn = _isMyTurn(snap, userId);
    final armed = snap.phase == 'playing' &&
        !snap.isEnded &&
        myTurn &&
        !inGrace &&
        !inputLocked;
    final controlMode = ref.watch(gameControlsProvider).slamControlMode;
    _precacheTableArt(snap);

    ref.listen(matchSnapshotProvider, (prev, next) {
      if (next.isEnded && prev?.isEnded != true && context.mounted) {
        _scheduleMatchShellDismiss();
      }

      // No leftover aim/target across turns or matches.
      final prevSeat = prev?.active?['seatIndex'];
      final nextSeat = next.active?['seatIndex'];
      if (prev?.matchId != next.matchId ||
          prev?.round != next.round ||
          prevSeat != nextSeat) {
        if (_liveAim.x != 0 || _liveAim.z != 0 || _powerPreview != null) {
          _resetLiveAim(
            'match=${next.matchId} round=${next.round} seat=$nextSeat',
          );
        }
      }

      final event = next.lastEvent;
      if (event == null || event['type'] != 'slam') return;
      final version = event['version'];
      if (version is! int) return;

      // Newer slam interrupted a pending local result — show it now.
      final pending = _pendingSlamResultEvent;
      if (pending != null && pending['version'] != version) {
        _flushPendingSlamResultModal();
      }

      final outcome = event['outcome'];
      final hasSim = outcome is Map &&
          outcome['sim'] is Map &&
          _simHasFrames(Map<String, dynamic>.from(outcome['sim'] as Map));
      if (hasSim && _predictiveImpulse != null && mounted) {
        setState(() => _predictiveImpulse = null);
      }

      // Any seat commit → clear local charge preview so gauge shows authority speed.
      final input = event['input'];
      if (input is Map && input['speed'] is num && mounted) {
        final speed = (input['speed'] as num).toDouble().clamp(0.0, 1.0);
        if (LOGGING_SWITCH && _lastPowerGaugeLogVersion != version) {
          _lastPowerGaugeLogVersion = version;
          customlog(
            'powerGauge: slam commit version=$version '
            'actor=${event['actorUserId']} speed=${speed.toStringAsFixed(2)}',
          );
        }
        if (_powerPreview != null) {
          setState(() => _powerPreview = null);
        }
      }

      final actorId = event['actorUserId']?.toString();
      final me = ref.read(authProvider).userId?.trim();
      if (me == null || me.isEmpty || actorId != me) return;
      if (_lastSlamResultModalVersion == version) return;

      _lastSlamResultModalVersion = version;
      final delta =
          prev == null ? 0 : _scoreFor(next, me) - _scoreFor(prev, me);
      // Show after flip anim completes (stack onAnimComplete).
      _pendingSlamResultEvent = Map<String, dynamic>.from(event);
      _pendingSlamResultDelta = delta;
      if (LOGGING_SWITCH) {
        customlog(
          'slamResultModal: pending after anim version=$version '
          'result=${event['result']}',
        );
      }
    });

    // Leave inMatch → remove this shell even when buried under post-match.
    // Otherwise Done/clear cancels isEnded-dismiss and the next match stacks
    // another surface on a stale rematch shell.
    ref.listen(matchFlowProvider, (prev, next) {
      if (next.phase == MatchFlowPhase.inMatch) return;
      if (prev?.phase != MatchFlowPhase.inMatch &&
          prev?.phase != MatchFlowPhase.postMatch) {
        return;
      }
      _forceCloseShell(reason: 'flow=${next.phase.name}');
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
    final gaugePower = _displayedPower(snap: snap, armed: armed);

    final stackKey = ValueKey(
      'stack-${snap.matchId}-s${(lastEvent != null && lastEvent['type'] == 'slam') ? lastEvent['version'] : 0}',
    );

    return SlamInputCapture(
      key: ValueKey(
        'slam-${snap.matchId}-r${snap.round}-'
        's${snap.active?['seatIndex']}-'
        '${inGrace ? 'grace' : 'live'}-${controlMode.name}',
      ),
      armed: armed,
      controlMode: controlMode,
      onAimChanged: (aim) {
        if (!mounted) return;
        if ((_liveAim.x - aim.x).abs() < 1e-9 &&
            (_liveAim.z - aim.z).abs() < 1e-9) {
          return;
        }
        setState(() => _liveAim = aim);
      },
      onPowerPreview: (p) {
        if (!mounted) return;
        if (_powerPreview == p) return;
        setState(() => _powerPreview = p);
      },
      onCommit: (payload) => unawaited(_commitSlam(payload)),
      builder: (context, handle) {
        final arenaUrl = resolveMediaUrl(snap.arenaImageUrl);
        final hasArena = arenaUrl.isNotEmpty;
        final stack = ArcoriStackSurface(
          // Key on slam event only — clearTurnAnimLock bumps version and must
          // not remount mid-replay (that restarts anim / blanks the table).
          key: stackKey,
          pieces: snap.pieces,
          impulse: stackImpulse,
          sim: authoritySim,
          showAimMarker: armed,
          aimX: _liveAim.x,
          aimZ: _liveAim.z,
          applyFitZoom: !hasArena,
          onPovScale: (fit) {
            if ((_arenaPovScale.value - fit).abs() < 0.002) return;
            _arenaPovScale.value = fit;
          },
          onAnimComplete: () {
            final v = (lastEvent != null &&
                    lastEvent['type'] == 'slam' &&
                    lastEvent['version'] is int)
                ? lastEvent['version'] as int
                : snap.version;
            _onStackAnimComplete(v);
          },
        );

        final locked = handle.aimLocked;
        Widget? aimOverlay;
        if (controlMode == SlamControlMode.touch) {
          aimOverlay = Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final area = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (!armed || locked)
                      ? null
                      : (e) => handle.onAimAtLocal(
                            e.localPosition,
                            area,
                          ),
                  onPointerMove: (!armed || locked)
                      ? null
                      : (e) => handle.onAimAtLocal(
                            e.localPosition,
                            area,
                          ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart:
                        (armed && locked) ? (_) {} : null,
                    onVerticalDragUpdate: (armed && locked)
                        ? handle.onPowerDragUpdate
                        : null,
                    onVerticalDragEnd: (armed && locked)
                        ? handle.onPowerDragEnd
                        : null,
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          );
        }

        final stackRow = SizedBox(
          key: _stackAreaKey,
          height: 220,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (!hasArena) Positioned.fill(child: stack),
              if (aimOverlay != null) aimOverlay,
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(child: handle.aimLockButton()),
              ),
            ],
          ),
        );

        final matchColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!snap.isEnded) ...[
              SlamControlModeIndicator(mode: controlMode),
              AppSpacing.gapSm,
            ],
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
            ] else if (inputLocked) ...[
              Text(
                'Resolving slam…',
                style: context.appTypography.label,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXs,
              Text(
                'Wait for the table to settle',
                style: context.appTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
            ] else if (armed) ...[
              ...() {
                final shakeProbe = ref.watch(slamShakeAvailableProvider);
                final shakeAvailable = shakeProbe.value ?? false;
                final hints = slamTurnHints(
                  shakeAvailable: shakeAvailable,
                  controlMode: controlMode,
                );
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
            // Always reserve space from match open; animates on every commit.
            if (!snap.isEnded) ...[
              SlamPowerGauge(power01: gaugePower),
              AppSpacing.gapSm,
            ],
            Text('Stack', style: context.appTypography.label),
            AppSpacing.gapXs,
            stackRow,
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

        return ScrollConfiguration(
          behavior: const _MatchNoScrollBehavior(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasArena)
                Positioned.fill(
                  child: ArenaPovBackdrop(
                    imageUrl: arenaUrl,
                    povScale: _arenaPovScale,
                    stackAreaKey: _stackAreaKey,
                    stackLayer: stack,
                  ),
                ),
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  primary: false,
                  child: matchColumn,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Match gestures must not lose to overscroll / parent scrollables.
class _MatchNoScrollBehavior extends ScrollBehavior {
  const _MatchNoScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const NeverScrollableScrollPhysics();
}
