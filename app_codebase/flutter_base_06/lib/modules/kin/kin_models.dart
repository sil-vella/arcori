/// Client-side Kin creation catalogs and save drafts.
library;

enum KinCustomType {
  hue,
  saturation,
  lightDark,
  color,
  embedImage,
  swapPart;

  static KinCustomType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in KinCustomType.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

class KinCustomTypeDef {
  const KinCustomTypeDef({
    required this.code,
    required this.displayName,
    required this.valueShape,
    this.defaultRange,
  });

  factory KinCustomTypeDef.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? range;
    final raw = json['defaultRange'];
    if (raw is Map<String, dynamic>) {
      range = raw;
    }
    return KinCustomTypeDef(
      code: json['code']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      valueShape: json['valueShape']?.toString() ?? '',
      defaultRange: range,
    );
  }

  final String code;
  final String displayName;
  final String valueShape;
  final Map<String, dynamic>? defaultRange;
}

class KinCustom {
  const KinCustom({
    required this.serial,
    required this.customType,
    required this.displayName,
    this.params = const {},
  });

  factory KinCustom.fromJson(Map<String, dynamic> json) {
    final type = KinCustomType.tryParse(json['customType']?.toString()) ??
        KinCustomType.hue;
    final rawParams = json['params'];
    return KinCustom(
      serial: json['serial']?.toString() ?? '',
      customType: type,
      displayName: json['displayName']?.toString() ?? '',
      params: rawParams is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawParams)
          : const {},
    );
  }

  final String serial;
  final KinCustomType customType;
  final String displayName;
  final Map<String, dynamic> params;

  double get defaultNumber {
    final v = params['default'];
    if (v is num) return v.toDouble();
    if (customType == KinCustomType.saturation) return 1.0;
    return 0.0;
  }

  double get min {
    final v = params['min'];
    if (v is num) return v.toDouble();
    if (customType == KinCustomType.saturation) return 0.0;
    if (customType == KinCustomType.lightDark) return -1.0;
    return -180.0;
  }

  double get max {
    final v = params['max'];
    if (v is num) return v.toDouble();
    if (customType == KinCustomType.saturation) return 2.0;
    if (customType == KinCustomType.lightDark) return 1.0;
    return 180.0;
  }

  List<String> get allowedColors {
    final raw = params['allowedColors'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  String? get defaultColor {
    final v = params['default']?.toString();
    if (v == null || v.isEmpty) return null;
    return v;
  }
}

class KinEmbed {
  const KinEmbed({
    required this.serial,
    required this.displayName,
    required this.assetPath,
  });

  factory KinEmbed.fromJson(Map<String, dynamic> json) {
    return KinEmbed(
      serial: json['serial']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      assetPath: json['assetPath']?.toString() ?? '',
    );
  }

  final String serial;
  final String displayName;
  final String assetPath;
}

class KinType {
  const KinType({
    required this.serial,
    required this.code,
    required this.displayName,
  });

  factory KinType.fromJson(Map<String, dynamic> json) {
    return KinType(
      serial: json['serial']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
    );
  }

  final String serial;
  final String code;
  final String displayName;
}

class KinPart {
  const KinPart({
    required this.serial,
    required this.layerName,
    required this.displayName,
    this.anatomical,
    this.affectsLayers = const [],
    this.allowedCustomSerials = const [],
    this.embedPoolSerials = const [],
  });

  factory KinPart.fromJson(Map<String, dynamic> json) {
    final anatomical = json['anatomical']?.toString();
    return KinPart(
      serial: json['serial']?.toString() ?? '',
      layerName: json['layerName']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      anatomical: (anatomical == null || anatomical.isEmpty) ? null : anatomical,
      affectsLayers: _stringList(json['affectsLayers']),
      allowedCustomSerials: _stringList(json['allowedCustomSerials']),
      embedPoolSerials: _stringList(json['embedPoolSerials']),
    );
  }

  final String serial;
  final String layerName;
  final String displayName;
  final String? anatomical;

  /// When set, styles from this part apply to these Lottie layer names.
  /// Empty → only [layerName] (single-layer parts).
  final List<String> affectsLayers;
  final List<String> allowedCustomSerials;
  final List<String> embedPoolSerials;

  /// Lottie layer names this part styles.
  List<String> get styleLayerNames {
    if (affectsLayers.isNotEmpty) return affectsLayers;
    if (layerName.isEmpty) return const [];
    return [layerName];
  }

  bool allowsCustom(String customSerial) =>
      allowedCustomSerials.contains(customSerial);

  bool allowsEmbed(String embedSerial) =>
      embedPoolSerials.contains(embedSerial);
}

class KinTemplate {
  const KinTemplate({
    required this.serial,
    required this.typeSerial,
    required this.displayName,
    this.lottieUrl,
    this.thumbnailUrl,
    this.parts = const [],
  });

  factory KinTemplate.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts'];
    // Prefer backend URL; accept legacy lottieAsset key during transition.
    final lottie = _nullableString(json['lottieUrl']) ??
        _nullableString(json['lottieAsset']);
    final thumb = _nullableString(json['thumbnailUrl']) ??
        _nullableString(json['thumbnailAsset']);
    return KinTemplate(
      serial: json['serial']?.toString() ?? '',
      typeSerial: json['typeSerial']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      lottieUrl: lottie,
      thumbnailUrl: thumb,
      parts: rawParts is List
          ? rawParts
              .whereType<Map>()
              .map((e) => KinPart.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  final String serial;
  final String typeSerial;
  final String displayName;

  /// Backend-served Lottie path, e.g. `/catalog-media/kin/gen001/guardians/KIN-BRZ-GEN001-0001.json`.
  final String? lottieUrl;
  final String? thumbnailUrl;
  final List<KinPart> parts;

  KinPart? partBySerial(String serial) {
    for (final p in parts) {
      if (p.serial == serial) return p;
    }
    return null;
  }
}

class KinCreationCatalog {
  const KinCreationCatalog({
    required this.customTypes,
    required this.customs,
    required this.embeds,
    required this.types,
    required this.kins,
  });

  final List<KinCustomTypeDef> customTypes;
  final List<KinCustom> customs;
  final List<KinEmbed> embeds;
  final List<KinType> types;
  final List<KinTemplate> kins;

  KinCustom? customBySerial(String serial) {
    for (final c in customs) {
      if (c.serial == serial) return c;
    }
    return null;
  }

  KinEmbed? embedBySerial(String serial) {
    for (final e in embeds) {
      if (e.serial == serial) return e;
    }
    return null;
  }

  KinType? typeBySerial(String serial) {
    for (final t in types) {
      if (t.serial == serial) return t;
    }
    return null;
  }

  KinTemplate? kinBySerial(String serial) {
    for (final k in kins) {
      if (k.serial == serial) return k;
    }
    return null;
  }

  List<KinTemplate> kinsForType(String typeSerial) =>
      kins.where((k) => k.typeSerial == typeSerial).toList();

  /// Returns allowed customs for [part], skipping unknown serials.
  List<KinCustom> allowedCustomsFor(KinPart part) {
    final out = <KinCustom>[];
    for (final serial in part.allowedCustomSerials) {
      final c = customBySerial(serial);
      if (c != null) out.add(c);
    }
    return out;
  }

  List<KinEmbed> embedsFor(KinPart part) {
    final out = <KinEmbed>[];
    for (final serial in part.embedPoolSerials) {
      final e = embedBySerial(serial);
      if (e != null) out.add(e);
    }
    return out;
  }
}

/// One applied custom on a part (saved in sidecar).
class KinAppliedCustom {
  const KinAppliedCustom({
    required this.partSerial,
    required this.customSerial,
    required this.value,
  });

  factory KinAppliedCustom.fromJson(Map<String, dynamic> json) {
    return KinAppliedCustom(
      partSerial: json['partSerial']?.toString() ?? '',
      customSerial: json['customSerial']?.toString() ?? '',
      value: json['value'],
    );
  }

  final String partSerial;
  final String customSerial;
  final Object? value;

  Map<String, dynamic> toJson() => {
        'partSerial': partSerial,
        'customSerial': customSerial,
        'value': value,
      };
}

/// Local saved Kin instance (sidecar index).
class KinSaveDraft {
  const KinSaveDraft({
    required this.serial,
    required this.kinSerial,
    required this.typeSerial,
    required this.displayName,
    required this.lottieRelativePath,
    required this.applied,
    required this.createdAtIso,
    this.regionCode,
    this.colorHex,
    this.chosenName,
    this.backgroundId,
  });

  factory KinSaveDraft.fromJson(Map<String, dynamic> json) {
    final rawApplied = json['applied'];
    return KinSaveDraft(
      serial: json['serial']?.toString() ?? '',
      kinSerial: json['kinSerial']?.toString() ?? '',
      typeSerial: json['typeSerial']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      lottieRelativePath: json['lottieRelativePath']?.toString() ?? '',
      applied: rawApplied is List
          ? rawApplied
              .whereType<Map>()
              .map((e) => KinAppliedCustom.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      createdAtIso: json['createdAtIso']?.toString() ?? '',
      regionCode: _nullableString(json['regionCode']),
      colorHex: _nullableString(json['colorHex']),
      chosenName: _nullableString(json['chosenName']),
      backgroundId: _nullableString(json['backgroundId']),
    );
  }

  final String serial;
  final String kinSerial;
  final String typeSerial;
  final String displayName;
  final String lottieRelativePath;
  final List<KinAppliedCustom> applied;
  final String createdAtIso;
  final String? regionCode;
  final String? colorHex;
  final String? chosenName;
  final String? backgroundId;

  Map<String, dynamic> toJson() => {
        'serial': serial,
        'kinSerial': kinSerial,
        'typeSerial': typeSerial,
        'displayName': displayName,
        'lottieRelativePath': lottieRelativePath,
        'applied': applied.map((e) => e.toJson()).toList(),
        'createdAtIso': createdAtIso,
        if (regionCode != null) 'regionCode': regionCode,
        if (colorHex != null) 'colorHex': colorHex,
        if (chosenName != null) 'chosenName': chosenName,
        if (backgroundId != null) 'backgroundId': backgroundId,
      };
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
}

String? _nullableString(Object? raw) {
  final s = raw?.toString();
  if (s == null || s.isEmpty || s == 'null') return null;
  return s;
}
