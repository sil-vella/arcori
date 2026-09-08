import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../bin/core/errors/app_error.dart';
import '../bin/core/http/fastapi_service_client.dart';
import '../bin/core/state/state_registry.dart';
import '../bin/modules/match/match_errors.dart';
import '../bin/modules/match/match_lifecycle_contract.dart';
import '../bin/modules/match/match_models.dart';
import '../bin/modules/match/match_service.dart';
import '../bin/modules/match/match_store.dart';

http.Response _verifySlammersOk(http.Request request) {
  final body = jsonDecode(request.body) as Map;
  final seats = body['seats'] as List? ?? [];
  final assignments = <Map<String, dynamic>>[];
  for (final raw in seats) {
    final seat = raw as Map;
    final requested = seat['slammerId']?.toString().trim() ?? '';
    assignments.add({
      'userId': seat['userId']?.toString() ?? '',
      'slammerId': requested.isNotEmpty ? requested : stubSlammerId,
      'source': 'owned',
    });
  }
  return http.Response(
    jsonEncode({
      'ok': true,
      'data': {'assignments': assignments},
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _selectArenaOk() {
  return http.Response(
    jsonEncode({
      'ok': true,
      'data': {
        'arenaId': 'ARN-AMB-WLD001-0001',
        'regionCode': 'AMB',
        'name': 'Amberwild',
        'imageUrl':
            '/catalog-media/velora/arenas/amberwild/ARN-AMB-WLD001-0001.webp',
        'source': 'majority',
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('MatchService', () {
    setUp(() {
      resetStateRegistry();
    });

    test('createPractice freezes catalog via service client', () async {
      final store = MatchStore();
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          if (request.url.path == '/service/avari/verify_slammers') {
            return _verifySlammersOk(request);
          }
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
        fastApi: fastApi,
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
        fastApi: fastApi,
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
          if (request.url.path == '/service/avari/verify_slammers') {
            return _verifySlammersOk(request);
          }
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
          if (request.url.path == '/service/catalog/select_arena') {
            return _selectArenaOk();
          }
          if (request.url.path == '/service/catalog/designs') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'designs': {
                    stubArcoriId: {
                      'internalId': stubArcoriId,
                      'imageUrl':
                          '/catalog-media/genesis/animals/ANM-TIG-GEN001-0001.webp',
                      'color': '#C6A15B',
                    },
                    stubAiArcoriId: {
                      'internalId': stubAiArcoriId,
                      'imageUrl':
                          '/catalog-media/genesis/animals/ANM-WTI-GEN001-0002.webp',
                      'color': '#A8B0B8',
                    },
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
        fastApi: fastApi,
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

      expect(paths.first, '/service/avari/verify_slammers');
      expect(paths, contains('/service/catalog/select_arcori'));
      expect(paths, contains('/service/catalog/select_arena'));
      expect(paths, contains('/service/catalog/designs'));
      expect(snapshot.arenaId, 'ARN-AMB-WLD001-0001');
      expect(
        snapshot.arenaImageUrl,
        '/catalog-media/velora/arenas/amberwild/ARN-AMB-WLD001-0001.webp',
      );
      expect(snapshot.seats[0].arcoriIds, [stubArcoriId]);
      expect(snapshot.seats[1].arcoriIds, [stubAiArcoriId]);
      expect(snapshot.seats[1].kind, 'ai');
      final pieces = snapshot.table['pieces'] as List;
      expect(pieces.first['imageUrl'], contains('ANM-TIG-GEN001-0001.webp'));
      expect(pieces.first['color'], '#C6A15B');
    });

    test('startFromLobby skips select_arena for specialEvent', () async {
      final store = MatchStore();
      final paths = <String>[];
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/service/avari/verify_slammers') {
            return _verifySlammersOk(request);
          }
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
        fastApi: fastApi,
        autoStubTurns: false,
      );
      final snapshot = await service.startFromLobby(
        matchType: {'code': 'specialEvent', 'subtype': 'royal-battle'},
        humans: [
          LobbyHumanSeat(
            userId: 'usr_a',
            connectionId: 'conn-1',
          ),
        ],
        aiUserIds: ['ai-1'],
        targetSeats: 2,
      );

      expect(paths, isNot(contains('/service/catalog/select_arena')));
      expect(snapshot.arenaId, stubArenaId);
      expect(snapshot.arenaImageUrl, isNull);
    });

    test('startFromLobby uses verified slammer not the requested unowned id',
        () async {
      const owned = stubSlammerId;
      const unowned = 'SLM-TTN-GEN001-0002';
      final store = MatchStore();
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          if (request.url.path == '/service/avari/verify_slammers') {
            final body = jsonDecode(request.body) as Map;
            final seats = body['seats'] as List? ?? [];
            final assignments = <Map<String, dynamic>>[];
            for (final raw in seats) {
              final seat = raw as Map;
              assignments.add({
                'userId': seat['userId']?.toString() ?? '',
                'slammerId': owned,
                'source': 'fallback',
              });
            }
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {'assignments': assignments},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
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
          if (request.url.path == '/service/catalog/select_arena') {
            return _selectArenaOk();
          }
          if (request.url.path == '/service/catalog/designs') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'designs': {
                    stubArcoriId: {'internalId': stubArcoriId},
                    stubAiArcoriId: {'internalId': stubAiArcoriId},
                    owned: {'internalId': owned},
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
        fastApi: fastApi,
        autoStubTurns: false,
      );
      final snapshot = await service.startFromLobby(
        matchType: {'code': 'quickStart'},
        humans: [
          LobbyHumanSeat(
            userId: 'usr_a',
            connectionId: 'conn-1',
            slammerId: unowned,
          ),
        ],
        aiUserIds: ['ai-1'],
        targetSeats: 2,
      );

      expect(snapshot.seats[0].slammerId, owned);
      expect(snapshot.seats[0].slammerId, isNot(unowned));
    });

    test('startFromLobby falls back to stubs when select fails', () async {
      final store = MatchStore();
      final fastApi = FastApiServiceClient(
        client: MockClient((request) async {
          if (request.url.path == '/service/avari/verify_slammers') {
            return _verifySlammersOk(request);
          }
          if (request.url.path == '/service/catalog/select_arcori') {
            return http.Response('boom', 500);
          }
          if (request.url.path == '/service/catalog/select_arena') {
            return _selectArenaOk();
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
        fastApi: fastApi,
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
          if (request.url.path == '/service/avari/verify_slammers') {
            return _verifySlammersOk(request);
          }
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
          if (request.url.path == '/service/catalog/select_arena') {
            return _selectArenaOk();
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
        fastApi: fastApi,
        autoStubTurns: false,
        matchStartGrace: Duration.zero,
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
        firstSeatIndex: 0,
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
          service.clearTurnAnimLock(snapshot.matchId);
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
        fastApi: fastApi,
        autoStubTurns: true,
        matchStartGrace: Duration.zero,
        turnTimeout: Duration.zero,
        turnRandom: Random(1),
      );
      service2.stubLoop
        ..aiDelayMin = Duration.zero
        ..aiDelayMax = Duration.zero
        ..aiMissProbability = 0
        ..postSlamAnimHold = Duration.zero;
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
        firstSeatIndex: 0,
      );
      await service2.stubLoop.waitFor(snap2.matchId);
      final ended2 = store2.getSnapshot(snap2.matchId)!;
      expect(ended2.phase, 'ended');
      expect(ended2.round, 2);
      // v1 create + 4 slams + 4 anim-lock clears + end
      expect(ended2.version, 10);
    });
  });
}
