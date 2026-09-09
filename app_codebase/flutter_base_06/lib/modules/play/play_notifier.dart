import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_policy.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/ws/ws_config.dart';
import '../../core/ws/ws_connection_manager.dart';
import '../../utils/dev_logger.dart';
import '../avari/avari_api.dart';
import '../avari/avari_notifier.dart';
import '../match/input/turn_pacing.dart';
import '../match/state/match_notifier.dart';
import '../match/state/match_snapshot_state.dart';
import '../matchmaking/state/lobby_notifier.dart';
import 'friend_match_invite_api.dart';
import 'game_controls_prefs.dart';
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
/// Invite uses Dart matchmaking via a dedicated invite lobby.
class MatchFlowNotifier extends Notifier<MatchFlowState> {
  int _runId = 0;
  Completer<PostMatchExitAction>? _postMatchExit;
  bool _finalizeStarted = false;

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

  /// Rematch exit — host creates rematch invite after leave (see pipeline).
  void completePostMatchRematch() {
    _completePostMatch(PostMatchExitAction.rematch);
  }

  /// True when Rematch should be enabled on the post-match modal.
  bool rematchAvailable() {
    return _captureRematchContext() != null;
  }

  String? rematchDisabledReason() {
    if (state.phase != MatchFlowPhase.postMatch) return null;
    if (state.selectedType == MatchType.practice) {
      return 'Rematch is not available for Practice.';
    }
    if (state.selectedType == null) return 'Rematch unavailable.';
    final me = ref.read(authProvider).userId?.trim() ?? '';
    final snap = ref.read(matchSnapshotProvider);
    final otherHumans = snap.seats
        .where((s) => s.kind == 'human' && s.userId.trim().isNotEmpty)
        .where((s) => s.userId.trim() != me)
        .length;
    final aiSeats = snap.seats
        .where((s) => s.kind == 'ai' && s.userId.trim().isNotEmpty)
        .length;
    if (otherHumans == 0 && aiSeats == 0) {
      return 'Rematch needs another player.';
    }
    return null;
  }

  /// Leave room, clear snapshots, return to idle.
  void completePostMatchDone() {
    _completePostMatch(PostMatchExitAction.done);
  }

  /// Leave room, clear, then restart Quick Start from the top.
  void completePostMatchPlayNew() {
    _completePostMatch(PostMatchExitAction.playNew);
  }

  void _completePostMatch(PostMatchExitAction action) {
    final c = _postMatchExit;
    if (c == null || c.isCompleted) return;
    if (LOGGING_SWITCH) {
      customlog('play: postMatch exit=${action.name}');
    }
    c.complete(action);
  }

  /// [practiceLoadout] used for practice local seats; ignored for other types.
  Future<void> selectType(
    MatchType type, {
    PracticeLoadout? practiceLoadout,
    String? inviteId,
    String? invitedUserId,
  }) async {
    if (state.phase != MatchFlowPhase.selectingType) return;

    if (type == MatchType.quickStart ||
        type == MatchType.specialEvent ||
        type == MatchType.invite) {
      final gateError = _onlinePlayGateError();
      if (gateError != null) {
        _abortWithMessage(gateError);
        return;
      }
    }

    if (type == MatchType.invite &&
        (inviteId == null || inviteId.trim().isEmpty)) {
      _abortWithMessage('Invite id missing. Please try again.');
      return;
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
    } else if (type == MatchType.invite) {
      await _runInviteMatchmaking(
        inviteId: inviteId!,
        invitedUserId: invitedUserId ?? '',
        createIfMissing: true,
      );
      if (!_isCurrentRun(runId, type)) return;
    } else {
      await _runRoomCreateStub(type);
      if (!_isCurrentRun(runId, type)) return;
    }

    _setPhase(MatchFlowPhase.postMatch);
    final exit = await _runPostMatch(type);
    if (!_isCurrentRun(runId, type)) return;

    final rematchCtx =
        exit == PostMatchExitAction.rematch ? _captureRematchContext() : null;

    await _leaveAndClearEndedMatch(online: type != MatchType.practice);
    if (!_isCurrentRun(runId, type)) return;

    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: pipeline done → idle');
    }

    if (exit == PostMatchExitAction.rematch) {
      if (rematchCtx == null || !rematchCtx.canRematch) {
        _abortWithMessage('Rematch needs another player.');
        return;
      }
      await _runRematchHost(rematchCtx);
      return;
    }

    if (exit == PostMatchExitAction.playNew) {
      startPlay();
      await selectType(MatchType.quickStart);
    }
  }

  /// Notification guest entrypoint: join an existing invite lobby.
  ///
  /// Expected: caller already invoked [startPlay], so UI is in
  /// [MatchFlowPhase.selectingType]. If not, we still allow from idle.
  Future<void> startInviteJoin({required String inviteId}) async {
    final gateError = _onlinePlayGateError();
    if (gateError != null) {
      _abortWithMessage(gateError);
      return;
    }

    if (!state.isIdle && state.phase != MatchFlowPhase.selectingType) {
      return;
    }

    if (state.isIdle) {
      startPlay();
      if (state.phase != MatchFlowPhase.selectingType) return;
    }

    if (inviteId.trim().isEmpty) {
      _abortWithMessage('Invite id missing. Please try again.');
      return;
    }

    final runId = ++_runId;
    state = MatchFlowState(
      phase: MatchFlowPhase.typeSetup,
      selectedType: MatchType.invite,
    );

    await _runInviteMatchmaking(
      inviteId: inviteId.trim(),
      invitedUserId: '',
      createIfMissing: false,
    );
    if (!_isCurrentRun(runId, MatchType.invite)) return;

    _setPhase(MatchFlowPhase.postMatch);
    final exit = await _runPostMatch(MatchType.invite);
    if (!_isCurrentRun(runId, MatchType.invite)) return;

    final rematchCtx =
        exit == PostMatchExitAction.rematch ? _captureRematchContext() : null;

    await _leaveAndClearEndedMatch(online: true);
    if (!_isCurrentRun(runId, MatchType.invite)) return;

    state = const MatchFlowState();
    if (exit == PostMatchExitAction.rematch) {
      if (rematchCtx == null || !rematchCtx.canRematch) {
        _abortWithMessage('Rematch needs another player.');
        return;
      }
      await _runRematchHost(rematchCtx);
      return;
    }
    if (exit == PostMatchExitAction.playNew) {
      startPlay();
      await selectType(MatchType.quickStart);
    }
  }

  /// Abort play pipeline; UI shows an OK modal from [errorMessage].
  void _abortWithMessage(String message) {
    _runId++;
    final pending = _postMatchExit;
    if (pending != null && !pending.isCompleted) {
      pending.complete(PostMatchExitAction.done);
    }
    _postMatchExit = null;
    _finalizeStarted = false;
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

  /// Tests only: collapse grace/timeouts so practice reaches postMatch instantly.
  bool practiceFastStub = false;

  String get _equippedSlammerId {
    final id = ref.read(gameControlsProvider).equippedSlammerId.trim();
    return id.isNotEmpty ? id : stubSlammerId;
  }

  /// Flutter-only practice: local human + 2 AI, paced turns (same as multi), then end.
  Future<void> _runPracticeLocal(PracticeLoadout? loadout) async {
    final effective = loadout ??
        PracticeLoadout(
          arcoriId: 'ANM-TIG-GEN001-0001',
          slammerId: _equippedSlammerId,
        );
    final userId = ref.read(authProvider).userId?.trim();
    final humanId =
        (userId != null && userId.isNotEmpty) ? userId : 'local';

    final match = ref.read(matchSnapshotProvider.notifier);
    // Always assign pacing so a prior fast/test run cannot leave Duration.zero stuck.
    if (practiceFastStub) {
      match.practiceMatchStartGrace = Duration.zero;
      match.practiceTurnTimeout = Duration.zero;
      match.practiceAiDelayMin = Duration.zero;
      match.practiceAiDelayMax = Duration.zero;
      match.practiceAiMissProbability = 0;
      match.practicePostSlamAnimHold = Duration.zero;
    } else {
      match.practiceMatchStartGrace = matchStartGraceDefault;
      match.practiceTurnTimeout = turnTimeoutDefault;
      match.practiceAiDelayMin = aiDelayMinDefault;
      match.practiceAiDelayMax = aiDelayMaxDefault;
      match.practiceAiMissProbability = aiMissProbabilityDefault;
      match.practicePostSlamAnimHold = postSlamAnimHoldDefault;
    }
    match.clear();
    match.startLocalPractice(humanUserId: humanId, loadout: effective);

    if (LOGGING_SWITCH) {
      customlog(
        'play: practiceLocal started human=$humanId '
        'arcori=${effective.arcoriId}',
      );
    }

    await match.runLocalPracticeTurnMatch();

    if (LOGGING_SWITCH) {
      final snap = ref.read(matchSnapshotProvider);
      customlog(
        'play: practiceLocal finished ended=${snap.isEnded} '
        'round=${snap.round}',
      );
    }
    // Keep ended snapshot for post-match UI / rematch context.
  }

  /// Quick Join / Special Event: Dart matchmaking find → promote → match room.
  Future<void> _runOnlineMatchmaking(MatchType type) async {
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
    ref.read(matchSnapshotProvider);
    ref.read(lobbySnapshotProvider);

    final already =
        ref.read(wsConnectionManagerProvider).connections[_dartWsId] ?? false;
    if (!already) {
      await manager.connect(_dartWsId, url: url, accessToken: token);
    }

    final matchType = _matchTypePayload(type);
    final slammerId = _equippedSlammerId;
    if (LOGGING_SWITCH) {
      customlog(
        'play: onlineMatchmaking find matchType=$matchType '
        'slammerId=$slammerId',
      );
    }

    await manager.send(
      _dartWsId,
      type: 'event',
      channel: 'matchmaking/find',
      payload: {
        'matchType': matchType,
        'slammerId': slammerId,
      },
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
      } catch (e) {
        if (LOGGING_SWITCH) {
          customlog('play: onlineMatchmaking cancel error: $e');
        }
      }
      _abortWithMessage(
        'Could not find players in time. Please try again.',
      );
      return;
    }

    _setPhase(MatchFlowPhase.inMatch);

    // Require a live (non-ended) snapshot so a stale post-leave ended frame
    // cannot satisfy matchId / ended waits (Play New race).
    final matchId = await _waitForMatchField(
      (s) {
        final id = s.matchId;
        if (id == null || id.isEmpty) return null;
        if (s.isEnded) return null;
        if (ref.read(matchSnapshotProvider.notifier).isIgnoredMatchId(id)) {
          return null;
        }
        return id;
      },
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

    // Keep room + snapshot for post-match (leave on Done / Play New).
    await _waitForMatchField(
      (s) => (s.matchId == matchId && s.isEnded) ? true : null,
      label: 'ended',
      timeout: const Duration(minutes: 30),
    );
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

  Map<String, dynamic> _inviteMatchTypePayload(
    String inviteId, {
    String invitedUserId = '',
    RematchHostContext? rematch,
  }) {
    final payload = <String, dynamic>{
      'code': 'invite',
      'subtype': inviteId,
    };
    final invited = invitedUserId.trim();
    if (invited.isNotEmpty) {
      payload['invitedUserId'] = invited;
    }
    if (rematch != null) {
      payload['rematch'] = true;
      payload['seriesId'] = rematch.seriesId;
      payload['seriesIndex'] = rematch.seriesIndex;
      payload['priorMatchId'] = rematch.priorMatchId;
      payload['rematchTargetSeats'] = rematch.rematchTargetSeats;
      payload['rematchSeats'] = rematch.rematchSeats;
      if (rematch.priorAiUserIds.isNotEmpty) {
        payload['priorAiUserIds'] = rematch.priorAiUserIds;
      }
    }
    return payload;
  }

  RematchHostContext? _captureRematchContext() {
    final type = state.selectedType;
    if (type == null || type == MatchType.practice) return null;
    if (state.phase != MatchFlowPhase.postMatch) return null;

    final snap = ref.read(matchSnapshotProvider);
    final prior = snap.matchId?.trim() ?? '';
    if (prior.isEmpty) return null;

    final me = ref.read(authProvider).userId?.trim() ?? '';
    final humans = snap.seats
        .where((s) => s.kind == 'human')
        .map((s) => s.userId.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final others = humans.where((id) => id != me).toList();
    final aiIds = snap.seats
        .where((s) => s.kind == 'ai')
        .map((s) => s.userId.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    // Online rematch: other humans and/or the same prior AI seats.
    if (others.isEmpty && aiIds.isEmpty) return null;

    final series = (snap.seriesId != null && snap.seriesId!.trim().isNotEmpty)
        ? snap.seriesId!.trim()
        : prior;
    final nextIndex = snap.seriesIndex >= 1 ? snap.seriesIndex + 1 : 2;
    final rematchSeats = [
      for (final s in snap.seats)
        {
          'userId': s.userId,
          'kind': s.kind,
          'arcoriIds': List<String>.from(s.arcoriIds),
          'slammerId': s.slammerId,
        },
    ];
    return RematchHostContext(
      priorMatchId: prior,
      seriesId: series,
      seriesIndex: nextIndex,
      otherHumanIds: others,
      priorAiUserIds: aiIds,
      rematchSeats: rematchSeats,
      rematchTargetSeats:
          snap.seats.isNotEmpty ? snap.seats.length : humans.length,
    );
  }

  Future<void> _runRematchHost(RematchHostContext ctx) async {
    final gateError = _onlinePlayGateError();
    if (gateError != null) {
      _abortWithMessage(gateError);
      return;
    }

    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      _abortWithMessage('Sign in to rematch.');
      return;
    }

    final runId = ++_runId;
    state = const MatchFlowState(
      phase: MatchFlowPhase.typeSetup,
      selectedType: MatchType.invite,
    );
    if (LOGGING_SWITCH) {
      customlog(
        'play: rematch host start series=${ctx.seriesId} '
        'index=${ctx.seriesIndex} prior=${ctx.priorMatchId} '
        'humans=${ctx.otherHumanIds} ai=${ctx.priorAiUserIds}',
      );
    }

    final inviteeIds = <String>[
      ...ctx.otherHumanIds,
      ...ctx.priorAiUserIds,
    ];
    final api = FriendMatchInviteApiClient();
    final outcome = await api.createRematch(
      accessToken: token,
      priorMatchId: ctx.priorMatchId,
      seriesId: ctx.seriesId,
      seriesIndex: ctx.seriesIndex,
      invitedUserIds: inviteeIds,
    );
    if (!outcome.isSuccess) {
      final msg = _messageForRematchInviteOutcome(outcome);
      _abortWithMessage(msg);
      return;
    }
    final inviteId = outcome.data!.trim();
    if (inviteId.isEmpty) {
      _abortWithMessage('Rematch invite failed. Please try again.');
      return;
    }

    final invitedUserId = ctx.otherHumanIds.isNotEmpty
        ? ctx.otherHumanIds.first
        : (ctx.priorAiUserIds.isNotEmpty ? ctx.priorAiUserIds.first : '');
    await _runInviteMatchmaking(
      inviteId: inviteId,
      invitedUserId: invitedUserId,
      createIfMissing: true,
      rematch: ctx,
    );
    if (!_isCurrentRun(runId, MatchType.invite)) return;

    _setPhase(MatchFlowPhase.postMatch);
    final exit = await _runPostMatch(MatchType.invite);
    if (!_isCurrentRun(runId, MatchType.invite)) return;

    final nextRematch =
        exit == PostMatchExitAction.rematch ? _captureRematchContext() : null;

    await _leaveAndClearEndedMatch(online: true);
    if (!_isCurrentRun(runId, MatchType.invite)) return;

    state = const MatchFlowState();
    if (LOGGING_SWITCH) {
      customlog('play: rematch pipeline done → idle exit=${exit.name}');
    }
    if (exit == PostMatchExitAction.rematch) {
      if (nextRematch == null || !nextRematch.canRematch) {
        _abortWithMessage('Rematch needs another player.');
        return;
      }
      await _runRematchHost(nextRematch);
      return;
    }
    if (exit == PostMatchExitAction.playNew) {
      startPlay();
      await selectType(MatchType.quickStart);
    }
  }

  String _messageForRematchInviteOutcome(
    FriendMatchInviteApiOutcome<String> outcome,
  ) {
    if (outcome.isNetworkError) {
      return 'Network error. Check connection and try again.';
    }
    final err = outcome.error;
    if (err == null) return 'Rematch invite failed. Please try again.';
    final action = actionForApiError(err, isWebSocket: false);
    final raw = err.rawCode;
    if (raw.contains('rematch_no_humans')) {
      return 'Rematch needs another player.';
    }
    if (raw.contains('rematch_series_invalid')) {
      return 'Rematch series is invalid. Please start a new match.';
    }
    switch (action) {
      case ErrorAction.reLogin:
        return 'Session expired. Sign in again.';
      case ErrorAction.retry:
      case ErrorAction.refreshAndRetry:
      case ErrorAction.showMessage:
      case ErrorAction.reconnectWs:
        return err.message.isNotEmpty
            ? err.message
            : 'Rematch invite failed. Please try again.';
    }
  }

  /// Invite Friend Match: Dart matchmaking find → promote → match room.
  Future<void> _runInviteMatchmaking({
    required String inviteId,
    required String invitedUserId,
    required bool createIfMissing,
    RematchHostContext? rematch,
  }) async {
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
    ref.read(matchSnapshotProvider);
    ref.read(lobbySnapshotProvider);

    final already =
        ref.read(wsConnectionManagerProvider).connections[_dartWsId] ?? false;
    if (!already) {
      await manager.connect(_dartWsId, url: url, accessToken: token);
    }

    final matchType = _inviteMatchTypePayload(
      inviteId,
      invitedUserId: invitedUserId,
      rematch: rematch,
    );
    final slammerId = _equippedSlammerId;
    if (LOGGING_SWITCH) {
      customlog(
        'play: invite matchmaking find matchType=$matchType '
        'createIfMissing=$createIfMissing slammerId=$slammerId',
      );
    }

    await manager.send(
      _dartWsId,
      type: 'event',
      channel: 'matchmaking/find',
      payload: {
        'matchType': matchType,
        'createIfMissing': createIfMissing,
        'slammerId': slammerId,
      },
    );

    final promoted = await _waitForLobbyPromoted(
      timeout: const Duration(seconds: 25),
    );
    if (promoted == null) {
      if (LOGGING_SWITCH) {
        customlog('play: invite matchmaking timed out waiting for promote');
      }
      if (createIfMissing) {
        try {
          await manager.send(
            _dartWsId,
            type: 'event',
            channel: 'matchmaking/cancel',
            payload: const {},
          );
        } catch (e) {
          if (LOGGING_SWITCH) {
            customlog('play: invite cancel error: $e');
          }
        }
      }
      _abortWithMessage(
        createIfMissing
            ? (rematch != null
                ? 'Rematch timed out. Please try again.'
                : 'Invite timed out. Please try again.')
            : 'Invite not found or expired.',
      );
      return;
    }

    _setPhase(MatchFlowPhase.inMatch);

    final matchId = await _waitForMatchField(
      (s) {
        final id = s.matchId;
        if (id == null || id.isEmpty) return null;
        if (s.isEnded) return null;
        if (ref.read(matchSnapshotProvider.notifier).isIgnoredMatchId(id)) {
          return null;
        }
        return id;
      },
      label: 'matchId',
      timeout: const Duration(seconds: 15),
    );
    if (matchId == null) {
      if (LOGGING_SWITCH) {
        customlog('play: invite matchmaking missing match snapshot');
      }
      _abortWithMessage('Match failed to start. Please try again.');
      return;
    }

    await _waitForMatchField(
      (s) => (s.matchId == matchId && s.isEnded) ? true : null,
      label: 'ended',
      timeout: const Duration(minutes: 30),
    );
  }

  Future<bool?> _waitForLobbyPromoted({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    var ticks = 0;
    while (DateTime.now().isBefore(deadline)) {
      final lobby = ref.read(lobbySnapshotProvider);
      if (lobby.phase == 'cancelled') {
        if (LOGGING_SWITCH) {
          customlog('play: lobby cancelled while waiting for promote');
        }
        return null;
      }
      if (lobby.isPromoted) {
        if (LOGGING_SWITCH) {
          customlog(
            'play: lobby promoted lobbyId=${lobby.lobbyId} '
            'matchId=${lobby.matchId}',
          );
        }
        return true;
      }
      final match = ref.read(matchSnapshotProvider);
      if (match.matchId != null &&
          match.matchId!.isNotEmpty &&
          !match.isEnded &&
          !ref
              .read(matchSnapshotProvider.notifier)
              .isIgnoredMatchId(match.matchId)) {
        if (LOGGING_SWITCH) {
          customlog('play: match snapshot ready matchId=${match.matchId}');
        }
        return true;
      }
      ticks++;
      if (LOGGING_SWITCH && ticks % 20 == 0) {
        customlog(
          'play: waiting promote lobbyId=${lobby.lobbyId} '
          'phase=${lobby.phase} members=${lobby.members.length}/'
          '${lobby.targetSeats} matchId=${match.matchId}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (LOGGING_SWITCH) {
      customlog('play: lobby promote wait timed out');
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

  Future<void> _runRoomCreateStub(MatchType type) async {
    if (LOGGING_SWITCH) {
      customlog('play: roomCreateStub type=${type.name} (no WS stub)');
    }
  }

  Future<PostMatchExitAction> _runPostMatch(MatchType type) async {
    if (LOGGING_SWITCH) {
      customlog('play: postMatch waiting for exit type=${type.name}');
    }
    _finalizeStarted = false;
    _postMatchExit = Completer<PostMatchExitAction>();
    unawaited(_requestFinalize(type));
    final exit = await _postMatchExit!.future;
    _postMatchExit = null;
    return exit;
  }

  /// Soft finalize for the post-match modal (idempotent within a postMatch).
  Future<void> requestPostMatchFinalize() async {
    final type = state.selectedType;
    if (type == null || state.phase != MatchFlowPhase.postMatch) return;
    await _requestFinalize(type);
  }

  Future<void> _requestFinalize(MatchType type) async {
    if (_finalizeStarted) return;
    _finalizeStarted = true;

    final snap = ref.read(matchSnapshotProvider);
    final matchId = snap.matchId?.trim() ?? '';
    if (matchId.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('play: finalize skip empty matchId');
      }
      return;
    }

    final practice = type == MatchType.practice;
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      // Practice finalize still hits the API when signed in; unsigned skip.
      if (LOGGING_SWITCH) {
        customlog('play: finalize skip missing token practice=$practice');
      }
      return;
    }

    final designIds = <String>{
      for (final seat in snap.seats) ...seat.arcoriIds,
      for (final piece in snap.pieces) piece.designId,
    }.where((id) => id.trim().isNotEmpty).toList();

    final api = ref.read(avariApiClientProvider);
    final outcome = await api.finalizeMatch(
      accessToken: token,
      matchId: matchId,
      matchType: type.name,
      practice: practice,
      designIds: designIds,
      result: snap.result,
    );

    if (outcome.isSuccess) {
      if (LOGGING_SWITCH) {
        customlog(
          'play: finalize ok applied=${outcome.data!.applied} '
          'reason=${outcome.data!.reason}',
        );
      }
      return;
    }

    final msg = _messageForFinalizeOutcome(outcome);
    if (msg != null && msg.isNotEmpty) {
      state = state.copyWith(postMatchSoftError: msg);
    }
    if (LOGGING_SWITCH) {
      customlog(
        'play: finalize soft-fail code=${outcome.error?.code} '
        'network=${outcome.isNetworkError}',
      );
    }
  }

  String? _messageForFinalizeOutcome(AvariApiOutcome<dynamic> outcome) {
    if (outcome.isNetworkError) {
      return 'Network error — rewards will sync later.';
    }
    final error = outcome.error;
    if (error == null) return null;
    actionForApiError(error, isWebSocket: false);
    return error.message;
  }

  Future<void> _leaveAndClearEndedMatch({required bool online}) async {
    _finalizeStarted = false;
    final snap = ref.read(matchSnapshotProvider);
    final matchId = snap.matchId;
    // Clear first + ignore late frames for this id (Play New must not see
    // the previous ended snapshot as the next match).
    ref.read(matchSnapshotProvider.notifier).clear(ignoreMatchId: matchId);
    ref.read(lobbySnapshotProvider.notifier).clear();
    if (LOGGING_SWITCH) {
      customlog(
        'play: postMatch leave+clear matchId=${matchId ?? '-'} online=$online',
      );
    }
    if (online && matchId != null && matchId.isNotEmpty) {
      try {
        final manager = ref.read(wsConnectionManagerProvider.notifier);
        await manager.send(
          _dartWsId,
          type: 'event',
          channel: 'match/leave',
          payload: {'matchId': matchId},
        );
      } catch (e) {
        if (LOGGING_SWITCH) {
          customlog('play: postMatch leave error: $e');
        }
      }
    }
  }
}
