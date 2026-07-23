import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  late Process process;
  late String wsUrl;

  setUpAll(() async {
    process = await Process.start(
      'dart',
      ['run', 'bin/app.dart'],
      environment: {
        'PORT': '0',
        'ARCORI_ENV': 'local',
        'JWT_SECRET': 'dev-local-jwt-secret-change-me',
        'JWT_REFRESH_SECRET': 'dev-local-jwt-refresh-secret-change-me',
        'SERVICE_KEY': 'dev-local-service-key-change-me',
        'ARCORI_ALLOW_DEV_LOGIN': 'true',
      },
      workingDirectory: Directory.current.path,
    );
    final line = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final match = RegExp(r'port (\d+)').firstMatch(line);
    if (match == null) {
      throw StateError('Could not parse port: $line');
    }
    wsUrl = 'ws://127.0.0.1:${match.group(1)}/ws/public';
  });

  tearDownAll(() {
    process.kill();
  });

  test('public ping pong without auth', () async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    final messages = channel.stream.map((e) => e.toString()).asBroadcastStream();

    final connected = jsonDecode(await messages.first) as Map;
    expect(connected['ok'], isTrue);
    expect(connected['data']['type'], 'connected');

    channel.sink.add(jsonEncode({'type': 'ping', 'channel': 'system'}));
    final pong = jsonDecode(await messages.first) as Map;
    expect(pong['ok'], isTrue);
    expect(pong['data']['type'], 'pong');

    await channel.sink.close();
  });
}
