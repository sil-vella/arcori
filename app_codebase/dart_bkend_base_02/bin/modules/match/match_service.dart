/// Match orchestration — create with catalog freeze, join/leave/end + actions.
library;

import '../../core/errors/app_error.dart';
import '../../core/http/fastapi_service_client.dart';
import '../../core/state/state_registry.dart';
import 'action_dispatcher.dart';
import 'match_catalog_client.dart';
import 'match_errors.dart';
import 'match_models.dart';
import 'match_store.dart';

class MatchService {
  MatchService({
    MatchStore? store,
    FastApiServiceClient? fastApi,
    MatchCatalogClient? catalog,
    ActionDispatcher? dispatcher,
  })  : _store = store ?? matchStore,
        _catalog = catalog ?? MatchCatalogClient(fastApi: fastApi),
        _dispatcher = dispatcher ??
            ActionDispatcher(store: store ?? matchStore);

  final MatchStore _store;
  final MatchCatalogClient _catalog;
  final ActionDispatcher _dispatcher;

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
