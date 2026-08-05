import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../bin/core/errors/app_error.dart';
import '../bin/core/http/fastapi_service_client.dart';
import '../bin/core/state/state_registry.dart';
import '../bin/modules/match/match_catalog_client.dart';
import '../bin/modules/match/match_errors.dart';
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
      );
      final snapshot = await service.createPractice(
        callerUserId: 'usr_a',
        connectionId: 'conn-1',
      );

      expect(snapshot.phase, 'playing');
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
  });
}
