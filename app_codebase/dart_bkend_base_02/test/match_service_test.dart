import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../bin/core/errors/app_error.dart';
import '../bin/core/http/fastapi_service_client.dart';
import '../bin/core/state/state_registry.dart';
import '../bin/modules/match/match_catalog_client.dart';
import '../bin/modules/match/match_errors.dart';
import '../bin/modules/match/match_lifecycle_contract.dart';
import '../bin/modules/match/match_models.dart';
import '../bin/modules/match/match_service.dart';
import '../bin/modules/match/match_store.dart';

void main() {
  group('MatchService', () {
    setUp(() {
      resetStateRegistry();
    });

    test('createPractice freezes catalog via service client', () async {
      final store = MatchStore();
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          expect(request.url.path, '/service/catalog/designs');
          final body = jsonDecode(request.body) as Map;
          expect(body['ids'], contains(stubSlammerId));
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': {
                'designs': {
                  stubArcoriId: {'internalId': stubArcoriId},
                  stubAiArcoriId: {'internalId': stubAiArcoriId},
                  stubSlammerId: {
                    'internalId': stubSlammerId,
                    'gameplayAttributes': {'impact': 5},
                  },
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://catalog.test',
      );

      final service = MatchService(
        store: store,
        catalog: MatchCatalogClient(fastApi: fastApi),
        autoStubTurns: false,
      );
      final snapshot = await service.createPractice(
        callerUserId: 'usr_a',
        connectionId: 'conn-1',
        callerArcoriIds: [stubArcoriId],
        callerSlammerId: stubSlammerId,
      );

      expect(snapshot.phase, 'playing');
      expect(snapshot.seats[0].arcoriIds, [stubArcoriId]);
      expect(store.getRuntime(snapshot.matchId)!.catalogById.length, 3);
      expect(roomRegistry.connectionIds(snapshot.matchId), contains('conn-1'));

      final ended = service.end(matchId: snapshot.matchId, userId: 'usr_a');
      expect(ended.phase, 'ended');
    });

    test('createPractice maps catalog failure', () async {
      final store = MatchStore();
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'ok': false,
              'error': {
                'code': 'catalog/not_found',
                'message': 'Design not found: MISSING',
              },
            }),
            404,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://catalog.test',
      );

      final service = MatchService(
        store: store,
        catalog: MatchCatalogClient(fastApi: fastApi),
        autoStubTurns: false,
      );
      expect(
        () => service.createPractice(
          callerUserId: 'usr_a',
          connectionId: 'conn-1',
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            matchCatalogFreezeFailed.code,
          ),
        ),
      );
    });

    test('startFromLobby selects Arcori then freezes catalog', () async {
      final store = MatchStore();
      final paths = <String>[];
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/service/catalog/select_arcori') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'selections': [
                    {
                      'userId': 'usr_a',
                      'arcoriId': stubArcoriId,
                      'source': 'weighted',
                    },
                    {
                      'userId': 'ai-1',
                      'arcoriId': stubAiArcoriId,
                      'source': 'weighted',
                    },
                  ],
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
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
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
        baseUrl: 'http://catalog.test',
      );

      final service = MatchService(
        store: store,
        catalog: MatchCatalogClient(fastApi: fastApi),
        autoStubTurns: false,
      );
      final snapshot = await service.startFromLobby(
        matchType: {'code': 'quickStart'},
        humans: [
          LobbyHumanSeat(
            userId: 'usr_a',
            connectionId: 'conn-1',
          ),
        ],
        aiUserIds: ['ai-1'],
        targetSeats: 2,
      );

      expect(paths.first, '/service/catalog/select_arcori');
      expect(paths, contains('/service/catalog/designs'));
      expect(snapshot.seats[0].arcoriIds, [stubArcoriId]);
      expect(snapshot.seats[1].arcoriIds, [stubAiArcoriId]);
      expect(snapshot.seats[1].kind, 'ai');
    });

    test('startFromLobby falls back to stubs when select fails', () async {
      final store = MatchStore();
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          if (request.url.path == '/service/catalog/select_arcori') {
            return http.Response('boom', 500);
          }
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
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
        baseUrl: 'http://catalog.test',
      );

      final service = MatchService(
        store: store,
        catalog: MatchCatalogClient(fastApi: fastApi),
        autoStubTurns: false,
      );
      final snapshot = await service.startFromLobby(
        matchType: {'code': 'quickStart'},
        humans: [
          LobbyHumanSeat(
            userId: 'usr_a',
            connectionId: 'conn-1',
          ),
        ],
        aiUserIds: ['ai-1'],
        targetSeats: 2,
      );

      expect(snapshot.seats[0].arcoriIds, [stubArcoriId]);
      expect(snapshot.seats[1].arcoriIds, [stubAiArcoriId]);
    });

    test('stub loop: 2×N slams then phase ended with round 2', () async {
      final store = MatchStore();
      final slamEvents = <Map<String, dynamic>>[];
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          if (request.url.path == '/service/catalog/select_arcori') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'selections': [
                    {
                      'userId': 'usr_a',
                      'arcoriId': stubArcoriId,
                      'source': 'weighted',
                    },
                    {
                      'userId': 'ai-1',
                      'arcoriId': stubAiArcoriId,
                      'source': 'weighted',
                    },
                  ],
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
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
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
        baseUrl: 'http://catalog.test',
      );

      final service = MatchService(
        store: store,
        catalog: MatchCatalogClient(fastApi: fastApi),
        autoStubTurns: false,
        stubStepDelay: Duration.zero,
      );

      final snapshot = await service.startFromLobby(
        matchType: {'code': 'quickStart'},
        humans: [
          LobbyHumanSeat(
            userId: 'usr_a',
            connectionId: 'conn-1',
            slammerId: stubSlammerId,
          ),
        ],
        aiUserIds: ['ai-1'],
        targetSeats: 2,
      );

      // Spy: wrap action to record slam lastEvents.
      final seatCount = snapshot.seats.length;
      final roundsTotal = snapshot.roundsTotal;
      for (var round = 1; round <= roundsTotal; round++) {
        for (var i = 0; i < seatCount; i++) {
          final actor = store.getSnapshot(snapshot.matchId)!.seats[i];
          final next = service.action(
            matchId: snapshot.matchId,
            userId: actor.userId,
            payload: const {'action': 'slam'},
          );
          final ev = next.lastEvent!;
          expect(ev['type'], 'slam');
          slamEvents.add(Map<String, dynamic>.from(ev));
        }
      }
      final ended = service.endInternal(snapshot.matchId);

      expect(slamEvents, hasLength(seatCount * roundsTotal));
      expect(slamEvents.first['slammerId'], stubSlammerId);
      expect(slamEvents.first['seatIndex'], 0);
      expect(slamEvents.first['round'], 1);
      expect(slamEvents.first['arcoriId'], stubArcoriId);
      expect(slamEvents[2]['round'], 2);
      expect(ended.phase, 'ended');
      expect(ended.round, 2);
      expect(ended.lastEvent?['type'], 'match_ended');

      // Also cover schedule path with delay zero.
      final store2 = MatchStore();
      final service2 = MatchService(
        store: store2,
        catalog: MatchCatalogClient(fastApi: fastApi),
        autoStubTurns: true,
        stubStepDelay: Duration.zero,
      );
      final snap2 = await service2.startFromLobby(
        matchType: {'code': 'quickStart'},
        humans: [
          LobbyHumanSeat(
            userId: 'usr_a',
            connectionId: 'conn-2',
            slammerId: stubSlammerId,
          ),
        ],
        aiUserIds: ['ai-1'],
        targetSeats: 2,
      );
      await service2.stubLoop.waitFor(snap2.matchId);
      final ended2 = store2.getSnapshot(snap2.matchId)!;
      expect(ended2.phase, 'ended');
      expect(ended2.round, 2);
      // v1 create + 4 slams + end
      expect(ended2.version, 6);
    });
  });
}
