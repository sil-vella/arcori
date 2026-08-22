/// Match orchestration — create with catalog freeze, join/leave/end + actions.
library;

import '../../core/errors/app_error.dart';
import '../../core/http/fastapi_service_client.dart';
import '../../core/state/state_registry.dart';
import '../../utils/dev_logger.dart';
import 'action_dispatcher.dart';
import 'match_catalog_client.dart';
import 'match_errors.dart';
import 'match_lifecycle_contract.dart';
import 'match_models.dart';
import 'match_store.dart';
import 'match_stub_loop.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class MatchService implements MatchLifecycleContract {
  MatchService({
    MatchStore? store,
    FastApiServiceClient? fastApi,
    MatchCatalogClient? catalog,
    ActionDispatcher? dispatcher,
    bool autoStubTurns = true,
    Duration? stubStepDelay,
  })  : _store = store ?? matchStore,
        _catalog = catalog ?? MatchCatalogClient(fastApi: fastApi),
        _dispatcher =
            dispatcher ?? ActionDispatcher(store: store ?? matchStore),
        autoStubTurns = autoStubTurns {
    stubLoop = MatchStubLoop(
      store: _store,
      service: this,
      stepDelay: stubStepDelay ?? stubMatchStepDelayDefault,
    );
  }

  final MatchStore _store;
  final MatchCatalogClient _catalog;
  final ActionDispatcher _dispatcher;

  /// When true, [startFromLobby] schedules the online stub slam loop.
  bool autoStubTurns;

  late final MatchStubLoop stubLoop;

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

    final seats = <MatchSeat>[];
    for (var i = 0; i < humans.length; i++) {
      final h = humans[i];
      final slammer =
          h.slammerId.trim().isNotEmpty ? h.slammerId.trim() : stubSlammerId;
      seats.add(
        MatchSeat(
          userId: h.userId,
          seatIndex: i,
          kind: 'human',
          arcoriIds: const [],
          slammerId: slammer,
        ),
      );
    }
    for (var i = 0; i < needAi; i++) {
      seats.add(
        MatchSeat(
          userId: aiUserIds[i],
          seatIndex: humans.length + i,
          kind: 'ai',
          arcoriIds: const [],
          slammerId: stubSlammerId,
        ),
      );
    }

    Map<String, String> selected = {};
    try {
      selected = await _catalog.selectArcori(
        seats: [
          for (final s in seats) {'userId': s.userId},
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

    final assigned = <MatchSeat>[];
    for (var i = 0; i < seats.length; i++) {
      final s = seats[i];
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
    final snapshot = _store.createFromLobby(
      callerUserId: callerUserId,
      matchType: matchType,
      seats: assigned,
      catalogById: catalogById,
      arenaId: arenaId,
    );

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
        'ai=${needAi} seats=${snapshot.seats.length}',
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
