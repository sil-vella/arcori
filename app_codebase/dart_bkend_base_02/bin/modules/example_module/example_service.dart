/// Example module orchestration — hot in-memory state + optional durable record.
library;

import 'dart:async';

import '../../core/http/fastapi_service_client.dart';
import 'example_store.dart';

class ExampleModuleService {
  ExampleModuleService({
    ExampleModuleStore? store,
    FastApiServiceClient? fastApi,
  })  : _store = store ?? exampleModuleStore,
        _fastApi = fastApi ?? FastApiServiceClient();

  final ExampleModuleStore _store;
  final FastApiServiceClient _fastApi;

  ExampleSnapshot applyEvent({
    required String userId,
    required Map<String, dynamic> patch,
    bool record = false,
  }) {
    final snapshot = _store.applyPatch(patch);
    if (record) {
      unawaited(
        _fastApi.recordExampleModule(
          userId: userId,
          payload: snapshot.toPayload(),
        ),
      );
    }
    return snapshot;
  }
}

final exampleModuleService = ExampleModuleService();
