/// FastAPI service-tier client — best-effort calls from Dart modules.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/auth_config.dart';
import '../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = false; // ignore: constant_identifier_names

class FastApiServiceClient {
  FastApiServiceClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  http.Client get client => _client;

  static String _defaultBaseUrl() {
    final fromEnv = Platform.environment['FASTAPI_SERVICE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return 'http://127.0.0.1:8000';
  }

  /// Record durable example payload — logs on failure; does not throw.
  Future<void> recordExampleModule({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$_baseUrl/service/example_module/record');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Service-Key': serviceKey(),
            },
            body: jsonEncode({
              'user_id': userId,
              'payload': payload,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (LOGGING_SWITCH) {
          customlog(
            'example_module record failed: ${response.statusCode} ${response.body}',
          );
        }
      }
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('example_module record error: $e');
      }
    }
  }
}
