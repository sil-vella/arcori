import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<String> _devToken(String baseHttp, String userId) async {
  final res = await http.post(
    Uri.parse('$baseHttp/public/auth/dev-login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'user_id': userId}),
  );
  expect(res.statusCode, 200);
  final body = jsonDecode(res.body) as Map;
  return body['data']['access_token'] as String;
}

Future<void> _wsAuth(WebSocketChannel channel, Stream<String> messages, String token) async {
  channel.sink.add(jsonEncode({
    'type': 'auth',
    'channel': 'system',
    'payload': {'access_token': token},
  }));
  final frame = jsonDecode(await messages.first) as Map;
  expect(frame['ok'], isTrue);
}

void main() {
  late Process process;
  late String httpBase;
  late String wsBase;

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
    final port = match.group(1);
    httpBase = 'http://127.0.0.1:$port';
    wsBase = 'ws://127.0.0.1:$port/ws/authuser';
  });

  tearDownAll(() {
    process.kill();
  });

  test('example/state event updates revision', () async {
    final token = await _devToken(httpBase, 'example-user');
    final channel = WebSocketChannel.connect(Uri.parse(wsBase));
    final messages = channel.stream.map((e) => e.toString()).asBroadcastStream();

    await _wsAuth(channel, messages, token);

    channel.sink.add(jsonEncode({
      'type': 'event',
      'channel': 'example/state',
      'payload': {'message': 'from-ws'},
    }));

    final frame = jsonDecode(await messages.first) as Map;
    expect(frame['ok'], isTrue);
    expect(frame['data']['payload']['revision'], 1);
    expect(frame['data']['payload']['message'], 'from-ws');

    await channel.sink.close();
  });
}
