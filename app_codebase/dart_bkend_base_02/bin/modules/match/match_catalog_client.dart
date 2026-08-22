/// Service-tier catalog batch fetch for match freeze (module-owned client).
library;

import 'dart:convert';

import '../../core/auth/auth_config.dart';
import '../../core/errors/app_error.dart';
import '../../core/http/fastapi_service_client.dart';
import '../../utils/dev_logger.dart';
import 'match_errors.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

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

  /// Match-time Arcori pick after seats exist. Returns userId → arcoriId.
  Future<Map<String, String>> selectArcori({
    required List<Map<String, dynamic>> seats,
  }) async {
    final uri = Uri.parse('${_fastApi.baseUrl}/service/catalog/select_arcori');
    try {
      final response = await _fastApi.client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Service-Key': serviceKey(),
            },
            body: jsonEncode({'seats': seats}),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body);
      if (body is! Map) {
        throw AppError(
          matchCatalogFreezeFailed,
          message: 'Invalid select_arcori response',
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
          message: 'select_arcori data missing',
        );
      }
      final raw = data['selections'];
      if (raw is! List) {
        throw AppError(
          matchCatalogFreezeFailed,
          message: 'select_arcori selections missing',
        );
      }
      final out = <String, String>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final userId = item['userId']?.toString().trim() ?? '';
        final arcoriId = item['arcoriId']?.toString().trim() ?? '';
        if (userId.isEmpty || arcoriId.isEmpty) continue;
        out[userId] = arcoriId;
      }
      if (LOGGING_SWITCH) {
        customlog('match catalog select_arcori ok count=${out.length}');
      }
      return out;
    } on AppError {
      rethrow;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('match catalog select_arcori error: $e');
      }
      throw AppError(
        matchCatalogFreezeFailed,
        message: 'select_arcori request failed: $e',
      );
    }
  }
}
