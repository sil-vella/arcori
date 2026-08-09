/// Matchmaking orchestration — find/join-or-create, timer, promote to match.
library;

import 'dart:async';

import '../../core/errors/app_error.dart';
import '../../core/http/fastapi_service_client.dart';
import '../../core/state/state_registry.dart';
import '../../utils/dev_logger.dart';
import '../match/match_lifecycle_contract.dart';
import '../match/match_models.dart';
import '../match/match_service.dart';
import '../ops/ops_errors.dart';
import '../ops/ops_state.dart';
import 'matchmaking_ai_client.dart';
import 'matchmaking_errors.dart';
import 'matchmaking_models.dart';
import 'matchmaking_store.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class MatchmakingService {
  MatchmakingService({
    MatchmakingStore? store,
    MatchLifecycleContract? matchLifecycle,
    MatchmakingAiClient? aiClient,
    FastApiServiceClient? fastApi,
    this.fillWindow = const Duration(seconds: 5),
    this.scheduleTimers = true,
    this.targetSeats = defaultTargetSeats,
  })  : _store = store ?? matchmakingStore,
        _match = matchLifecycle ?? matchService,
        _ai = aiClient ?? MatchmakingAiClient(fastApi: fastApi);

  final MatchmakingStore _store;
  final MatchLifecycleContract _match;
  final MatchmakingAiClient _ai;
  final Duration fillWindow;
  final bool scheduleTimers;
  final int targetSeats;

  final Map<String, Timer> _timers = {};
  final Set<String> _promoting = {};

  void reset() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _promoting.clear();
    _store.reset();
  }

  Future<LobbySnapshot> find({
    required String userId,
    required String connectionId,
    required Map<String, dynamic> payload,
  }) async {
    if (drainMode) {
      throw AppError(drainModeError);
    }

    late final Map<String, dynamic> matchType;
    try {
      matchType = parseMatchType(payload);
    } catch (_) {
      throw AppError(
        matchmakingInvalidRequest,
        message: 'matchType.code required (quickStart|specialEvent)',
      );
    }
    final code = matchType['code']?.toString() ?? '';
    if (code != 'quickStart' && code != 'specialEvent') {
      throw AppError(
        matchmakingInvalidRequest,
        message: 'Only quickStart and specialEvent supported',
      );
    }

    final existing = _store.lobbyForUser(userId);
    if (existing != null && existing.phase == 'waiting') {
      return existing;
    }

    final rawArcori = payload['arcoriIds'];
    List<String> arcoriIds = const [];
    if (rawArcori is List) {
      arcoriIds =
          rawArcori.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final slammerId = payload['slammerId']?.toString().trim() ?? '';

    final member = LobbyMember(
      userId: userId,
      connectionId: connectionId,
      arcoriIds: arcoriIds,
      slammerId: slammerId,
    );

    final queueKey = queueKeyFor(matchType);
    var lobby = _store.findOpenLobby(queueKey);
    if (lobby == null) {
      final endsAt = DateTime.now().toUtc().add(fillWindow);
      lobby = _store.createLobby(
        matchType: matchType,
        creator: member,
        endsAt: endsAt,
        targetSeats: targetSeats,
      );
      roomRegistry.subscribe(lobby.lobbyId, connectionId, userId: userId);
      _broadcastLobby(lobby);
      _armTimer(lobby.lobbyId);
      if (LOGGING_SWITCH) {
        customlog(
          'matchmaking: create lobby=${lobby.lobbyId} '
          'queueKey=$queueKey user=$userId endsAt=${lobby.endsAt.toIso8601String()}',
        );
      }
      return lobby;
    }

    lobby = _store.addMember(lobby.lobbyId, member);
    roomRegistry.subscribe(lobby.lobbyId, connectionId, userId: userId);
    _broadcastLobby(lobby);
    if (LOGGING_SWITCH) {
      customlog(
        'matchmaking: join lobby=${lobby.lobbyId} queueKey=$queueKey '
        'user=$userId members=${lobby.members.length}/${lobby.targetSeats}',
      );
    }

    if (lobby.members.length >= lobby.targetSeats) {
      return await promoteLobby(lobby.lobbyId);
    }
    return lobby;
  }

  LobbySnapshot cancel({
    required String userId,
    required String connectionId,
  }) {
    final lobby = _store.lobbyForUser(userId);
    if (lobby == null || lobby.phase != 'waiting') {
      throw AppError(matchmakingNotInLobby);
    }
    roomRegistry.unsubscribe(lobby.lobbyId, connectionId);
    final next = _store.removeMember(lobby.lobbyId, userId);
    if (LOGGING_SWITCH) {
      customlog(
        'matchmaking: cancel lobby=${lobby.lobbyId} user=$userId '
        'phase=${next.phase}',
      );
    }
    if (next.phase == 'cancelled' || next.members.isEmpty) {
      _cancelTimer(lobby.lobbyId);
      return next;
    }
    _broadcastLobby(next);
    return next;
  }

  Future<LobbySnapshot> promoteLobby(String lobbyId) async {
    if (_promoting.contains(lobbyId)) {
      final current = _store.getLobby(lobbyId);
      if (current != null) return current;
    }
    final lobby = _store.getLobby(lobbyId);
    if (lobby == null || lobby.phase != 'waiting') {
      final current = _store.getLobby(lobbyId);
      if (current != null) return current;
      throw AppError(matchmakingNotInLobby);
    }

    _promoting.add(lobbyId);
    _cancelTimer(lobbyId);
    if (LOGGING_SWITCH) {
      customlog(
        'matchmaking: promote start lobby=$lobbyId '
        'humans=${lobby.members.length} target=${lobby.targetSeats} '
        'queueKey=${lobby.queueKey}',
      );
    }
    try {
      final needAi = lobby.targetSeats - lobby.members.length;
      final exclude = lobby.members.map((m) => m.userId).toList();
      List<String> aiIds = const [];
      if (needAi > 0) {
        try {
          aiIds = await _ai.sampleAiUserIds(
            count: needAi,
            excludeUserIds: exclude,
          );
          if (LOGGING_SWITCH) {
            customlog('matchmaking: AI sample count=${aiIds.length} ids=$aiIds');
          }
        } on AppError {
          rethrow;
        } catch (e) {
          throw AppError(
            matchmakingAiUnavailable,
            message: 'AI sample failed: $e',
          );
        }
      }

      final humans = lobby.members
          .map(
            (m) => LobbyHumanSeat(
              userId: m.userId,
              connectionId: m.connectionId,
              arcoriIds: m.arcoriIds,
              slammerId: m.slammerId,
            ),
          )
          .toList();

      late final MatchSnapshot match;
      try {
        match = await _match.startFromLobby(
          matchType: lobby.matchType,
          humans: humans,
          aiUserIds: aiIds,
          targetSeats: lobby.targetSeats,
        );
      } on AppError {
        rethrow;
      } catch (e) {
        throw AppError(
          matchmakingPromoteFailed,
          message: 'Promote failed: $e',
        );
      }

      final promoted = _store.markPromoted(lobbyId, match.matchId);
      _broadcastLobby(promoted);

      for (final m in lobby.members) {
        roomRegistry.unsubscribe(lobby.lobbyId, m.connectionId);
      }
      if (LOGGING_SWITCH) {
        customlog(
          'matchmaking: promote done lobby=$lobbyId → match=${match.matchId} '
          'seats=${match.seats.length}',
        );
      }
      return promoted;
    } finally {
      _promoting.remove(lobbyId);
    }
  }

  void _armTimer(String lobbyId) {
    if (!scheduleTimers) return;
    _cancelTimer(lobbyId);
    _timers[lobbyId] = Timer(fillWindow, () {
      if (LOGGING_SWITCH) {
        customlog('matchmaking: timer fire lobby=$lobbyId');
      }
      unawaited(promoteLobby(lobbyId));
    });
  }

  void _cancelTimer(String lobbyId) {
    _timers.remove(lobbyId)?.cancel();
  }

  void _broadcastLobby(LobbySnapshot lobby) {
    roomBroadcaster.broadcastToRoom(
      lobby.lobbyId,
      channel: 'matchmaking/lobby',
      type: 'event',
      payload: lobby.toPayload(),
    );
  }
}

final matchmakingService = MatchmakingService();

void resetMatchmakingState() {
  matchmakingService.reset();
}
