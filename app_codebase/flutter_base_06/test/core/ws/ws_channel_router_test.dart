import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/ws/ws_channel_router.dart';

void main() {
  group('WsChannelRouter', () {
    test('dispatches to prefix handler', () {
      final router = WsChannelRouter();
      String? received;
      router.register('demo', (connectionId, data) {
        received = '$connectionId:${data['channel']}';
      });

      router.dispatch('dart', {'channel': 'demo/echo', 'payload': {}});

      expect(received, 'dart:demo/echo');
    });

    test('does not dispatch when channel missing', () {
      final router = WsChannelRouter();
      var count = 0;
      router.register('demo', (_, __) => count++);

      router.dispatch('dart', {'payload': {}});

      expect(count, 0);
    });

    test('example prefix routes nested channels', () {
      final router = WsChannelRouter();
      String? message;
      router.register('example', (_, data) {
        message = data['payload']?['message']?.toString();
      });

      router.dispatch('dart', {
        'channel': 'example/state',
        'payload': {'message': 'hello'},
      });

      expect(message, 'hello');
    });
  });
}
