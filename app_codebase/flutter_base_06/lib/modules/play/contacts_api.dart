import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/api_error.dart';
import '../../core/ws/ws_config.dart';

class ContactUser {
  const ContactUser({
    required this.userId,
    required this.username,
    required this.displayName,
  });

  final String userId;
  final String username;
  final String displayName;

  factory ContactUser.fromJson(Map<String, dynamic> json) {
    return ContactUser(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
    );
  }
}

class ContactsApiOutcome<T> {
  const ContactsApiOutcome._({
    this.data,
    this.error,
    this.isNetworkError = false,
  });

  const ContactsApiOutcome.success(T data)
      : this._(data: data, isNetworkError: false);

  const ContactsApiOutcome.failure({
    required ApiError error,
    bool isNetworkError = false,
  }) : this._(error: error, isNetworkError: isNetworkError);

  const ContactsApiOutcome.networkFailure()
      : this._(isNetworkError: true, error: null, data: null);

  final T? data;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => data != null && error == null;
}

class ContactsApiClient {
  ContactsApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? WsConfig.apiRestBase;

  final http.Client _client;
  final String _baseUrl;

  Future<ContactsApiOutcome<List<ContactUser>>> searchContactsByUsername({
    required String accessToken,
    required String query,
  }) async {
    final encoded = Uri.encodeQueryComponent(query);
    final uri = Uri.parse('$_baseUrl/authuser/contacts/search?query=$encoded');

    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseSearchOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) return const ContactsApiOutcome.networkFailure();
      rethrow;
    }
  }

  ContactsApiOutcome<List<ContactUser>> _parseSearchOutcome(
    http.Response response,
  ) {
    final envelope = _tryParseEnvelope(response);
    if (envelope == null) {
      return ContactsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return ContactsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }

    final data = envelope['data'];
    if (data is! Map) {
      return ContactsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    final users = data['users'];
    if (users is! List) {
      return ContactsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }

    return ContactsApiOutcome.success(
      users
          .whereType<Map>()
          .map((e) => ContactUser.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<ContactsApiOutcome<List<ContactUser>>> fetchMyContacts({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/contacts/list');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseListOutcome(response);
    } on Exception catch (e) {
      if (_isNetworkError(e)) return const ContactsApiOutcome.networkFailure();
      rethrow;
    }
  }

  ContactsApiOutcome<List<ContactUser>> _parseListOutcome(
    http.Response response,
  ) {
    final envelope = _tryParseEnvelope(response);
    if (envelope == null) {
      return ContactsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return ContactsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }

    final data = envelope['data'];
    if (data is! Map) {
      return ContactsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    final contacts = data['contacts'];
    if (contacts is! List) {
      return ContactsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }

    return ContactsApiOutcome.success(
      contacts
          .whereType<Map>()
          .map((e) => ContactUser.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<ContactsApiOutcome<bool>> addContact({
    required String accessToken,
    required String contactUserId,
  }) async {
    final uri = Uri.parse('$_baseUrl/authuser/contacts/add');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'contact_user_id': contactUserId}),
      );
      return _parseBoolOutcome(response, okKey: 'ok');
    } on Exception catch (e) {
      if (_isNetworkError(e)) return const ContactsApiOutcome.networkFailure();
      rethrow;
    }
  }

  Future<ContactsApiOutcome<bool>> removeContact({
    required String accessToken,
    required String contactUserId,
  }) async {
    final encoded = Uri.encodeQueryComponent(contactUserId);
    final uri =
        Uri.parse('$_baseUrl/authuser/contacts/remove?contact_user_id=$encoded');
    try {
      final response = await _client.delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return _parseBoolOutcome(response, okKey: 'ok');
    } on Exception catch (e) {
      if (_isNetworkError(e)) return const ContactsApiOutcome.networkFailure();
      rethrow;
    }
  }

  ContactsApiOutcome<bool> _parseBoolOutcome(
    http.Response response, {
    required String okKey,
  }) {
    final envelope = _tryParseEnvelope(response);
    if (envelope == null) {
      return ContactsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    if (envelope['ok'] != true) {
      return ContactsApiOutcome.failure(
        error: ApiError.fromEnvelope(envelope),
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      return ContactsApiOutcome.failure(
        error: ApiError(
          code: CoreApiErrorCode.internalError,
          message: 'Invalid server response',
          rawCode: 'internal_error',
        ),
      );
    }
    return ContactsApiOutcome.success(data[okKey] == true);
  }

  Map<String, dynamic>? _tryParseEnvelope(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;
}

