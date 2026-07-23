import 'dart:convert';

import 'package:test/test.dart';

import '../bin/core/errors/app_error.dart';
import '../bin/core/state/connection_registry.dart';
import '../bin/core/state/room/room_registry.dart';
import '../bin/core/ws/contracts/ws_message_contract.dart';
import '../bin/core/state/room/room_demo_handler.dart';
import '../bin/modules/ops/ops_errors.dart';
import '../bin/modules/ops/ops_service.dart';
import '../bin/modules/ops/ops_state.dart';
import '../bin/core/state/state_registry.dart';

void main() {
  setUp(() {
    resetOpsState();
    resetStateRegistry();
  });

  tearDown(() {
    resetOpsState();
    resetStateRegistry();
  });

  test('setDrainMode flips flag and status reports it', () {
    expect(drainMode, isFalse);
    setDrainMode(true);
    final status = drainStatus();
    expect(status['drain_mode'], isTrue);
    expect(status['active_rooms'], 0);
    expect(status['dart_connections'], 0);
  });

  test('roomCount and connectionCount feed drainStatus', () {
    connectionRegistry.register('c1', (_) {});
    roomRegistry.subscribe('demo', 'c1', userId: 'u1');
    setDrainMode(true);
    final status = drainStatus();
    expect(status['active_rooms'], 1);
    expect(status['room_count'], 1);
    expect(status['dart_connections'], 1);
  });

  test('subscribe blocked when drainMode', () {
    setDrainMode(true);
    final ctx = WsConnectionContext(tier: 'authuser', connectionId: 'c1')
      ..authenticated = true
      ..userId = 'u1';
    final msg = WsClientMessage(
      msgType: 'subscribe',
      channel: 'demo/room',
      payload: {'room_id': 'demo'},
    );
    expect(
      () => handleDemoRoomMessage(ctx, msg),
      throwsA(
        isA<AppError>().having((e) => e.code, 'code', drainModeError.code),
      ),
    );
  });

  test('event allowed when drainMode if already in room', () {
    setDrainMode(false);
    connectionRegistry.register('c1', (_) {});
    roomRegistry.subscribe('demo', 'c1', userId: 'u1');
    setDrainMode(true);
    final ctx = WsConnectionContext(tier: 'authuser', connectionId: 'c1')
      ..authenticated = true
      ..userId = 'u1';
    final msg = WsClientMessage(
      msgType: 'event',
      channel: 'demo/room',
      payload: {'room_id': 'demo', 'text': 'hi'},
    );
    final result = handleDemoRoomMessage(ctx, msg);
    expect(result, isNotNull);
    expect(result!['type'], 'event');
  });

  test('serverMaintenance error frame shape', () {
    final frame = jsonDecode(AppError(serverMaintenance).toWsFrame())
        as Map<String, dynamic>;
    expect(frame['ok'], isFalse);
    expect(frame['error']['code'], 'server_maintenance');
  });
}
