import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth/auth_providers.dart';
import '../../core/ws/ws_config.dart';
import '../../core/ws/ws_connection_manager.dart';
import '../../utils/dev_logger.dart';
import '../match/state/match_notifier.dart';
import '../match/state/match_snapshot_state.dart';
import '../matchmaking/state/lobby_notifier.dart';
import 'play_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const _dartWsId = 'dart';

/// Stub special-event identity until a real event picker exists.
const stubSpecialEventSubtype = 'royal-battle';
const stubSpecialEventId = 'evt_stub_v1';

final matchFlowProvider =
    NotifierProvider<MatchFlowNotifier, MatchFlowState>(MatchFlowNotifier.new);

/// Owns the Play → type select → setup → match → post-match pipeline.
///
/// Practice is Flutter-only. quickStart/specialEvent use Dart matchmaking.
/// Invite stays a room stub.
class MatchFlowNotifier extends Notifier<MatchFlowState> {
  int _runId = 0;

  @override
  MatchFlowState build() => const MatchFlowState();

  void startPlay() {
    if (!state.isIdle) return;
    _setPhase(MatchFlowPhase.selectingType);
  }

  void cancelSelection() {
    if (state.phase != MatchFlowPhase.selectingType &&
        state.phase != MatchFlowPhase.typeSetup) {
      return;
    }
    _runId++;
    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: cancelSelection → idle');
    }
  }

  /// Clears [MatchFlowState.errorMessage] after the OK modal is dismissed.
  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(clearError: true);
  }

  /// [practiceLoadout] used for practice local seats; ignored for other types.
  Future<void> selectType(
    MatchType type, {
    PracticeLoadout? practiceLoadout,
  }) async {
    if (state.phase != MatchFlowPhase.selectingType) return;

    if (type == MatchType.quickStart || type == MatchType.specialEvent) {
      final gateError = _onlinePlayGateError();
      if (gateError != null) {
        _abortWithMessage(gateError);
        return;
      }
    }

    final runId = ++_runId;
    state = MatchFlowState(
      phase: MatchFlowPhase.typeSetup,
      selectedType: type,
      practiceLoadout: practiceLoadout,
    );
    if (LOGGING_SWITCH) {
      customlog('play: selectType=${type.name} → typeSetup');
    }

    await _runTypeSetup(type);
    if (!_isCurrentRun(runId, type)) return;

    if (type == MatchType.practice) {
      _setPhase(MatchFlowPhase.inMatch);
      await _runPracticeLocal(practiceLoadout);
      if (!_isCurrentRun(runId, type)) return;
    } else if (type == MatchType.quickStart ||
        type == MatchType.specialEvent) {
      await _runOnlineMatchmaking(type);
      if (!_isCurrentRun(runId, type)) return;
    } else {
      await _runRoomCreateStub(type);
      if (!_isCurrentRun(runId, type)) return;
    }

    _setPhase(MatchFlowPhase.postMatch);
    await _runPostMatch();
    if (!_isCurrentRun(runId, type)) return;

    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: pipeline done → idle');
    }
  }

  /// Abort play pipeline; UI shows an OK modal from [errorMessage].
  void _abortWithMessage(String message) {
    _runId++;
    ref.read(lobbySnapshotProvider.notifier).clear();
    state = MatchFlowState(errorMessage: message);
    if (LOGGING_SWITCH) {
      customlog('play: abort → idle message=$message');
    }
  }

  /// Null when online matchmaking may proceed; otherwise user-facing copy.
  String? _onlinePlayGateError() {
    final auth = ref.read(authProvider);
    final token = auth.accessToken;
    if (!auth.isAuthenticated || token == null || token.isEmpty) {
      final authMsg = auth.errorMessage?.trim();
      if (authMsg != null && authMsg.isNotEmpty) return authMsg;
      return 'Sign in to play online.';
    }
    if (WsConfig.dartAuthuserUrl.isEmpty) {
      return 'Online matchmaking is unavailable right now.';
    }
    return null;
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

  Future<void> _runTypeSetup(MatchType type) async {
    if (LOGGING_SWITCH) {
      customlog(
        'play: typeSetup type=${type.name} '
        'loadout=${state.practiceLoadout?.arcoriId ?? '-'}',
      );
    }
  }

  /// Step delay for auto stub practice loop (tests may set [Duration.zero]).
  Duration practiceStubStepDelay = practiceStubStepDelayDefault;

  /// When true (default), online caller auto-sends match/end after promote (stub).
  bool autoEndOnlineMatch = true;

  /// Flutter-only practice: local human + 2 AI. Auto stub loop then end.
  Future<void> _runPracticeLocal(PracticeLoadout? loadout) async {
    final effective = loadout ??
        const PracticeLoadout(
          arcoriId: 'ANM-TIG-GEN001-0001',
          slammerId: stubSlammerId,
        );
    final userId = ref.read(authProvider).userId?.trim();
    final humanId =
        (userId != null && userId.isNotEmpty) ? userId : 'local';

    final match = ref.read(matchSnapshotProvider.notifier);
    match.clear();
    match.startLocalPractice(humanUserId: humanId, loadout: effective);

    if (LOGGING_SWITCH) {
      customlog(
        'play: practiceLocal started human=$humanId '
        'arcori=${effective.arcoriId}',
      );
    }

    await match.runLocalPracticeStubMatch(stepDelay: practiceStubStepDelay);

    if (LOGGING_SWITCH) {
      final snap = ref.read(matchSnapshotProvider);
      customlog(
        'play: practiceLocal finished ended=${snap.isEnded} '
        'round=${snap.round}',
      );
    }
    match.clear();
  }

  /// Quick Join / Special Event: Dart matchmaking find → promote → match room.
  Future<void> _runOnlineMatchmaking(MatchType type) async {
    // Gate already checked in [selectType]; re-check in case session dropped.
    final gateError = _onlinePlayGateError();
    if (gateError != null) {
      _abortWithMessage(gateError);
      return;
    }

    final url = WsConfig.dartAuthuserUrl;
    final token = ref.read(authProvider).accessToken!;

    final manager = ref.read(wsConnectionManagerProvider.notifier);
    ref.read(matchSnapshotProvider.notifier).clear();
    ref.read(lobbySnapshotProvider.notifier).clear();
    // Ensure match + lobby listeners are mounted.
    ref.read(matchSnapshotProvider);
    ref.read(lobbySnapshotProvider);

    final already =
        ref.read(wsConnectionManagerProvider).connections[_dartWsId] ?? false;
    if (!already) {
      await manager.connect(_dartWsId, url: url, accessToken: token);
    }

    final matchType = _matchTypePayload(type);
    if (LOGGING_SWITCH) {
      customlog('play: onlineMatchmaking find matchType=$matchType');
    }

    await manager.send(
      _dartWsId,
      type: 'event',
      channel: 'matchmaking/find',
      payload: {'matchType': matchType},
    );

    final promoted = await _waitForLobbyPromoted(
      timeout: const Duration(seconds: 30),
    );
    if (promoted == null) {
      if (LOGGING_SWITCH) {
        customlog('play: onlineMatchmaking timed out waiting for promote');
      }
      try {
        await manager.send(
          _dartWsId,
          type: 'event',
          channel: 'matchmaking/cancel',
          payload: const {},
        );
      } catch (_) {}
      _abortWithMessage(
        'Could not find players in time. Please try again.',
      );
      return;
    }

    _setPhase(MatchFlowPhase.inMatch);

    final matchId = await _waitForMatchField(
      (s) => s.matchId != null && s.matchId!.isNotEmpty ? s.matchId : null,
      label: 'matchId',
      timeout: const Duration(seconds: 15),
    );
    if (matchId == null) {
      if (LOGGING_SWITCH) {
        customlog('play: onlineMatchmaking missing match snapshot');
      }
      _abortWithMessage('Match failed to start. Please try again.');
      return;
    }

    if (autoEndOnlineMatch) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final snap = ref.read(matchSnapshotProvider);
      final userId = ref.read(authProvider).userId?.trim();
      if (!snap.isEnded &&
          userId != null &&
          userId.isNotEmpty &&
          snap.callerUserId == userId) {
        try {
          await manager.send(
            _dartWsId,
            type: 'event',
            channel: 'match/end',
            payload: {'matchId': matchId},
          );
        } catch (e) {
          if (LOGGING_SWITCH) {
            customlog('play: onlineMatchmaking auto-end error: $e');
          }
        }
      }
    }

    await _waitForMatchField(
      (s) => s.isEnded ? true : null,
      label: 'ended',
      timeout: const Duration(minutes: 30),
    );

    try {
      await manager.send(
        _dartWsId,
        type: 'event',
        channel: 'match/leave',
        payload: {'matchId': matchId},
      );
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('play: onlineMatchmaking leave error: $e');
      }
    }

    ref.read(matchSnapshotProvider.notifier).clear();
    ref.read(lobbySnapshotProvider.notifier).clear();
  }

  Map<String, dynamic> _matchTypePayload(MatchType type) {
    if (type == MatchType.specialEvent) {
      return {
        'code': 'specialEvent',
        'subtype': stubSpecialEventSubtype,
        'eventId': stubSpecialEventId,
      };
    }
    return {'code': 'quickStart'};
  }

  Future<bool?> _waitForLobbyPromoted({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final lobby = ref.read(lobbySnapshotProvider);
      if (lobby.isPromoted) return true;
      final match = ref.read(matchSnapshotProvider);
      if (match.matchId != null && match.matchId!.isNotEmpty) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
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
      customlog('play: wait timeout label=$label');
    }
    return null;
  }

  /// Invite — stub only (no WS).
  Future<void> _runRoomCreateStub(MatchType type) async {
    if (LOGGING_SWITCH) {
      customlog('play: roomCreateStub type=${type.name} (invite stub, no WS)');
    }
  }

  Future<void> _runPostMatch() async {
    if (LOGGING_SWITCH) {
      customlog('play: postMatch stub');
    }
  }
}
