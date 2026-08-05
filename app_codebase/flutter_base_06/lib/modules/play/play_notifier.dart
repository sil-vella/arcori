import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/dev_logger.dart';
import '../match/state/match_notifier.dart';
import '../match/state/match_snapshot_state.dart';
import 'play_models.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/ws/ws_config.dart';
import '../../core/ws/ws_connection_manager.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const _dartWsId = 'dart';

final matchFlowProvider =
    NotifierProvider<MatchFlowNotifier, MatchFlowState>(MatchFlowNotifier.new);

/// Owns the Play → type select → setup → match → post-match pipeline.
///
/// Stage 2: `_runMatchSsot` talks to Dart match hot state when WS/auth available.
class MatchFlowNotifier extends Notifier<MatchFlowState> {
  int _runId = 0;

  @override
  MatchFlowState build() => const MatchFlowState();

  /// Enter type selection. No-op if not idle.
  void startPlay() {
    if (!state.isIdle) return;
    _setPhase(MatchFlowPhase.selectingType);
  }

  /// Cancel type modal → idle.
  void cancelSelection() {
    if (state.phase != MatchFlowPhase.selectingType) return;
    _runId++;
    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: cancelSelection → idle');
    }
  }

  /// Chosen type → run pipeline → idle.
  Future<void> selectType(MatchType type) async {
    if (state.phase != MatchFlowPhase.selectingType) return;
    final runId = ++_runId;
    state = MatchFlowState(
      phase: MatchFlowPhase.typeSetup,
      selectedType: type,
    );
    if (LOGGING_SWITCH) {
      customlog('play: selectType=${type.name} → typeSetup');
    }

    await _runTypeSetup(type);
    if (!_isCurrentRun(runId, type)) return;

    _setPhase(MatchFlowPhase.inMatch);
    await _runMatchSsot();
    if (!_isCurrentRun(runId, type)) return;

    _setPhase(MatchFlowPhase.postMatch);
    await _runPostMatch();
    if (!_isCurrentRun(runId, type)) return;

    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: pipeline done → idle');
    }
  }

  bool _isCurrentRun(int runId, MatchType type) {
    return runId == _runId && state.selectedType == type;
  }

  void _setPhase(MatchFlowPhase phase) {
    state = state.copyWith(phase: phase);
    if (LOGGING_SWITCH) {
      customlog('play: phase=${phase.name}');
    }
  }

  /// Hook: per-type setup (matchmaking, invite, event rules). Stub for now.
  Future<void> _runTypeSetup(MatchType type) async {
    if (LOGGING_SWITCH) {
      customlog('play: typeSetup stub type=${type.name}');
    }
  }

  /// Live Dart match SSOT when configured; otherwise no-op (tests / offline).
  Future<void> _runMatchSsot() async {
    final url = WsConfig.dartAuthuserUrl;
    final token = ref.read(authProvider).accessToken;
    if (url.isEmpty || token == null || token.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('play: matchSsot skip (no dart ws url or auth token)');
      }
      return;
    }

    final manager = ref.read(wsConnectionManagerProvider.notifier);
    ref.read(matchSnapshotProvider.notifier).clear();
    // Keep notifier alive for replay listener.
    ref.read(matchSnapshotProvider);

    final already =
        ref.read(wsConnectionManagerProvider).connections[_dartWsId] ?? false;
    if (!already) {
      await manager.connect(_dartWsId, url: url, accessToken: token);
    }

    if (LOGGING_SWITCH) {
      customlog('play: matchSsot create');
    }
    await manager.send(
      _dartWsId,
      type: 'event',
      channel: 'match/create',
      payload: const {},
    );

    final matchId = await _waitForMatchField(
      (s) => s.matchId != null && s.matchId!.isNotEmpty ? s.matchId : null,
      label: 'matchId',
    );
    if (matchId == null) {
      if (LOGGING_SWITCH) {
        customlog('play: matchSsot timed out waiting for create');
      }
      return;
    }

    if (LOGGING_SWITCH) {
      customlog('play: matchSsot end matchId=$matchId');
    }
    await manager.send(
      _dartWsId,
      type: 'event',
      channel: 'match/end',
      payload: {'matchId': matchId},
    );

    final ended = await _waitForMatchField(
      (s) => s.isEnded ? true : null,
      label: 'ended',
    );
    if (ended != true && LOGGING_SWITCH) {
      customlog('play: matchSsot timed out waiting for ended');
    }

    try {
      await manager.send(
        _dartWsId,
        type: 'event',
        channel: 'match/leave',
        payload: {'matchId': matchId},
      );
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('play: matchSsot leave error: $e');
      }
    }
  }

  Future<T?> _waitForMatchField<T>(
    T? Function(MatchSnapshotState state) pick, {
    required String label,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final value = pick(ref.read(matchSnapshotProvider));
      if (value != null) return value;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (LOGGING_SWITCH) {
      customlog('play: matchSsot wait timeout label=$label');
    }
    return null;
  }

  /// Hook: type-dependent post-match. Stub for now.
  Future<void> _runPostMatch() async {
    if (LOGGING_SWITCH) {
      customlog('play: postMatch stub');
    }
  }
}
