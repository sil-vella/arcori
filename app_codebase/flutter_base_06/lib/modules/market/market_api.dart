import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import '../avari/avari_api.dart';

class MarketSlammerSku {
  const MarketSlammerSku({
    required this.designId,
    required this.displayName,
    required this.shopPriceGoldArcori,
    required this.rechargePriceGoldArcori,
    required this.rechargeCharges,
    required this.maxCharges,
    required this.owned,
    required this.permanent,
    this.chargesRemaining,
    this.hitTarget,
    this.color,
    this.canAffordPurchase = false,
    this.canAffordRecharge = false,
  });

  factory MarketSlammerSku.fromJson(Map<String, dynamic> json) {
    return MarketSlammerSku(
      designId: json['designId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      shopPriceGoldArcori: _asInt(json['shopPriceGoldArcori']) ?? 4,
      rechargePriceGoldArcori: _asInt(json['rechargePriceGoldArcori']) ?? 4,
      rechargeCharges: _asInt(json['rechargeCharges']) ?? 100,
      maxCharges: _asInt(json['maxCharges']) ?? 20,
      owned: json['owned'] == true,
      permanent: json['permanent'] == true,
      chargesRemaining: _asInt(json['chargesRemaining']),
      hitTarget: json['hitTarget']?.toString(),
      color: json['color']?.toString(),
      canAffordPurchase: json['canAffordPurchase'] == true,
      canAffordRecharge: json['canAffordRecharge'] == true,
    );
  }

  final String designId;
  final String displayName;
  final int shopPriceGoldArcori;
  final int rechargePriceGoldArcori;
  final int rechargeCharges;
  final int maxCharges;
  final bool owned;
  final bool permanent;
  final int? chargesRemaining;
  final String? hitTarget;
  final String? color;
  final bool canAffordPurchase;
  final bool canAffordRecharge;

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class MarketSlammersList {
  const MarketSlammersList({
    required this.slammers,
    required this.goldArcori,
    required this.goldFragments,
  });

  factory MarketSlammersList.fromJson(Map<String, dynamic> json) {
    final raw = json['slammers'];
    final list = <MarketSlammerSku>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(MarketSlammerSku.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return MarketSlammersList(
      slammers: list,
      goldArcori: MarketSlammerSku._asInt(json['goldArcori']) ?? 0,
      goldFragments: MarketSlammerSku._asInt(json['goldFragments']) ?? 0,
    );
  }

  final List<MarketSlammerSku> slammers;
  final int goldArcori;
  final int goldFragments;
}

class MarketPurchaseResult {
  const MarketPurchaseResult({
    required this.designId,
    required this.chargesRemaining,
    required this.goldArcoriSpent,
    required this.goldArcori,
  });

  factory MarketPurchaseResult.fromJson(Map<String, dynamic> json) {
    return MarketPurchaseResult(
      designId: json['designId']?.toString() ?? '',
      chargesRemaining: MarketSlammerSku._asInt(json['chargesRemaining']) ?? 0,
      goldArcoriSpent: MarketSlammerSku._asInt(json['goldArcoriSpent']) ?? 0,
      goldArcori: MarketSlammerSku._asInt(json['goldArcori']) ?? 0,
    );
  }

  final String designId;
  final int chargesRemaining;
  final int goldArcoriSpent;
  final int goldArcori;
}

class MarketApiClient {
  MarketApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<AvariApiOutcome<MarketSlammersList>> fetchSlammers({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/market/slammers');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseList(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  Future<AvariApiOutcome<MarketPurchaseResult>> purchase({
    required String accessToken,
    required String designId,
  }) async {
    return _postDesign(
      path: '/authuser/market/slammers/purchase',
      accessToken: accessToken,
      designId: designId,
    );
  }

  Future<AvariApiOutcome<MarketPurchaseResult>> recharge({
    required String accessToken,
    required String designId,
  }) async {
    return _postDesign(
      path: '/authuser/market/slammers/recharge',
      accessToken: accessToken,
      designId: designId,
    );
  }

  Future<AvariApiOutcome<MarketPurchaseResult>> _postDesign({
    required String path,
    required String accessToken,
    required String designId,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'designId': designId}),
      );
      return _parsePurchase(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  AvariApiOutcome<MarketSlammersList> _parseList(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return AvariApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return AvariApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return AvariApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return AvariApiOutcome.success(
      MarketSlammersList.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  AvariApiOutcome<MarketPurchaseResult> _parsePurchase(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return AvariApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return AvariApiOutcome.failure(error: ApiError.fromEnvelope(envelope));
    }
    final data = envelope['data'];
    if (data is! Map) {
      return AvariApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return AvariApiOutcome.success(
      MarketPurchaseResult.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  Map<String, dynamic>? _decodeEnvelope(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}
