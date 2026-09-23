/// Service-tier owned-slammer verify for match seating (module-owned client).
library;

import 'dart:convert';

import '../../core/auth/auth_config.dart';
import '../../core/errors/app_error.dart';
import '../../core/http/fastapi_service_client.dart';
import '../../utils/dev_logger.dart';
import 'match_errors.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class MatchAvariClient {
  MatchAvariClient({FastApiServiceClient? fastApi})
      : _fastApi = fastApi ?? FastApiServiceClient();

  final FastApiServiceClient _fastApi;

  /// Returns userId → owned (or fallback) slammerId. Empty values omitted.
  Future<Map<String, String>> verifySlammers({
    required List<Map<String, dynamic>> seats,
  }) async {
    final uri = Uri.parse('${_fastApi.baseUrl}/service/avari/verify_slammers');
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
          message: 'Invalid verify_slammers response',
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
          message: 'verify_slammers data missing',
        );
      }
      final raw = data['assignments'];
      if (raw is! List) {
        throw AppError(
          matchCatalogFreezeFailed,
          message: 'verify_slammers assignments missing',
        );
      }
      final out = <String, String>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final userId = item['userId']?.toString().trim() ?? '';
        final slammerId = item['slammerId']?.toString().trim() ?? '';
        if (userId.isEmpty || slammerId.isEmpty) continue;
        out[userId] = slammerId;
      }
      if (LOGGING_SWITCH) {
        customlog('match avari verify_slammers ok count=${out.length}');
      }
      return out;
    } on AppError {
      rethrow;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('match avari verify_slammers error: $e');
      }
      throw AppError(
        matchCatalogFreezeFailed,
        message: 'verify_slammers request failed: $e',
      );
    }
  }

  /// Deduct one charge for a slam. Permanent / missing → noop success.
  /// Throws [matchSlammerNoCharges] when the equipped slammer is empty.
  Future<void> spendSlammerCharge({
    required String userId,
    required String designId,
    String? matchId,
    String? intentId,
  }) async {
    final uid = userId.trim();
    final did = designId.trim();
    if (uid.isEmpty || did.isEmpty) return;

    final uri =
        Uri.parse('${_fastApi.baseUrl}/service/avari/spend_slammer_charge');
    try {
      final response = await _fastApi.client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Service-Key': serviceKey(),
            },
            body: jsonEncode({
              'userId': uid,
              'designId': did,
              if (matchId != null && matchId.trim().isNotEmpty)
                'matchId': matchId.trim(),
              if (intentId != null && intentId.trim().isNotEmpty)
                'intentId': intentId.trim(),
            }),
          )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      if (body is! Map) {
        throw AppError(
          matchInvalidRequest,
          message: 'Invalid spend_slammer_charge response',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          map['ok'] != true) {
        final err = map['error'];
        final code = err is Map ? err['code']?.toString() : null;
        final message = err is Map
            ? (err['message']?.toString() ?? matchSlammerNoCharges.message)
            : matchSlammerNoCharges.message;
        if (code == 'avari/slammer_no_charges' ||
            response.statusCode == 402) {
          throw AppError(matchSlammerNoCharges, message: message);
        }
        throw AppError(matchInvalidRequest, message: message);
      }
      if (LOGGING_SWITCH) {
        customlog(
          'match avari spend_slammer_charge ok user=$uid design=$did',
        );
      }
    } on AppError {
      rethrow;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('match avari spend_slammer_charge error: $e');
      }
      // Fail closed: do not slam if charge spend cannot be confirmed.
      throw AppError(
        matchInvalidRequest,
        message: 'spend_slammer_charge request failed: $e',
      );
    }
  }
}
