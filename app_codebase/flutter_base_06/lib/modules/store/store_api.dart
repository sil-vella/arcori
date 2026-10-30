import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import '../avari/avari_api.dart';

class FragmentPack {
  const FragmentPack({
    required this.productId,
    required this.fragments,
    required this.priceLabel,
    required this.label,
    required this.description,
    required this.isPopular,
  });

  factory FragmentPack.fromJson(Map<String, dynamic> json) {
    return FragmentPack(
      productId: json['productId']?.toString() ?? '',
      fragments: _asInt(json['fragments']) ?? 0,
      priceLabel: json['priceLabel']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isPopular: json['isPopular'] == true,
    );
  }

  final String productId;
  final int fragments;
  final String priceLabel;
  final String label;
  final String description;
  final bool isPopular;

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class FragmentCatalog {
  const FragmentCatalog(this.packs);

  factory FragmentCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['packs'];
    final packs = <FragmentPack>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          packs.add(FragmentPack.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return FragmentCatalog(packs);
  }

  final List<FragmentPack> packs;
}

class FragmentPurchaseResult {
  const FragmentPurchaseResult({
    required this.productId,
    required this.fragmentsCredited,
    required this.goldArcori,
    required this.goldFragments,
    required this.idempotent,
  });

  factory FragmentPurchaseResult.fromJson(Map<String, dynamic> json) {
    return FragmentPurchaseResult(
      productId: json['productId']?.toString() ?? '',
      fragmentsCredited: FragmentPack._asInt(json['fragmentsCredited']) ?? 0,
      goldArcori: FragmentPack._asInt(json['goldArcori']) ?? 0,
      goldFragments: FragmentPack._asInt(json['goldFragments']) ?? 0,
      idempotent: json['idempotent'] == true,
    );
  }

  final String productId;
  final int fragmentsCredited;
  final int goldArcori;
  final int goldFragments;
  final bool idempotent;
}

class StoreApiClient {
  StoreApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<AvariApiOutcome<FragmentCatalog>> fetchCatalog({
    required String accessToken,
  }) async {
    return _get('/authuser/store/catalog', accessToken);
  }

  Future<AvariApiOutcome<FragmentPurchaseResult>> verifyPurchase({
    required String accessToken,
    required PurchaseDetails purchase,
  }) async {
    final fields = nativeVerifyFields(purchase);
    if (fields.isEmpty) {
      return AvariApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Store receipt was empty',
          rawCode: 'store/invalid_receipt',
        ),
      );
    }
    final path = _isIos
        ? '/authuser/store/apple/verify'
        : '/authuser/store/play/verify';
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'productId': purchase.productID,
          ...fields,
        }),
      );
      return _parsePurchase(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  Future<AvariApiOutcome<FragmentCatalog>> _get(
    String path,
    String accessToken,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseCatalog(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const AvariApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  AvariApiOutcome<FragmentCatalog> _parseCatalog(http.Response response) {
    final envelope = _decode(response.body);
    if (envelope == null || envelope['ok'] != true) {
      return AvariApiOutcome.failure(
        error: envelope == null
            ? _invalidError()
            : ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return AvariApiOutcome.failure(error: _invalidError());
    }
    return AvariApiOutcome.success(
      FragmentCatalog.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  AvariApiOutcome<FragmentPurchaseResult> _parsePurchase(http.Response response) {
    final envelope = _decode(response.body);
    if (envelope == null || envelope['ok'] != true) {
      return AvariApiOutcome.failure(
        error: envelope == null
            ? _invalidError()
            : ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return AvariApiOutcome.failure(error: _invalidError());
    }
    return AvariApiOutcome.success(
      FragmentPurchaseResult.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  ApiError _invalidError() {
    return ApiError(
      code: CoreApiErrorCode.internalError,
      message: 'Invalid server response',
      rawCode: 'internal_error',
    );
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  bool _isNetworkError(Exception error) {
    return error is SocketException ||
        error is http.ClientException ||
        error is TimeoutException;
  }
}

bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Play sends purchase_token. Apple sends the StoreKit signed transaction.
Map<String, String> nativeVerifyFields(PurchaseDetails purchase) {
  if (kIsWeb) return const {};
  final serverData = purchase.verificationData.serverVerificationData.trim();
  if (_isIos) {
    if (serverData.isNotEmpty) {
      return {'signedTransaction': serverData};
    }
    final txId = purchase.purchaseID?.trim() ?? '';
    if (txId.isNotEmpty) return {'transactionId': txId};
    return const {};
  }
  if (serverData.isNotEmpty) return {'purchaseToken': serverData};
  return const {};
}
