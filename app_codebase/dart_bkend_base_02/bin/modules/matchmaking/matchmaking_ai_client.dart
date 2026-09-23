/// Module-owned FastAPI client for AI seat fill.
library;

import 'dart:convert';

import '../../core/auth/auth_config.dart';
import '../../core/errors/app_error.dart';
import '../../core/http/fastapi_service_client.dart';
import 'matchmaking_errors.dart';

/// One AI seat fill from `/service/players/ai/sample`.
class AiSeatFill {
  const AiSeatFill({
    required this.userId,
    this.username,
  });

  final String userId;
  final String? username;
}

class MatchmakingAiClient {
  MatchmakingAiClient({FastApiServiceClient? fastApi})
      : _fastApi = fastApi ?? FastApiServiceClient();

  final FastApiServiceClient _fastApi;

  Future<List<AiSeatFill>> sampleAiSeats({
    required int count,
    List<String> excludeUserIds = const [],
  }) async {
    if (count <= 0) return const [];
    final uri = Uri.parse('${_fastApi.baseUrl}/service/players/ai/sample');
    try {
      final response = await _fastApi.client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Service-Key': serviceKey(),
            },
            body: jsonEncode({
              'count': count,
              'excludeUserIds': excludeUserIds,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body);
      if (body is! Map) {
        throw AppError(matchmakingAiUnavailable, message: 'Invalid AI sample');
      }
      final map = Map<String, dynamic>.from(body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          map['ok'] != true) {
        final err = map['error'];
        final message = err is Map
            ? (err['message']?.toString() ?? matchmakingAiUnavailable.message)
            : matchmakingAiUnavailable.message;
        throw AppError(matchmakingAiUnavailable, message: message);
      }
      final data = map['data'];
      if (data is! Map) {
        throw AppError(matchmakingAiUnavailable, message: 'AI data missing');
      }
      final players = data['players'];
      if (players is! List) {
        throw AppError(matchmakingAiUnavailable, message: 'AI players missing');
      }
      final fills = <AiSeatFill>[];
      for (final p in players) {
        if (p is! Map || p['userId'] == null) continue;
        final uid = p['userId'].toString().trim();
        if (uid.isEmpty) continue;
        final rawName = p['username']?.toString().trim() ??
            p['displayName']?.toString().trim() ??
            '';
        fills.add(
          AiSeatFill(
            userId: uid,
            username: rawName.isNotEmpty ? rawName : null,
          ),
        );
      }
      if (fills.length < count) {
        throw AppError(
          matchmakingAiUnavailable,
          message: 'Need $count AI, got ${fills.length}',
        );
      }
      return fills.take(count).toList();
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError(
        matchmakingAiUnavailable,
        message: 'AI sample request failed: $e',
      );
    }
  }

  /// Convenience when only ids are needed.
  Future<List<String>> sampleAiUserIds({
    required int count,
    List<String> excludeUserIds = const [],
  }) async {
    final seats = await sampleAiSeats(
      count: count,
      excludeUserIds: excludeUserIds,
    );
    return seats.map((s) => s.userId).toList();
  }
}
