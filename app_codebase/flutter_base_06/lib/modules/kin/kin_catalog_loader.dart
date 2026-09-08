import 'dart:convert';

import 'package:flutter/services.dart';

import 'kin_models.dart';

/// Loads bundled Kin creation catalogs from `assets/kin/`.
class KinCatalogLoader {
  KinCatalogLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const typesAsset = 'assets/kin/types.json';
  static const kinsAsset = 'assets/kin/kins.json';
  static const customsAsset = 'assets/kin/customs.json';
  static const customTypesAsset = 'assets/kin/custom_types.json';
  static const embedsAsset = 'assets/kin/embeds.json';

  final AssetBundle _bundle;

  Future<KinCreationCatalog> load() async {
    final typesJson = await _decode(typesAsset);
    final kinsJson = await _decode(kinsAsset);
    final customsJson = await _decode(customsAsset);
    final customTypesJson = await _decode(customTypesAsset);
    final embedsJson = await _decode(embedsAsset);

    return KinCreationCatalog(
      customTypes: _mapList(customTypesJson['types'], KinCustomTypeDef.fromJson),
      customs: _mapList(customsJson['customs'], KinCustom.fromJson),
      embeds: _mapList(embedsJson['embeds'], KinEmbed.fromJson),
      types: _mapList(typesJson['types'], KinType.fromJson),
      kins: _mapList(kinsJson['kins'], KinTemplate.fromJson),
    );
  }

  Future<Map<String, dynamic>> _decode(String asset) async {
    final raw = await _bundle.loadString(asset);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  List<T> _mapList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
