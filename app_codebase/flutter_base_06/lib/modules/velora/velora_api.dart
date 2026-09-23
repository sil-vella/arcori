import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';
import 'velora_models.dart';

class VeloraApiOutcome<T> {
  const VeloraApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const VeloraApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const VeloraApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const VeloraApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null && !isNetworkError;
}

class CatalogIndexResult {
  const CatalogIndexResult({
    required this.items,
    required this.total,
  });

  final List<DesignSummary> items;
  final int total;
}

class VeloraApiClient {
  VeloraApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  /// Circulating designs only (`worldState == Active`).
  /// Optional [theme] / [series] filter by theme code|name and series key|slug.
  Future<VeloraApiOutcome<CatalogIndexResult>> fetchIndex({
    required String accessToken,
    String? theme,
    String? series,
  }) {
    final params = <String, String>{'circulating': '1'};
    if (theme != null && theme.isNotEmpty) {
      params['theme'] = theme;
    }
    if (series != null && series.isNotEmpty) {
      params['series'] = series;
    }
    final uri = Uri.parse('$_baseUrl/authuser/catalog/index').replace(
      queryParameters: params,
    );
    return _get(uri, accessToken: accessToken, parse: _parseIndex);
  }

  /// Series list for Velora home.
  Future<VeloraApiOutcome<List<CatalogSeriesEntry>>> fetchSeries({
    required String accessToken,
  }) {
    final uri = Uri.parse('$_baseUrl/authuser/catalog/series');
    return _get(uri, accessToken: accessToken, parse: _parseSeries);
  }

  /// Theme list from catalog meta (lore / labels).
  Future<VeloraApiOutcome<List<CatalogThemeEntry>>> fetchThemes({
    required String accessToken,
  }) {
    final uri = Uri.parse('$_baseUrl/authuser/catalog/meta');
    return _get(uri, accessToken: accessToken, parse: _parseThemes);
  }

  Future<VeloraApiOutcome<DesignDetail>> fetchDesign({
    required String accessToken,
    required String internalId,
  }) {
    final uri = Uri.parse('$_baseUrl/authuser/catalog/design').replace(
      queryParameters: {'id': internalId},
    );
    return _get(uri, accessToken: accessToken, parse: _parseDesign);
  }

  Future<VeloraApiOutcome<DesignStandings>> fetchStandings({
    required String accessToken,
    required String internalId,
  }) {
    final uri = Uri.parse('$_baseUrl/authuser/standings/design').replace(
      queryParameters: {'id': internalId},
    );
    return _get(uri, accessToken: accessToken, parse: _parseStandings);
  }

  Future<VeloraApiOutcome<T>> _get<T>(
    Uri uri, {
    required String accessToken,
    required VeloraApiOutcome<T> Function(http.Response) parse,
  }) async {
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return parse(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) {
        return const VeloraApiOutcome.networkFailure();
      }
      rethrow;
    }
  }

  VeloraApiOutcome<CatalogIndexResult> _parseIndex(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return VeloraApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return VeloraApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'] as Map<String, dynamic>? ?? const {};
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) => DesignSummary.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((d) => d.internalId.isNotEmpty)
            .toList()
        : <DesignSummary>[];
    final total = data['total'] is int
        ? data['total'] as int
        : int.tryParse('${data['total']}') ?? items.length;
    return VeloraApiOutcome.success(
      CatalogIndexResult(items: items, total: total),
    );
  }

  VeloraApiOutcome<List<CatalogSeriesEntry>> _parseSeries(
    http.Response response,
  ) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return VeloraApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return VeloraApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'] as Map<String, dynamic>? ?? const {};
    final raw = data['series'];
    final series = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (item) =>
                  CatalogSeriesEntry.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((s) => s.key.isNotEmpty || s.seriesKey.isNotEmpty)
            .toList()
        : <CatalogSeriesEntry>[];
    return VeloraApiOutcome.success(series);
  }

  VeloraApiOutcome<List<CatalogThemeEntry>> _parseThemes(
    http.Response response,
  ) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return VeloraApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return VeloraApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'] as Map<String, dynamic>? ?? const {};
    final meta = data['themes_subthemes'];
    final rawThemes = meta is Map ? meta['themes'] : null;
    final themes = rawThemes is List
        ? rawThemes
            .whereType<Map>()
            .map(
              (item) =>
                  CatalogThemeEntry.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((t) => t.themeCode.isNotEmpty)
            .toList()
        : <CatalogThemeEntry>[];
    return VeloraApiOutcome.success(themes);
  }

  VeloraApiOutcome<DesignDetail> _parseDesign(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return VeloraApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return VeloraApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return VeloraApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return VeloraApiOutcome.success(
      DesignDetail.fromJson(Map<String, dynamic>.from(data)),
    );
  }

  VeloraApiOutcome<DesignStandings> _parseStandings(http.Response response) {
    final envelope = _decodeEnvelope(response.body);
    if (envelope == null) {
      return VeloraApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return VeloraApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return VeloraApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return VeloraApiOutcome.success(
      DesignStandings.fromJson(Map<String, dynamic>.from(data)),
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
