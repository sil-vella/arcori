import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  late String baseUrl;
  late Process p;

  setUp(() async {
    p = await Process.start(
      'dart',
      ['run', 'bin/app.dart'],
      environment: {'PORT': '0'},
      workingDirectory: Directory.current.path,
    );
    final line = await p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final match = RegExp(r'port (\d+)').firstMatch(line);
    if (match == null) {
      throw StateError('Could not parse port from server line: $line');
    }
    baseUrl = 'http://127.0.0.1:${match.group(1)}';
  });

  tearDown(() => p.kill());

  test('public root returns JSON envelope', () async {
    final response = await get(Uri.parse(baseUrl));
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('application/json'));
    expect(response.body, contains('"ok":true'));
    expect(response.body, contains('dart_bkend_base_02'));
  });
}
