/// Fetch special-event match rules from FastAPI (service tier).
library;

import 'dart:convert';

import '../../core/auth/auth_config.dart';
import '../../core/http/fastapi_service_client.dart';
import '../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class SpecialEventMatchRules {
  const SpecialEventMatchRules({
    required this.eventId,
    required this.players,
    required this.aiFill,
    required this.fillWindowSec,
    required this.rounds,
    required this.feeFragments,
    required this.arcoriSource,
    required this.designIds,
    this.subtype = '',
    this.arenaMode = 'seated_regions',
    this.resolvedArena,
    this.media = const {},
  });

  final String eventId;
  final String subtype;
  final int players;
  final bool aiFill;
  final int fillWindowSec;
  final int rounds;
  final int feeFragments;
  final String arcoriSource;
  final List<String> designIds;
  final String arenaMode;
  final Map<String, dynamic>? resolvedArena;
  final Map<String, dynamic> media;

  factory SpecialEventMatchRules.fromJson(Map<String, dynamic> json) {
    final arcori = json['arcori'] is Map
        ? Map<String, dynamic>.from(json['arcori'] as Map)
        : <String, dynamic>{};
    final arena = json['arena'] is Map
        ? Map<String, dynamic>.from(json['arena'] as Map)
        : <String, dynamic>{};
    final resolved = arena['resolved'];
    final designRaw = arcori['designIds'] ?? arcori['design_ids'];
    final designIds = designRaw is List
        ? designRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    return SpecialEventMatchRules(
      eventId: json['eventId']?.toString().trim() ?? '',
      subtype: json['subtype']?.toString().trim() ?? '',
      players: _asInt(json['players'], 3),
      aiFill: json['aiFill'] != false,
      fillWindowSec: _asInt(json['fillWindowSec'], 5),
      rounds: _asInt(json['rounds'], 2),
      feeFragments: _asInt(json['feeFragments'], 2),
      arcoriSource: arcori['source']?.toString().trim() ?? 'circulation',
      designIds: designIds,
      arenaMode: arena['mode']?.toString().trim() ?? 'seated_regions',
      resolvedArena: resolved is Map
          ? Map<String, dynamic>.from(resolved)
          : null,
      media: json['media'] is Map
          ? Map<String, dynamic>.from(json['media'] as Map)
          : const {},
    );
  }
}

int _asInt(dynamic raw, int fallback) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

class SpecialEventsClient {
  SpecialEventsClient({FastApiServiceClient? fastApi})
      : _fastApi = fastApi ?? FastApiServiceClient();

  final FastApiServiceClient _fastApi;

  Future<SpecialEventMatchRules?> fetchMatchRules(String eventId) async {
    final eid = eventId.trim();
    if (eid.isEmpty) return null;
    final uri = Uri.parse(
      '${_fastApi.baseUrl}/service/special_events/match_rules',
    ).replace(queryParameters: {'eventId': eid});
    try {
      final response = await _fastApi.client
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Service-Key': serviceKey(),
            },
          )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      if (body is! Map) return null;
      final map = Map<String, dynamic>.from(body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          map['ok'] != true) {
        if (LOGGING_SWITCH) {
          customlog(
            'special_events: match_rules fail status=${response.statusCode} '
            'eventId=$eid',
          );
        }
        return null;
      }
      final data = map['data'];
      if (data is! Map) return null;
      final rules = SpecialEventMatchRules.fromJson(
        Map<String, dynamic>.from(data),
      );
      if (LOGGING_SWITCH) {
        customlog(
          'special_events: match_rules ok eventId=${rules.eventId} '
          'players=${rules.players} rounds=${rules.rounds} '
          'arena=${rules.arenaMode}',
        );
      }
      return rules;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('special_events: match_rules error eventId=$eid err=$e');
      }
      return null;
    }
  }
}
