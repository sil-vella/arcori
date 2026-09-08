import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/state/auth/auth_providers.dart';
import '../../core/ws/ws_config.dart';
import '../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Realm Beyond — excluded from Kin assignment.
const String kKinExcludedRegionCode = 'RBY';

class KinRegionOption {
  const KinRegionOption({
    required this.regionCode,
    required this.name,
  });

  final String regionCode;
  final String name;
}

/// Velora lands eligible for Kin assignment (catalog regions minus RBY).
final kinAssignableRegionsProvider =
    FutureProvider<List<KinRegionOption>>((ref) async {
  final token = ref.watch(authProvider).accessToken;
  final client = http.Client();
  try {
    final uri = Uri.parse('${WsConfig.apiRestBase}/authuser/catalog/meta');
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (LOGGING_SWITCH) {
        customlog('KinRegions: meta status=${response.statusCode}');
      }
      return _fallbackRegions();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['ok'] != true) {
      return _fallbackRegions();
    }
    final data = decoded['data'];
    if (data is! Map) return _fallbackRegions();
    final regionsRoot = data['regions'];
    if (regionsRoot is! Map) return _fallbackRegions();
    final list = regionsRoot['regions'];
    if (list is! List) return _fallbackRegions();
    final out = <KinRegionOption>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final code = raw['regionCode']?.toString() ?? '';
      if (code.isEmpty || code == kKinExcludedRegionCode) continue;
      final name = raw['name']?.toString() ?? code;
      out.add(KinRegionOption(regionCode: code, name: name));
    }
    if (out.isEmpty) return _fallbackRegions();
    if (LOGGING_SWITCH) {
      customlog('KinRegions: loaded ${out.length}');
    }
    return out;
  } on SocketException {
    return _fallbackRegions();
  } on http.ClientException {
    return _fallbackRegions();
  } on TimeoutException {
    return _fallbackRegions();
  } catch (e) {
    if (LOGGING_SWITCH) {
      customlog('KinRegions: fail $e');
    }
    return _fallbackRegions();
  } finally {
    client.close();
  }
});

List<KinRegionOption> _fallbackRegions() => const [
      KinRegionOption(regionCode: 'ASH', name: 'Ashdrift Hill'),
      KinRegionOption(regionCode: 'EVG', name: 'Everlight Grove'),
      KinRegionOption(regionCode: 'LFR', name: 'Little Frost'),
      KinRegionOption(regionCode: 'MWB', name: 'Moonwake Bay'),
      KinRegionOption(regionCode: 'AMB', name: 'Amberwild'),
    ];
