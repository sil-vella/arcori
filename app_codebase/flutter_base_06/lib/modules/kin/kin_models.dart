/// Client-side Kin creation catalogs and save drafts.
library;

/// Catalog serial for [KinCustomType.embedImage].
const String kKinEmbedImageSerial = 'CUS-0006';

/// Catalog serial for [KinCustomType.embedHue] (tints selected addition).
const String kKinEmbedHueSerial = 'CUS-0009';

/// Catalog serial for [KinCustomType.embedLightDark] (tints selected addition).
const String kKinEmbedLightDarkSerial = 'CUS-0010';

enum KinCustomType {
  hue,
  saturation,
  lightDark,
  color,
  embedImage,
  embedHue,
  embedLightDark,
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
    if (customType == KinCustomType.lightDark ||
        customType == KinCustomType.embedLightDark) {
      return -1.0;
    }
    return -180.0;
  }

  double get max {
    final v = params['max'];
    if (v is num) return v.toDouble();
    if (customType == KinCustomType.saturation) return 2.0;
    if (customType == KinCustomType.lightDark ||
        customType == KinCustomType.embedLightDark) {
      return 1.0;
    }
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
    this.assetPath = '',
    this.imageUrl,
  });

  factory KinEmbed.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['imageUrl']?.toString();
    return KinEmbed(
      serial: json['serial']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      assetPath: json['assetPath']?.toString() ?? '',
      imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
    );
  }

  final String serial;
  final String displayName;

  /// Bundled Flutter asset (offline / legacy fallback).
  final String assetPath;

  /// Hot catalog path from API (`/catalog-media/kin/...`); preferred when set.
  final String? imageUrl;

  /// Source used for bake / preview load (network URL path or asset path).
  String get bakeSource {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) return url;
    return assetPath;
  }

  bool get hasArt => bakeSource.isNotEmpty;

  KinEmbed copyWith({
    String? serial,
    String? displayName,
    String? assetPath,
    String? imageUrl,
    bool clearImageUrl = false,
  }) {
    return KinEmbed(
      serial: serial ?? this.serial,
      displayName: displayName ?? this.displayName,
      assetPath: assetPath ?? this.assetPath,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
    );
  }
}

/// Whether an embed sits above or below its target Lottie layer (list order).
enum KinEmbedSide {
  /// Lower list index than target → drawn in front.
  inFront,

  /// Higher list index than target → drawn behind.
  behind,
}

/// Per-part placement for an embed addition relative to a Lottie layer `nm`.
class KinEmbedPlacement {
  const KinEmbedPlacement({
    required this.targetLayer,
    required this.side,
    this.p,
    this.s,
  });

  factory KinEmbedPlacement.fromJson(Map<String, dynamic> json) {
    final inFrontRaw = json['inFrontOf']?.toString();
    final behindRaw = json['behindLayer']?.toString();
    final hasInFront = inFrontRaw != null && inFrontRaw.isNotEmpty;
    final hasBehind = behindRaw != null && behindRaw.isNotEmpty;
    // Exactly one of inFrontOf / behindLayer.
    if (hasInFront == hasBehind) {
      return const KinEmbedPlacement(
        targetLayer: '',
        side: KinEmbedSide.inFront,
      );
    }
    return KinEmbedPlacement(
      targetLayer: hasInFront ? inFrontRaw : behindRaw!,
      side: hasInFront ? KinEmbedSide.inFront : KinEmbedSide.behind,
      p: _numList3(json['p'], padThird: 0),
      s: _numList3(json['s'], padThird: 100),
    );
  }

  /// Lottie layer `nm` the embed is placed relative to.
  final String targetLayer;

  final KinEmbedSide side;

  /// Optional position `[x, y, z]`; bake defaults to composition center.
  final List<double>? p;

  /// Optional scale percent `[sx, sy, sz]`; bake defaults to `[100, 100, 100]`.
  final List<double>? s;

  bool get isValid => targetLayer.isNotEmpty;

  Map<String, dynamic> toJson() => {
        if (side == KinEmbedSide.inFront) 'inFrontOf': targetLayer,
        if (side == KinEmbedSide.behind) 'behindLayer': targetLayer,
        if (p != null) 'p': p,
        if (s != null) 's': s,
      };
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
    this.embedPlacements = const {},
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
      embedPlacements: _embedPlacements(json['embedPlacements']),
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

  /// Per-embed insert placement (`inFrontOf` or `behindLayer`, optional `p` / `s`).
  final Map<String, KinEmbedPlacement> embedPlacements;

  /// Lottie layer names this part styles.
  List<String> get styleLayerNames {
    if (affectsLayers.isNotEmpty) return affectsLayers;
    if (layerName.isEmpty) return const [];
    return [layerName];
  }

  bool allowsCustom(String customSerial) {
    if (allowedCustomSerials.contains(customSerial)) return true;
    // Addition tint companions auto-allowed wherever embedImage is allowed.
    if ((customSerial == kKinEmbedHueSerial ||
            customSerial == kKinEmbedLightDarkSerial) &&
        allowedCustomSerials.contains(kKinEmbedImageSerial)) {
      return true;
    }
    return false;
  }

  bool allowsEmbed(String embedSerial) =>
      embedPoolSerials.contains(embedSerial);

  KinEmbedPlacement? placementFor(String embedSerial) {
    final p = embedPlacements[embedSerial];
    if (p == null || !p.isValid) return null;
    return p;
  }

  KinPart copyWith({
    String? serial,
    String? layerName,
    String? displayName,
    String? anatomical,
    List<String>? affectsLayers,
    List<String>? allowedCustomSerials,
    List<String>? embedPoolSerials,
    Map<String, KinEmbedPlacement>? embedPlacements,
  }) {
    return KinPart(
      serial: serial ?? this.serial,
      layerName: layerName ?? this.layerName,
      displayName: displayName ?? this.displayName,
      anatomical: anatomical ?? this.anatomical,
      affectsLayers: affectsLayers ?? this.affectsLayers,
      allowedCustomSerials:
          allowedCustomSerials ?? this.allowedCustomSerials,
      embedPoolSerials: embedPoolSerials ?? this.embedPoolSerials,
      embedPlacements: embedPlacements ?? this.embedPlacements,
    );
  }
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

  /// Backend-served Lottie path, e.g. `/catalog-media/kin/ser001/guardians/KIN-BRZ-SER001-0001.json`.
  final String? lottieUrl;
  final String? thumbnailUrl;
  final List<KinPart> parts;

  KinPart? partBySerial(String serial) {
    for (final p in parts) {
      if (p.serial == serial) return p;
    }
    return null;
  }

  KinTemplate copyWith({
    String? serial,
    String? typeSerial,
    String? displayName,
    String? lottieUrl,
    String? thumbnailUrl,
    List<KinPart>? parts,
  }) {
    return KinTemplate(
      serial: serial ?? this.serial,
      typeSerial: typeSerial ?? this.typeSerial,
      displayName: displayName ?? this.displayName,
      lottieUrl: lottieUrl ?? this.lottieUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      parts: parts ?? this.parts,
    );
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

  KinCreationCatalog copyWith({
    List<KinCustomTypeDef>? customTypes,
    List<KinCustom>? customs,
    List<KinEmbed>? embeds,
    List<KinType>? types,
    List<KinTemplate>? kins,
  }) {
    return KinCreationCatalog(
      customTypes: customTypes ?? this.customTypes,
      customs: customs ?? this.customs,
      embeds: embeds ?? this.embeds,
      types: types ?? this.types,
      kins: kins ?? this.kins,
    );
  }

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
  ///
  /// Addition hue / light-dark are not listed here — they live on each
  /// selected embed inside the embedImage value map (see Additions UI).
  List<KinCustom> allowedCustomsFor(KinPart part) {
    final out = <KinCustom>[];
    final seen = <String>{};
    for (final serial in part.allowedCustomSerials) {
      // Hide embedImage from per-part list; dedicated Additions section owns it.
      if (serial == kKinEmbedImageSerial) continue;
      if (serial == kKinEmbedHueSerial || serial == kKinEmbedLightDarkSerial) {
        continue;
      }
      final c = customBySerial(serial);
      if (c == null) continue;
      if (!seen.add(c.serial)) continue;
      out.add(c);
    }
    return out;
  }

  List<KinEmbed> embedsFor(KinPart part) {
    final out = <KinEmbed>[];
    for (final serial in part.embedPoolSerials) {
      if (part.placementFor(serial) == null) continue;
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
    this.background,
    this.backgroundFilterMode,
  });

  factory KinSaveDraft.fromJson(Map<String, dynamic> json) {
    final rawApplied = json['applied'];
    final rawBg = json['background'];
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
      background: rawBg is Map
          ? Map<String, dynamic>.from(rawBg)
          : null,
      backgroundFilterMode: _nullableString(json['backgroundFilterMode']),
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

  /// Claim-shaped background snapshot for restore (solid / gradient / image).
  final Map<String, dynamic>? background;

  /// Customize UI filter mode: `theme` or `style`.
  final String? backgroundFilterMode;

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
        if (background != null) 'background': background,
        if (backgroundFilterMode != null)
          'backgroundFilterMode': backgroundFilterMode,
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

List<double>? _numList3(Object? raw, {required double padThird}) {
  if (raw is! List || raw.length < 2) return null;
  final out = <double>[];
  for (var i = 0; i < raw.length && i < 3; i++) {
    final v = raw[i];
    if (v is! num) return null;
    out.add(v.toDouble());
  }
  while (out.length < 3) {
    out.add(out.length == 2 ? padThird : 0.0);
  }
  return out;
}

Map<String, KinEmbedPlacement> _embedPlacements(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, KinEmbedPlacement>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString();
    if (key.isEmpty) continue;
    final value = entry.value;
    if (value is! Map) continue;
    final placement =
        KinEmbedPlacement.fromJson(Map<String, dynamic>.from(value));
    if (!placement.isValid) continue;
    out[key] = placement;
  }
  return out;
}
