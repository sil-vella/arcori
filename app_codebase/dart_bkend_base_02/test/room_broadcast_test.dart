import 'package:test/test.dart';

import '../bin/core/state/room/broadcast_hub.dart';
import '../bin/core/state/room/room_registry.dart';
import '../bin/core/state/connection_registry.dart';

void main() {
  test('room subscribe and broadcast excludes sender', () {
    final connections = ConnectionRegistry();
    final membership = RoomRegistry();
    final hub = BroadcastHub(connections: connections, membership: membership);

    final sent = <String, List<String>>{};
    connections.register('a', (frame) {
      sent.putIfAbsent('a', () => []).add(frame);
    });
    connections.register('b', (frame) {
      sent.putIfAbsent('b', () => []).add(frame);
    });

    membership.subscribe('demo', 'a', userId: 'user-a');
    membership.subscribe('demo', 'b', userId: 'user-b');

    hub.broadcastToRoom(
      'demo',
      channel: 'demo/room',
      type: 'event',
      payload: {'event': 'room_message', 'text': 'hi'},
      excludeConnectionId: 'a',
    );

    expect(sent['a'], isNull);
    expect(sent['b'], isNotEmpty);
  });

  test('onConnectionClosed removes membership', () {
    final membership = RoomRegistry();
    membership.subscribe('demo', 'conn-1', userId: 'u1');
    membership.onConnectionClosed('conn-1');
    expect(membership.connectionIds('demo'), isEmpty);
  });
}
