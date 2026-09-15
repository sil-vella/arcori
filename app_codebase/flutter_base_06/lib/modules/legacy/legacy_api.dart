import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import '../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class LegacyApiOutcome<T> {
  const LegacyApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const LegacyApiOutcome.success(T data) : this._(data: data);

  const LegacyApiOutcome.failure({ApiError? error}) : this._(error: error);

  const LegacyApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null && !isNetworkError;
}

class LegacyOffer {
  const LegacyOffer({
    required this.designId,
    required this.generationNumber,
    required this.phase,
    this.serial = '',
    this.canPreserveAsFirstOffer = false,
    this.canPreserveAsLeader = false,
    this.firstOfferExpiresAt,
    this.viewerMasteryPoints = 0,
    this.preservationRequirement = 0,
  });

  factory LegacyOffer.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    final designId = json['designId']?.toString() ?? '';
    final serial = json['serial']?.toString().trim().isNotEmpty == true
        ? json['serial'].toString()
        : designId;
    return LegacyOffer(
      designId: designId,
      serial: serial,
      generationNumber: asInt(json['generationNumber']),
      phase: json['phase']?.toString() ?? '',
      canPreserveAsFirstOffer: json['canPreserveAsFirstOffer'] == true,
      canPreserveAsLeader: json['canPreserveAsLeader'] == true,
      firstOfferExpiresAt: json['firstOfferExpiresAt']?.toString(),
      viewerMasteryPoints: asInt(json['viewerMasteryPoints']),
      preservationRequirement: asInt(json['preservationRequirement']),
    );
  }

  final String designId;
  final String serial;
  final int generationNumber;
  final String phase;
  final bool canPreserveAsFirstOffer;
  final bool canPreserveAsLeader;
  final String? firstOfferExpiresAt;
  final int viewerMasteryPoints;
  final int preservationRequirement;

  bool get canPreserve => canPreserveAsFirstOffer || canPreserveAsLeader;
}

class LegacyPreserveStart {
  const LegacyPreserveStart({
    required this.intentId,
    required this.designId,
    required this.generationNumber,
    this.checkoutUrl = '',
    this.orderId = '',
    this.status = 'pending',
    this.applied = false,
    this.stubComplete = false,
    this.serial = '',
    this.echoGenerationNumber,
    this.titlesGranted = const [],
    this.creatorAttributed = false,
    this.offers = const [],
    this.items = const [],
    this.checkoutPayload,
  });

  factory LegacyPreserveStart.fromJson(Map<String, dynamic> json) {
    final rawOffers = json['offers'];
    final offers = <LegacyOffer>[];
    if (rawOffers is List) {
      for (final row in rawOffers) {
        if (row is Map) {
          offers.add(LegacyOffer.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    final items = _parseMintItems(json);
    final designId = json['designId']?.toString() ??
        (items.isNotEmpty ? items.first.designId : '');
    final serial = json['serial']?.toString().trim().isNotEmpty == true
        ? json['serial'].toString()
        : (items.isNotEmpty ? items.first.serial : designId);
    final reason = json['reason']?.toString() ?? '';
    final status = json['status']?.toString() ??
        (json['stubComplete'] == true || reason == 'preserved'
            ? 'complete'
            : 'pending');
    final checkout = json['checkoutPayload'];
    return LegacyPreserveStart(
      intentId: json['intentId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      checkoutUrl: json['checkoutUrl']?.toString() ?? '',
      designId: designId,
      serial: serial,
      generationNumber: json['generationNumber'] is int
          ? json['generationNumber'] as int
          : int.tryParse('${json['generationNumber']}') ??
              (items.isNotEmpty ? items.first.generationNumber : 0),
      status: status,
      applied: json['applied'] == true || reason == 'preserved',
      stubComplete: json['stubComplete'] == true,
      echoGenerationNumber: json['echoGenerationNumber'] is int
          ? json['echoGenerationNumber'] as int
          : int.tryParse('${json['echoGenerationNumber']}'),
      titlesGranted: json['titlesGranted'] is List
          ? (json['titlesGranted'] as List).map((e) => e.toString()).toList()
          : const [],
      creatorAttributed: json['creatorAttributed'] == true,
      offers: offers,
      items: items,
      checkoutPayload:
          checkout is Map ? Map<String, dynamic>.from(checkout) : null,
    );
  }

  final String intentId;
  final String orderId;
  final String checkoutUrl;
  final String designId;
  final String serial;
  final int generationNumber;
  final String status;
  final bool applied;
  final bool stubComplete;
  final int? echoGenerationNumber;
  final List<String> titlesGranted;
  final bool creatorAttributed;
  final List<LegacyOffer> offers;
  final List<LegacyMintItem> items;
  final Map<String, dynamic>? checkoutPayload;

  LegacyMintComplete toMintComplete() {
    final resolvedItems = items.isNotEmpty
        ? items
        : [
            LegacyMintItem(
              designId: designId,
              serial: serial.isNotEmpty ? serial : designId,
              generationNumber: generationNumber,
              echoGenerationNumber: echoGenerationNumber,
            ),
          ];
    return LegacyMintComplete(
      applied: applied || stubComplete,
      reason: stubComplete ? 'preserved' : status,
      status: status == 'complete' || stubComplete ? 'complete' : status,
      designId: resolvedItems.first.designId,
      serial: resolvedItems.first.serial,
      generationNumber: resolvedItems.first.generationNumber,
      echoGenerationNumber: resolvedItems.first.echoGenerationNumber,
      titlesGranted: titlesGranted,
      creatorAttributed: creatorAttributed,
      items: resolvedItems,
    );
  }
}

class LegacyMintItem {
  const LegacyMintItem({
    required this.designId,
    required this.generationNumber,
    this.serial = '',
    this.echoGenerationNumber,
  });

  factory LegacyMintItem.fromJson(Map<String, dynamic> json) {
    final designId = json['designId']?.toString() ?? '';
    final serial = json['serial']?.toString().trim().isNotEmpty == true
        ? json['serial'].toString()
        : designId;
    return LegacyMintItem(
      designId: designId,
      serial: serial,
      generationNumber: json['generationNumber'] is int
          ? json['generationNumber'] as int
          : int.tryParse('${json['generationNumber']}') ?? 0,
      echoGenerationNumber: json['echoGenerationNumber'] is int
          ? json['echoGenerationNumber'] as int
          : int.tryParse('${json['echoGenerationNumber']}'),
    );
  }

  final String designId;
  final String serial;
  final int generationNumber;
  final int? echoGenerationNumber;
}

List<LegacyMintItem> _parseMintItems(Map<String, dynamic> json) {
  final out = <LegacyMintItem>[];
  final rawItems = json['items'];
  if (rawItems is List) {
    for (final row in rawItems) {
      if (row is Map) {
        final item = LegacyMintItem.fromJson(Map<String, dynamic>.from(row));
        if (item.designId.isNotEmpty) out.add(item);
      }
    }
  }
  if (out.isNotEmpty) return out;
  final rawMints = json['mints'];
  if (rawMints is List) {
    for (final row in rawMints) {
      if (row is Map) {
        final item = LegacyMintItem.fromJson(Map<String, dynamic>.from(row));
        if (item.designId.isNotEmpty) out.add(item);
      }
    }
  }
  return out;
}

class LegacyMintComplete {
  const LegacyMintComplete({
    required this.applied,
    required this.reason,
    required this.designId,
    required this.generationNumber,
    this.status = 'complete',
    this.serial = '',
    this.echoGenerationNumber,
    this.titlesGranted = const [],
    this.creatorAttributed = false,
    this.items = const [],
  });

  factory LegacyMintComplete.fromJson(Map<String, dynamic> json) {
    final titles = json['titlesGranted'];
    final reason = json['reason']?.toString() ?? '';
    final status = json['status']?.toString() ??
        (reason == 'processing' ? 'processing' : 'complete');
    final items = _parseMintItems(json);
    final designId = json['designId']?.toString() ??
        (items.isNotEmpty ? items.first.designId : '');
    final serial = json['serial']?.toString().trim().isNotEmpty == true
        ? json['serial'].toString()
        : (items.isNotEmpty ? items.first.serial : designId);
    return LegacyMintComplete(
      applied: json['applied'] == true || reason == 'already_applied',
      reason: reason,
      status: status,
      designId: designId,
      serial: serial,
      generationNumber: json['generationNumber'] is int
          ? json['generationNumber'] as int
          : int.tryParse('${json['generationNumber']}') ??
              (items.isNotEmpty ? items.first.generationNumber : 0),
      echoGenerationNumber: json['echoGenerationNumber'] is int
          ? json['echoGenerationNumber'] as int
          : int.tryParse('${json['echoGenerationNumber']}'),
      titlesGranted: titles is List
          ? titles.map((e) => e.toString()).toList()
          : const [],
      creatorAttributed: json['creatorAttributed'] == true,
      items: items.isNotEmpty
          ? items
          : (designId.isEmpty
              ? const []
              : [
                  LegacyMintItem(
                    designId: designId,
                    serial: serial,
                    generationNumber: json['generationNumber'] is int
                        ? json['generationNumber'] as int
                        : int.tryParse('${json['generationNumber']}') ?? 0,
                    echoGenerationNumber: json['echoGenerationNumber'] is int
                        ? json['echoGenerationNumber'] as int
                        : int.tryParse('${json['echoGenerationNumber']}'),
                  ),
                ]),
    );
  }

  final bool applied;
  final String reason;
  final String status;
  final String designId;
  final String serial;
  final int generationNumber;
  final int? echoGenerationNumber;
  final List<String> titlesGranted;
  final bool creatorAttributed;
  final List<LegacyMintItem> items;

  List<LegacyMintItem> get preservedItems => items.isNotEmpty
      ? items
      : [
          LegacyMintItem(
            designId: designId,
            serial: serial.isNotEmpty ? serial : designId,
            generationNumber: generationNumber,
            echoGenerationNumber: echoGenerationNumber,
          ),
        ];
}

class LegacyApiClient {
  LegacyApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<LegacyApiOutcome<LegacyOffer>> fetchOffer({
    required String accessToken,
    required String designId,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/legacy/offer').replace(
      queryParameters: {'designId': designId},
    );
    try {
      if (LOGGING_SWITCH) {
        customlog('legacyApi: GET offer designId=$designId');
      }
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      final out = _parseOffer(response);
      if (LOGGING_SWITCH) {
        customlog(
          'legacyApi: offer ok=${out.isSuccess} phase=${out.data?.phase} '
          'canPreserve=${out.data?.canPreserve}',
        );
      }
      return out;
    } on Exception catch (e) {
      if (_isNetworkError(e)) return const LegacyApiOutcome.networkFailure();
      rethrow;
    }
  }

  Future<LegacyApiOutcome<LegacyOffer>> decline({
    required String accessToken,
    required String designId,
    int? generationNumber,
    List<LegacyOffer>? offers,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/legacy/decline');
    try {
      final body = <String, dynamic>{};
      if (offers != null && offers.isNotEmpty) {
        body['offers'] = [
          for (final o in offers)
            {
              'designId': o.designId,
              'generationNumber': o.generationNumber,
            },
        ];
      } else {
        body['designId'] = designId;
        if (generationNumber != null) {
          body['generationNumber'] = generationNumber;
        }
      }
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return _parseOffer(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) return const LegacyApiOutcome.networkFailure();
      rethrow;
    }
  }

  Future<LegacyApiOutcome<LegacyPreserveStart>> preserveStart({
    required String accessToken,
    required String designId,
    int? generationNumber,
    List<LegacyOffer>? offers,
    List<LegacyOffer>? declineOffers,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/legacy/preserve/start');
    try {
      final body = <String, dynamic>{};
      if (offers != null && offers.isNotEmpty) {
        body['offers'] = [
          for (final o in offers)
            {
              'designId': o.designId,
              'serial': o.serial,
              'generationNumber': o.generationNumber,
            },
        ];
      } else {
        body['designId'] = designId;
        body['serial'] = designId;
        if (generationNumber != null) {
          body['generationNumber'] = generationNumber;
        }
      }
      if (declineOffers != null && declineOffers.isNotEmpty) {
        body['declineOffers'] = [
          for (final o in declineOffers)
            {
              'designId': o.designId,
              'serial': o.serial,
              'generationNumber': o.generationNumber,
            },
        ];
      }
      if (LOGGING_SWITCH) {
        customlog(
          'legacyApi: POST preserve/start '
          'n=${offers?.length ?? 1} decline=${declineOffers?.length ?? 0} '
          'designId=$designId',
        );
      }
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final out = _parseStart(response);
      if (LOGGING_SWITCH) {
        customlog(
          'legacyApi: preserve/start ok=${out.isSuccess} '
          'stub=${out.data?.stubComplete} intentId=${out.data?.intentId}',
        );
      }
      return out;
    } on Exception catch (e) {
      if (_isNetworkError(e)) return const LegacyApiOutcome.networkFailure();
      rethrow;
    }
  }

  Future<LegacyApiOutcome<LegacyMintComplete>> preserveComplete({
    required String accessToken,
    required String intentId,
    required String orderId,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/legacy/preserve/complete');
    try {
      if (LOGGING_SWITCH) {
        customlog(
          'legacyApi: POST preserve/complete intentId=$intentId '
          'orderId=$orderId',
        );
      }
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'intentId': intentId, 'orderId': orderId}),
      );
      final out = _parseComplete(response);
      if (LOGGING_SWITCH) {
        customlog(
          'legacyApi: preserve/complete ok=${out.isSuccess} '
          'status=${out.data?.status} reason=${out.data?.reason}',
        );
      }
      return out;
    } on Exception catch (e) {
      if (_isNetworkError(e)) return const LegacyApiOutcome.networkFailure();
      rethrow;
    }
  }

  LegacyApiOutcome<LegacyOffer> _parseOffer(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return LegacyApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return LegacyApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return LegacyApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return LegacyApiOutcome.success(
      LegacyOffer.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  LegacyApiOutcome<LegacyPreserveStart> _parseStart(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return LegacyApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return LegacyApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return LegacyApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return LegacyApiOutcome.success(
      LegacyPreserveStart.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  LegacyApiOutcome<LegacyMintComplete> _parseComplete(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return LegacyApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return LegacyApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return LegacyApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return LegacyApiOutcome.success(
      LegacyMintComplete.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  Map<String, dynamic>? _decodeEnvelope(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}
