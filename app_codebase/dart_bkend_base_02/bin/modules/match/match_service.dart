/// Match orchestration — create with catalog freeze, join/leave/end + actions.
library;

import 'dart:math';

import '../../core/errors/app_error.dart';
import '../../core/http/fastapi_service_client.dart';
import '../../core/state/state_registry.dart';
import '../../utils/dev_logger.dart';
import 'action_dispatcher.dart';
import 'match_avari_client.dart';
import 'match_catalog_client.dart';
import 'match_errors.dart';
import 'match_lifecycle_contract.dart';
import 'match_models.dart';
import 'match_store.dart';
import 'slam_input.dart';
import 'turn_pacing.dart';
import 'match_turn_runner.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class MatchService implements MatchLifecycleContract {
  MatchService({
    MatchStore? store,
    FastApiServiceClient? fastApi,
    MatchCatalogClient? catalog,
    MatchAvariClient? avari,
    ActionDispatcher? dispatcher,
    bool autoStubTurns = true,
    Duration? turnTimeout,
    Duration? matchStartGrace,
    Random? turnRandom,
  })  : _store = store ?? matchStore,
        _catalog = catalog ?? MatchCatalogClient(fastApi: fastApi),
        _avari = avari ?? MatchAvariClient(fastApi: fastApi),
        _dispatcher =
            dispatcher ?? ActionDispatcher(store: store ?? matchStore),
        autoStubTurns = autoStubTurns {
    stubLoop = MatchTurnRunner(
      store: _store,
      service: this,
      matchStartGrace: matchStartGrace ?? matchStartGraceDefault,
      turnTimeout: turnTimeout ?? turnTimeoutDefault,
      random: turnRandom,
    );
  }

  final MatchStore _store;
  final MatchCatalogClient _catalog;
  final MatchAvariClient _avari;
  final ActionDispatcher _dispatcher;

  /// When true, [startFromLobby] schedules the online turn runner.
  bool autoStubTurns;

  late final MatchTurnRunner stubLoop;

  Future<MatchSnapshot> createPractice({
    required String callerUserId,
    required String connectionId,
    List<String>? callerArcoriIds,
    String? callerSlammerId,
    String arenaId = stubArenaId,
  }) async {
    final humanArcori = (callerArcoriIds != null && callerArcoriIds.isNotEmpty)
        ? callerArcoriIds
        : <String>[stubArcoriId];
    final humanSlammer =
        (callerSlammerId != null && callerSlammerId.trim().isNotEmpty)
            ? callerSlammerId.trim()
            : stubSlammerId;

    final ids = <String>{
      ...humanArcori,
      stubAiArcoriId,
      humanSlammer,
      stubSlammerId,
    }.toList();

    late final Map<String, Map<String, dynamic>> catalogById;
    try {
      catalogById = await _catalog.fetchDesigns(ids);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError(
        matchCatalogFreezeFailed,
        message: 'Catalog freeze failed: $e',
      );
    }

    for (final id in ids) {
      if (!catalogById.containsKey(id)) {
        throw AppError(
          matchCatalogFreezeFailed,
          message: 'Missing catalog design in freeze: $id',
        );
      }
    }

    final snapshot = _store.createPracticeStub(
      callerUserId: callerUserId,
      catalogById: catalogById,
      arenaId: arenaId,
      callerArcoriIds: humanArcori,
      callerSlammerId: humanSlammer,
    );
    roomRegistry.subscribe(
      snapshot.matchId,
      connectionId,
      userId: callerUserId,
    );
    _broadcast(snapshot);
    return snapshot;
  }

  @override
  Future<MatchSnapshot> startFromLobby({
    required Map<String, dynamic> matchType,
    required List<LobbyHumanSeat> humans,
    required List<String> aiUserIds,
    int targetSeats = 3,
    String arenaId = stubArenaId,
    int? firstSeatIndex,
  }) async {
    if (humans.isEmpty) {
      throw AppError(matchInvalidRequest, message: 'humans required');
    }
    if (humans.length > targetSeats) {
      throw AppError(matchInvalidRequest, message: 'too many humans');
    }
    final needAi = targetSeats - humans.length;
    if (aiUserIds.length < needAi) {
      throw AppError(
        matchInvalidRequest,
        message: 'Need $needAi AI ids, got ${aiUserIds.length}',
      );
    }

    final requestedSeats = <MatchSeat>[];
    final rematch = matchType['rematch'] == true ||
        matchType['rematch']?.toString() == 'true';
    final rematchSeatHints = <String, Map<String, dynamic>>{};
    final rawRematchSeats = matchType['rematchSeats'];
    if (rawRematchSeats is List) {
      for (final entry in rawRematchSeats) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final uid = map['userId']?.toString().trim() ?? '';
        if (uid.isEmpty) continue;
        rematchSeatHints[uid] = map;
      }
    }

    for (var i = 0; i < humans.length; i++) {
      final h = humans[i];
      final hint = rematchSeatHints[h.userId];
      final hintSlammer = hint?['slammerId']?.toString().trim() ?? '';
      final slammer = h.slammerId.trim().isNotEmpty
          ? h.slammerId.trim()
          : (hintSlammer.isNotEmpty ? hintSlammer : stubSlammerId);
      final hintArcori = hint?['arcoriIds'];
      final priorArcori = hintArcori is List
          ? hintArcori
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : const <String>[];
      requestedSeats.add(
        MatchSeat(
          userId: h.userId,
          seatIndex: i,
          kind: 'human',
          arcoriIds: rematch && priorArcori.isNotEmpty
              ? priorArcori
              : (h.arcoriIds.isNotEmpty ? h.arcoriIds : const []),
          slammerId: slammer,
        ),
      );
    }
    for (var i = 0; i < needAi; i++) {
      final aiUserId = aiUserIds[i];
      final hint = rematchSeatHints[aiUserId];
      final hintSlammer = hint?['slammerId']?.toString().trim() ?? '';
      final hintArcori = hint?['arcoriIds'];
      final priorArcori = hintArcori is List
          ? hintArcori
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : const <String>[];
      requestedSeats.add(
        MatchSeat(
          userId: aiUserId,
          seatIndex: humans.length + i,
          kind: 'ai',
          arcoriIds: rematch && priorArcori.isNotEmpty
              ? priorArcori
              : const [],
          slammerId: hintSlammer.isNotEmpty ? hintSlammer : stubSlammerId,
        ),
      );
    }

    Map<String, String> verifiedSlammers = {};
    try {
      verifiedSlammers = await _avari.verifySlammers(
        seats: [
          for (final s in requestedSeats)
            {'userId': s.userId, 'slammerId': s.slammerId},
        ],
      );
      if (LOGGING_SWITCH) {
        customlog(
          'match: startFromLobby verify_slammers ok '
          'picks=${verifiedSlammers.entries.map((e) => '${e.key}:${e.value}').join(',')}',
        );
      }
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog(
          'match: startFromLobby verify_slammers failed → stub slammer err=$e',
        );
      }
      verifiedSlammers = {};
    }

    Map<String, String> selected = {};
    final needsCatalogSelect =
        requestedSeats.any((s) => s.arcoriIds.isEmpty);
    if (needsCatalogSelect) {
      try {
        selected = await _catalog.selectArcori(
          seats: [
            for (final s in requestedSeats)
              if (s.arcoriIds.isEmpty) {'userId': s.userId},
          ],
        );
        if (LOGGING_SWITCH) {
          customlog(
            'match: startFromLobby select_arcori ok '
            'picks=${selected.entries.map((e) => '${e.key}:${e.value}').join(',')}',
          );
        }
      } catch (e) {
        if (LOGGING_SWITCH) {
          customlog(
            'match: startFromLobby select_arcori failed → stub Tiger/WhiteTiger err=$e',
          );
        }
        selected = {};
      }
    } else if (LOGGING_SWITCH) {
      customlog(
        'match: startFromLobby skip select_arcori rematch=$rematch '
        '(prior arcori loadouts present)',
      );
    }

    final seats = <MatchSeat>[];
    for (final s in requestedSeats) {
      final verified = verifiedSlammers[s.userId]?.trim() ?? '';
      final slammer = verified.isNotEmpty ? verified : s.slammerId;
      seats.add(
        MatchSeat(
          userId: s.userId,
          seatIndex: s.seatIndex,
          kind: s.kind,
          arcoriIds: s.arcoriIds,
          slammerId: slammer,
          score: s.score,
          connected: s.connected,
        ),
      );
    }

    final assigned = <MatchSeat>[];
    for (var i = 0; i < seats.length; i++) {
      final s = seats[i];
      if (s.arcoriIds.isNotEmpty) {
        assigned.add(s);
        continue;
      }
      final picked = selected[s.userId]?.trim() ?? '';
      final arcoriId = picked.isNotEmpty
          ? picked
          : (s.kind == 'ai' ? stubAiArcoriId : stubArcoriId);
      assigned.add(
        MatchSeat(
          userId: s.userId,
          seatIndex: s.seatIndex,
          kind: s.kind,
          arcoriIds: [arcoriId],
          slammerId: s.slammerId,
          score: s.score,
          connected: s.connected,
        ),
      );
    }

    var resolvedArenaId = arenaId;
    String? arenaImageUrl;
    if (matchTypeUsesArcoriRegionArena(matchType)) {
      try {
        final pick = await _catalog.selectArena(
          arcoriIds: [
            for (final s in assigned) ...s.arcoriIds,
          ],
        );
        if (pick != null && pick.arenaId.isNotEmpty) {
          resolvedArenaId = pick.arenaId;
          arenaImageUrl = pick.imageUrl;
          if (LOGGING_SWITCH) {
            customlog(
              'match: startFromLobby select_arena ok '
              'arenaId=${pick.arenaId} region=${pick.regionCode} '
              'source=${pick.source}',
            );
          }
        }
      } catch (e) {
        if (LOGGING_SWITCH) {
          customlog(
            'match: startFromLobby select_arena failed → stub arena err=$e',
          );
        }
      }
    } else if (LOGGING_SWITCH) {
      customlog(
        'match: startFromLobby skip select_arena type=${matchType['code']}',
      );
    }

    final ids = <String>{
      for (final s in assigned) ...s.arcoriIds,
      for (final s in assigned) s.slammerId,
    }.toList();

    late final Map<String, Map<String, dynamic>> catalogById;
    try {
      catalogById = await _catalog.fetchDesigns(ids);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError(
        matchCatalogFreezeFailed,
        message: 'Catalog freeze failed: $e',
      );
    }
    for (final id in ids) {
      if (!catalogById.containsKey(id)) {
        throw AppError(
          matchCatalogFreezeFailed,
          message: 'Missing catalog design in freeze: $id',
        );
      }
    }

    final callerUserId = humans.first.userId;
    var snapshot = _store.createFromLobby(
      callerUserId: callerUserId,
      matchType: matchType,
      seats: assigned,
      catalogById: catalogById,
      arenaId: resolvedArenaId,
      arenaImageUrl: arenaImageUrl,
      firstSeatIndex: firstSeatIndex,
      random: stubLoop.random,
    );

    final grace = stubLoop.matchStartGrace;
    if (grace > Duration.zero) {
      final graceEndsAt =
          DateTime.now().toUtc().add(grace).toIso8601String();
      snapshot = _store.bump(snapshot.matchId, (current) {
        final active = Map<String, dynamic>.from(current.active ?? {});
        active['graceEndsAt'] = graceEndsAt;
        return current.copyWith(active: active);
      });
      if (LOGGING_SWITCH) {
        customlog(
          'match: startFromLobby graceEndsAt=$graceEndsAt '
          'matchId=${snapshot.matchId}',
        );
      }
    }

    for (final h in humans) {
      roomRegistry.subscribe(
        snapshot.matchId,
        h.connectionId,
        userId: h.userId,
      );
    }
    _broadcast(snapshot);
    if (LOGGING_SWITCH) {
      customlog(
        'match: startFromLobby matchId=${snapshot.matchId} '
        'type=${snapshot.matchType} humans=${humans.length} '
        'ai=${needAi} seats=${snapshot.seats.length} '
        'firstSeat=${snapshot.firstSeatIndex}',
      );
    }
    if (autoStubTurns) {
      stubLoop.schedule(snapshot.matchId);
    }
    return snapshot;
  }

  MatchSnapshot join({
    required String matchId,
    required String userId,
    required String connectionId,
  }) {
    final current = _store.getSnapshot(matchId);
    if (current == null) {
      throw AppError(matchNotFound);
    }
    if (current.phase == 'ended') {
      throw AppError(matchInvalidRequest, message: 'Match already ended');
    }
    final seat = current.seats.where((s) => s.userId == userId).toList();
    if (seat.isEmpty) {
      throw AppError(matchForbidden, message: 'Not a seat in this match');
    }
    roomRegistry.subscribe(matchId, connectionId, userId: userId);
    final snapshot = _store.markConnected(
      matchId: matchId,
      userId: userId,
      connected: true,
    );
    _broadcast(snapshot);
    return snapshot;
  }

  MatchSnapshot leave({
    required String matchId,
    required String userId,
    required String connectionId,
  }) {
    final current = _store.getSnapshot(matchId);
    if (current == null) {
      throw AppError(matchNotFound);
    }
    roomRegistry.unsubscribe(matchId, connectionId);
    var snapshot = current;
    if (current.phase != 'ended') {
      snapshot = _store.markConnected(
        matchId: matchId,
        userId: userId,
        connected: false,
      );
      _broadcast(snapshot);
    }
    if (roomRegistry.connectionIds(matchId).isEmpty &&
        snapshot.phase != 'ended') {
      snapshot = _store.endMatch(matchId);
    }
    return snapshot;
  }

  MatchSnapshot end({
    required String matchId,
    required String userId,
  }) {
    final current = _store.getSnapshot(matchId);
    if (current == null) {
      throw AppError(matchNotFound);
    }
    if (current.callerUserId != userId) {
      throw AppError(matchForbidden, message: 'Only caller can end match');
    }
    if (current.phase == 'ended') {
      return current;
    }
    return endInternal(matchId);
  }

  /// End without caller check — used by the stub turn runner.
  MatchSnapshot endInternal(String matchId) {
    final current = _store.getSnapshot(matchId);
    if (current == null) {
      throw AppError(matchNotFound);
    }
    if (current.phase == 'ended') {
      return current;
    }
    final snapshot = _store.endMatch(matchId);
    _broadcast(snapshot);
    return snapshot;
  }

  /// Remove `graceEndsAt` from active and broadcast (turn runner after grace).
  MatchSnapshot clearTurnGrace(String matchId) {
    final current = _store.getSnapshot(matchId);
    if (current == null) {
      throw AppError(matchNotFound);
    }
    final active = current.active;
    if (active == null || !active.containsKey('graceEndsAt')) {
      return current;
    }
    final nextActive = Map<String, dynamic>.from(active)..remove('graceEndsAt');
    final snapshot = _store.bump(
      matchId,
      (s) => s.copyWith(active: nextActive),
    );
    _broadcast(snapshot);
    return snapshot;
  }

  /// Remove `inputLockedUntil` after post-slam anim hold (unlock next seat input).
  MatchSnapshot clearTurnAnimLock(String matchId) {
    final current = _store.getSnapshot(matchId);
    if (current == null) {
      throw AppError(matchNotFound);
    }
    final active = current.active;
    if (active == null || !active.containsKey('inputLockedUntil')) {
      return current;
    }
    final nextActive = activeWithoutAnimLock(active);
    final snapshot = _store.bump(
      matchId,
      (s) => s.copyWith(active: nextActive),
    );
    if (LOGGING_SWITCH) {
      customlog(
        'match: clearTurnAnimLock matchId=$matchId '
        'seat=${nextActive['seatIndex']}',
      );
    }
    _broadcast(snapshot);
    return snapshot;
  }

  MatchSnapshot action({
    required String matchId,
    required String userId,
    required Map<String, dynamic> payload,
  }) {
    final snapshot = _dispatcher.dispatch(
      matchId: matchId,
      actorUserId: userId,
      payload: payload,
    );
    _broadcast(snapshot);
    return snapshot;
  }

  void _broadcast(MatchSnapshot snapshot) {
    roomBroadcaster.broadcastToRoom(
      snapshot.matchId,
      channel: 'match/state',
      type: 'event',
      payload: snapshot.toPayload(),
    );
  }
}

final matchService = MatchService();
