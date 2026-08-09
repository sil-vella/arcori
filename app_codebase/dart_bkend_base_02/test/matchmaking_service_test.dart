import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../bin/core/http/fastapi_service_client.dart';
import '../bin/core/state/state_registry.dart';
import '../bin/modules/match/match_catalog_client.dart';
import '../bin/modules/match/match_models.dart';
import '../bin/modules/match/match_service.dart';
import '../bin/modules/match/match_store.dart';
import '../bin/modules/matchmaking/matchmaking_ai_client.dart';
import '../bin/modules/matchmaking/matchmaking_service.dart';
import '../bin/modules/matchmaking/matchmaking_store.dart';

void main() {
  group('MatchmakingService', () {
    late MatchStore matchStoreLocal;
    late MatchmakingStore lobbyStore;
    late MatchService matchSvc;
    late MatchmakingService mm;

    setUp(() {
      resetStateRegistry();
      matchStoreLocal = MatchStore();
      lobbyStore = MatchmakingStore();
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          if (request.url.path == '/service/catalog/designs') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'designs': {
                    stubArcoriId: {'internalId': stubArcoriId},
                    stubAiArcoriId: {'internalId': stubAiArcoriId},
                    stubSlammerId: {'internalId': stubSlammerId},
                  },
                },
              }),
              200,
            );
          }
          if (request.url.path == '/service/players/ai/sample') {
            final body = jsonDecode(request.body) as Map;
            final count = body['count'] as int;
            final players = List.generate(
              count,
              (i) => {
                'userId': 'ai-user-$i',
                'username': 'ai_$i',
                'displayName': 'AI $i',
              },
            );
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {'players': players},
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );
      matchSvc = MatchService(
        store: matchStoreLocal,
        catalog: MatchCatalogClient(fastApi: fastApi),
      );
      mm = MatchmakingService(
        store: lobbyStore,
        matchLifecycle: matchSvc,
        aiClient: MatchmakingAiClient(fastApi: fastApi),
        scheduleTimers: false,
      );
    });

    test('same queueKey joins same lobby; third promote fills AI', () async {
      final a = await mm.find(
        userId: 'u1',
        connectionId: 'c1',
        payload: {
          'matchType': {'code': 'quickStart'},
        },
      );
      expect(a.phase, 'waiting');
      expect(a.members, hasLength(1));

      final b = await mm.find(
        userId: 'u2',
        connectionId: 'c2',
        payload: {
          'matchType': {'code': 'quickStart'},
        },
      );
      expect(b.lobbyId, a.lobbyId);
      expect(b.members, hasLength(2));

      final c = await mm.find(
        userId: 'u3',
        connectionId: 'c3',
        payload: {
          'matchType': {'code': 'quickStart'},
        },
      );
      expect(c.phase, 'promoted');
      expect(c.matchId, isNotNull);
      expect(c.members, hasLength(3));

      final snap = matchStoreLocal.getSnapshot(c.matchId!);
      expect(snap, isNotNull);
      expect(snap!.seats, hasLength(3));
      expect(snap.seats.every((s) => s.kind == 'human'), isTrue);
      expect(roomRegistry.connectionIds(c.matchId!), containsAll(['c1', 'c2', 'c3']));
    });

    test('different queueKeys stay isolated; timeout promotes with AI', () async {
      final quick = await mm.find(
        userId: 'u1',
        connectionId: 'c1',
        payload: {
          'matchType': {'code': 'quickStart'},
        },
      );
      final event = await mm.find(
        userId: 'u2',
        connectionId: 'c2',
        payload: {
          'matchType': {
            'code': 'specialEvent',
            'subtype': 'royal-battle',
            'eventId': 'evt_stub',
          },
        },
      );
      expect(quick.lobbyId, isNot(event.lobbyId));
      expect(quick.queueKey, isNot(event.queueKey));

      final promoted = await mm.promoteLobby(quick.lobbyId);
      expect(promoted.phase, 'promoted');
      final snap = matchStoreLocal.getSnapshot(promoted.matchId!);
      expect(snap!.seats, hasLength(3));
      expect(snap.seats.where((s) => s.kind == 'ai'), hasLength(2));
      expect(snap.matchType['code'], 'quickStart');
    });
  });
}
