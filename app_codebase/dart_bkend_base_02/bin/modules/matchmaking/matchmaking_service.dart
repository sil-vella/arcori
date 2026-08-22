/// Matchmaking orchestration — find/join-or-create, timer, promote to match.
library;

import 'dart:async';
import 'dart:convert';

import '../../core/errors/app_error.dart';
import '../../core/auth/auth_config.dart';
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
        _fastApi = fastApi ?? FastApiServiceClient(),
        _ai = aiClient ?? MatchmakingAiClient(fastApi: fastApi ?? FastApiServiceClient());

  final MatchmakingStore _store;
  final MatchLifecycleContract _match;
  final FastApiServiceClient _fastApi;
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

  Future<Map<String, dynamic>?> _resolveInviteForAi(String inviteId) async {
    final trimmed = inviteId.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.parse(
      '${_fastApi.baseUrl}/service/friend_match_invites/resolve',
    );

    try {
      final response = await _fastApi.client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Service-Key': serviceKey(),
            },
            body: jsonEncode({'inviteId': trimmed}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (LOGGING_SWITCH) {
          customlog(
            'matchmaking: invite resolve failed status=${response.statusCode} '
            'inviteId=$trimmed body=${response.body}',
          );
        }
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      if (decoded['ok'] != true) {
        if (LOGGING_SWITCH) {
          customlog(
            'matchmaking: invite resolve envelope not ok inviteId=$trimmed '
            'body=${response.body}',
          );
        }
        return null;
      }

      final data = decoded['data'];
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      if (LOGGING_SWITCH) {
        customlog(
          'matchmaking: invite resolve ok inviteId=$trimmed '
          'invitedUserId=${map['invitedUserId']} isAi=${map['isAi']}',
        );
      }
      return map;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('matchmaking: invite resolve error inviteId=$trimmed err=$e');
      }
      return null;
    }
  }

  Future<bool> _checkUserIsAi(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.parse('${_fastApi.baseUrl}/service/players/is_ai');

    try {
      final response = await _fastApi.client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Service-Key': serviceKey(),
            },
            body: jsonEncode({'userId': trimmed}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (LOGGING_SWITCH) {
          customlog(
            'matchmaking: is_ai check failed status=${response.statusCode} '
            'userId=$trimmed',
          );
        }
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) return false;
      final data = decoded['data'];
      if (data is! Map) return false;
      final isAi = data['isAi'] == true;
      if (LOGGING_SWITCH) {
        customlog('matchmaking: is_ai check userId=$trimmed isAi=$isAi');
      }
      return isAi;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('matchmaking: is_ai check error userId=$trimmed err=$e');
      }
      return false;
    }
  }

  Future<({String invitedUserId, bool isAi})?> _resolveInvitedSeatForInvite(
    Map<String, dynamic> matchType,
  ) async {
    final inviteId = matchType['subtype']?.toString().trim() ?? '';
    var invitedUserId = matchType['invitedUserId']?.toString().trim() ?? '';

    if (invitedUserId.isEmpty && inviteId.isNotEmpty) {
      final resolved = await _resolveInviteForAi(inviteId);
      invitedUserId = resolved?['invitedUserId']?.toString().trim() ?? '';
      if (resolved?['isAi'] == true && invitedUserId.isNotEmpty) {
        return (invitedUserId: invitedUserId, isAi: true);
      }
    }

    if (invitedUserId.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog(
          'matchmaking: invite seat unresolved inviteId=$inviteId '
          '(no invitedUserId on matchType and resolve failed)',
        );
      }
      return null;
    }

    final isAi = await _checkUserIsAi(invitedUserId);
    return (invitedUserId: invitedUserId, isAi: isAi);
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
        message: 'matchType.code required (quickStart|specialEvent|invite)',
      );
    }
    final code = matchType['code']?.toString() ?? '';
    if (code != 'quickStart' && code != 'specialEvent' && code != 'invite') {
      throw AppError(
        matchmakingInvalidRequest,
        message: 'Only quickStart, specialEvent, and invite supported',
      );
    }

    final inviteId = matchType['subtype']?.toString().trim() ?? '';
    if (code == 'invite' && inviteId.isEmpty) {
      throw AppError(
        matchmakingInvalidRequest,
        message: 'invite requires matchType.subtype=inviteId',
      );
    }

    final rawCreateIfMissing = payload['createIfMissing'];
    final createIfMissing = rawCreateIfMissing is bool ? rawCreateIfMissing : true;

    final effectiveTargetSeats = (code == 'invite') ? 2 : targetSeats;

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
      if (code == 'invite' && !createIfMissing) {
        throw AppError(matchmakingInviteNotFound);
      }
      final effectiveFillWindow =
          code == 'invite' ? const Duration(seconds: 20) : fillWindow;
      final endsAt = DateTime.now().toUtc().add(effectiveFillWindow);
      lobby = _store.createLobby(
        matchType: matchType,
        creator: member,
        endsAt: endsAt,
        targetSeats: effectiveTargetSeats,
      );
      roomRegistry.subscribe(lobby.lobbyId, connectionId, userId: userId);
      _broadcastLobby(lobby);
      _armTimer(lobby.lobbyId, effectiveFillWindow);
      if (LOGGING_SWITCH) {
        customlog(
          'matchmaking: create lobby=${lobby.lobbyId} '
          'queueKey=$queueKey user=$userId endsAt=${lobby.endsAt.toIso8601String()}',
        );
      }
      // Invite contract special-case: if the invited user is an offline AI,
      // we can auto-promote immediately (so the waiting modal doesn't stick).
      if (code == 'invite' && lobby.members.length == lobby.targetSeats - 1) {
        try {
          return await promoteLobby(lobby.lobbyId);
        } on AppError catch (e) {
          if (e.code == matchmakingInviteNeedsMoreHumans.code) {
            return lobby;
          }
          rethrow;
        }
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

    // Invite contract special-case: if we have host + one missing seat,
    // and that missing invitee is an offline AI, auto-promote immediately.
    final isInvite = lobby.matchType['code']?.toString() == 'invite';
    if (isInvite && lobby.members.length == lobby.targetSeats - 1) {
      try {
        return await promoteLobby(lobby.lobbyId);
      } on AppError catch (e) {
        if (e.code == matchmakingInviteNeedsMoreHumans.code) {
          // Invited seat isn't an AI (or resolve failed); stay waiting.
          return lobby;
        }
        rethrow;
      }
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

      final isInvite = lobby.matchType['code']?.toString() == 'invite';
      if (needAi > 0) {
        if (isInvite) {
          // For invite lobbies we normally require a 2nd human (no AI fill).
          // If the invited user is an offline AI, we auto-fill that seat.
          if (needAi != 1) {
            throw AppError(matchmakingInviteNeedsMoreHumans);
          }
          final seat = await _resolveInvitedSeatForInvite(lobby.matchType);
          if (seat == null || !seat.isAi || seat.invitedUserId.isEmpty) {
            if (LOGGING_SWITCH) {
              customlog(
                'matchmaking: invite needs human lobby=$lobbyId '
                'seat=${seat?.invitedUserId} isAi=${seat?.isAi}',
              );
            }
            throw AppError(matchmakingInviteNeedsMoreHumans);
          }
          aiIds = [seat.invitedUserId];
          if (LOGGING_SWITCH) {
            customlog(
              'matchmaking: invite auto-fill AI seat=${seat.invitedUserId} '
              'lobby=$lobbyId',
            );
          }
        } else {
          try {
            aiIds = await _ai.sampleAiUserIds(
              count: needAi,
              excludeUserIds: exclude,
            );
            if (LOGGING_SWITCH) {
              customlog(
                'matchmaking: AI sample count=${aiIds.length} ids=$aiIds',
              );
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

  void _armTimer(String lobbyId, Duration delay) {
    if (!scheduleTimers) return;
    _cancelTimer(lobbyId);
    _timers[lobbyId] = Timer(delay, () {
      if (LOGGING_SWITCH) {
        customlog('matchmaking: timer fire lobby=$lobbyId');
      }
      unawaited(_timeoutPromoteOrCancel(lobbyId));
    });
  }

  Future<void> _timeoutPromoteOrCancel(String lobbyId) async {
    final current = _store.getLobby(lobbyId);
    if (current == null || current.phase != 'waiting') return;

    final isInvite = current.matchType['code']?.toString() == 'invite';
    if (isInvite && current.members.length < current.targetSeats) {
      // Invite contract: 2 humans, no AI fill.
      // However, if the missing invitee is an offline AI, promotion should
      // succeed (and we don't cancel).
      try {
        await promoteLobby(lobbyId);
        return;
      } on AppError catch (e) {
        if (e.code != matchmakingInviteNeedsMoreHumans.code) {
          // Unknown invite failure: keep consistent with previous behavior.
          rethrow;
        }
      }

      // Not an AI (or resolve failed): cancel instead of waiting forever.
      final members = List<LobbyMember>.from(current.members);
      final cancelled = _store.cancelLobby(lobbyId);
      _broadcastLobby(cancelled);
      for (final m in members) {
        roomRegistry.unsubscribe(lobbyId, m.connectionId);
      }
      return;
    }

    await promoteLobby(lobbyId);
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
