/// Service-tier catalog batch fetch for match freeze (module-owned client).
library;

import 'dart:convert';

import '../../core/auth/auth_config.dart';
import '../../core/errors/app_error.dart';
import '../../core/http/fastapi_service_client.dart';
import '../../utils/dev_logger.dart';
import 'match_errors.dart';

const bool LOGGING_SWITCH = false; // ignore: constant_identifier_names

class MatchCatalogClient {
  MatchCatalogClient({FastApiServiceClient? fastApi})
      : _fastApi = fastApi ?? FastApiServiceClient();

  final FastApiServiceClient _fastApi;

  Future<Map<String, Map<String, dynamic>>> fetchDesigns(List<String> ids) async {
    final uri = Uri.parse('${_fastApi.baseUrl}/service/catalog/designs');
    try {
      final response = await _fastApi.client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Service-Key': serviceKey(),
            },
            body: jsonEncode({'ids': ids}),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body);
      if (body is! Map) {
        throw AppError(
          matchCatalogFreezeFailed,
          message: 'Invalid catalog response',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          map['ok'] != true) {
        final err = map['error'];
        final message = err is Map
            ? (err['message']?.toString() ?? matchCatalogFreezeFailed.message)
            : matchCatalogFreezeFailed.message;
        throw AppError(matchCatalogFreezeFailed, message: message);
      }
      final data = map['data'];
      if (data is! Map) {
        throw AppError(
          matchCatalogFreezeFailed,
          message: 'Catalog data missing',
        );
      }
      final designsRaw = data['designs'];
      if (designsRaw is! Map) {
        throw AppError(
          matchCatalogFreezeFailed,
          message: 'Catalog designs missing',
        );
      }
      final out = <String, Map<String, dynamic>>{};
      designsRaw.forEach((key, value) {
        if (value is Map) {
          out[key.toString()] = Map<String, dynamic>.from(value);
        }
      });
      return out;
    } on AppError {
      rethrow;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('match catalog fetch error: $e');
      }
      throw AppError(
        matchCatalogFreezeFailed,
        message: 'Catalog freeze request failed: $e',
      );
    }
  }
}
