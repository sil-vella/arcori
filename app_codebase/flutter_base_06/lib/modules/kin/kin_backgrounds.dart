/// Kin scene backgrounds: solid / gradient (client) + image catalog (server scan).
///
/// Image filename: `KIN_BG_{THEME}_{STYLE}_{NNN}.webp`
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/state/auth/auth_providers.dart';
import '../../core/ws/ws_config.dart';
import '../../utils/dev_logger.dart';
import '../match/widgets/arcori_palette.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const String kKinBackgroundMediaPrefix =
    '/catalog-media/kin/gen001/00backgrounds';

const String kKinDefaultBackgroundColorHex = '#2A2A2E';

const String kKinBgThemeSolid = 'SOLID';
const String kKinBgThemeGradient = 'GRADIENT';
const String kKinBgThemeAbstract = 'ABSTRACT';
const String kKinBgThemeScenery = 'SCENERY';

const double kKinBgSatDefault = 1.0;
const double kKinBgSatMin = 0.0;
const double kKinBgSatMax = 2.0;
const double kKinBgLightDarkDefault = 0.0;
const double kKinBgLightDarkMin = -1.0;
const double kKinBgLightDarkMax = 1.0;
const double kKinBgAngleDefault = 180.0;
const double kKinBgTextureIntensityDefault = 0.35;
const double kKinBgTextureIntensityMin = 0.0;
const double kKinBgTextureIntensityMax = 1.0;

const String kKinBgTextureNone = 'none';
const String kKinBgTextureGrain = 'grain';
const String kKinBgTextureNoise = 'noise';
const String kKinBgTextureLines = 'lines';
const String kKinBgTextureDots = 'dots';
const String kKinBgTextureWeave = 'weave';

const List<String> kKinBackgroundTextures = [
  kKinBgTextureNone,
  kKinBgTextureGrain,
  kKinBgTextureNoise,
  kKinBgTextureLines,
  kKinBgTextureDots,
  kKinBgTextureWeave,
];

String kinBackgroundTextureLabel(String textureId) {
  switch (textureId) {
    case kKinBgTextureNone:
      return 'None';
    case kKinBgTextureGrain:
      return 'Grain';
    case kKinBgTextureNoise:
      return 'Noise';
    case kKinBgTextureLines:
      return 'Lines';
    case kKinBgTextureDots:
      return 'Dots';
    case kKinBgTextureWeave:
      return 'Weave';
    default:
      return titleFromKinBgToken(textureId);
  }
}

class KinBackgroundOption {
  const KinBackgroundOption.color({
    required this.id,
    required this.displayName,
    required this.colorHex,
  })  : imageUrl = null,
        theme = kKinBgThemeSolid,
        styleToken = null,
        fileName = null;

  const KinBackgroundOption.image({
    required this.id,
    required this.displayName,
    required this.imageUrl,
    required this.theme,
    required this.styleToken,
    required this.fileName,
  }) : colorHex = null;

  final String id;
  final String displayName;
  final String? colorHex;
  final String? imageUrl;
  final String theme;
  final String? styleToken;
  final String? fileName;

  bool get isColor => colorHex != null && colorHex!.isNotEmpty;
  bool get isImage => imageUrl != null && imageUrl!.isNotEmpty;

  String get styleLabel =>
      styleToken == null ? '' : titleFromKinBgToken(styleToken!);

  factory KinBackgroundOption.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final fileName = (json['fileName'] ?? '').toString();
    final theme = (json['theme'] ?? '').toString().toUpperCase();
    final style = (json['style'] ?? '').toString().toUpperCase();
    final imageUrl = (json['imageUrl'] ?? '').toString();
    final displayName = (json['displayName'] ?? '').toString();
    return KinBackgroundOption.image(
      id: id.isNotEmpty
          ? id
          : (fileName.endsWith('.webp')
              ? fileName.substring(0, fileName.length - 5)
              : fileName),
      displayName: displayName.isNotEmpty
          ? displayName
          : '${titleFromKinBgToken(theme)} · ${titleFromKinBgToken(style)}',
      imageUrl: imageUrl.isNotEmpty
          ? imageUrl
          : (fileName.isEmpty
              ? ''
              : '$kKinBackgroundMediaPrefix/$fileName'),
      theme: theme,
      styleToken: style.isEmpty ? null : style,
      fileName: fileName.isEmpty ? null : fileName,
    );
  }
}

/// Resolved scene fill for preview / claim (solid, gradient, or image).
class KinBackgroundScene {
  const KinBackgroundScene.image({
    required this.id,
    required this.imageUrl,
    this.theme = kKinBgThemeAbstract,
    this.style,
    this.fileName,
  })  : colorHex = null,
        colorHexB = null,
        angleDegrees = null,
        saturation = kKinBgSatDefault,
        lightDark = kKinBgLightDarkDefault,
        textureId = kKinBgTextureNone,
        textureIntensity = 0;

  const KinBackgroundScene.solid({
    required this.id,
    required this.colorHex,
    this.saturation = kKinBgSatDefault,
    this.lightDark = kKinBgLightDarkDefault,
    this.textureId = kKinBgTextureNone,
    this.textureIntensity = kKinBgTextureIntensityDefault,
  })  : theme = kKinBgThemeSolid,
        imageUrl = null,
        colorHexB = null,
        angleDegrees = null,
        style = null,
        fileName = null;

  const KinBackgroundScene.gradient({
    required this.id,
    required this.colorHex,
    required this.colorHexB,
    this.angleDegrees = kKinBgAngleDefault,
    this.saturation = kKinBgSatDefault,
    this.lightDark = kKinBgLightDarkDefault,
    this.textureId = kKinBgTextureNone,
    this.textureIntensity = kKinBgTextureIntensityDefault,
  })  : theme = kKinBgThemeGradient,
        imageUrl = null,
        style = null,
        fileName = null;

  final String id;
  final String theme;
  final String? colorHex;
  final String? colorHexB;
  final double? angleDegrees;
  final double saturation;
  final double lightDark;
  final String textureId;
  final double textureIntensity;
  final String? imageUrl;
  final String? style;
  final String? fileName;

  bool get isImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isGradient =>
      theme == kKinBgThemeGradient &&
      colorHex != null &&
      colorHexB != null &&
      colorHex!.isNotEmpty &&
      colorHexB!.isNotEmpty;
  bool get isSolid =>
      theme == kKinBgThemeSolid && colorHex != null && colorHex!.isNotEmpty;
  bool get hasTexture =>
      (isSolid || isGradient) &&
      textureId != kKinBgTextureNone &&
      textureIntensity > 0.01;

  Color? get adjustedColorA {
    final c = parseCatalogColor(colorHex);
    if (c == null) return null;
    return adjustKinBackgroundColor(
      c,
      saturation: saturation,
      lightDark: lightDark,
    );
  }

  Color? get adjustedColorB {
    final c = parseCatalogColor(colorHexB);
    if (c == null) return null;
    return adjustKinBackgroundColor(
      c,
      saturation: saturation,
      lightDark: lightDark,
    );
  }

  Map<String, dynamic> toClaimJson() => {
        'id': id,
        'theme': theme,
        if (colorHex != null) 'colorHex': colorHex,
        if (colorHexB != null) 'colorHexB': colorHexB,
        if (angleDegrees != null) 'angleDegrees': angleDegrees,
        if (isSolid || isGradient) 'saturation': saturation,
        if (isSolid || isGradient) 'lightDark': lightDark,
        if (isSolid || isGradient) 'textureId': textureId,
        if (isSolid || isGradient) 'textureIntensity': textureIntensity,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (style != null) 'style': style,
        if (fileName != null) 'fileName': fileName,
      };

  factory KinBackgroundScene.fromClaimJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const KinBackgroundScene.solid(
        id: 'bg-default',
        colorHex: kKinDefaultBackgroundColorHex,
      );
    }
    final theme = (json['theme'] ?? '').toString().toUpperCase();
    final id = (json['id'] ?? 'bg').toString();
    final sat = _asDouble(json['saturation'], kKinBgSatDefault)
        .clamp(kKinBgSatMin, kKinBgSatMax);
    final light = _asDouble(json['lightDark'], kKinBgLightDarkDefault)
        .clamp(kKinBgLightDarkMin, kKinBgLightDarkMax);
    final texture = (json['textureId'] ?? kKinBgTextureNone).toString();
    final intensity = _asDouble(
      json['textureIntensity'],
      kKinBgTextureIntensityDefault,
    ).clamp(kKinBgTextureIntensityMin, kKinBgTextureIntensityMax);
    final imageUrl = json['imageUrl']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return KinBackgroundScene.image(
        id: id,
        imageUrl: imageUrl,
        theme: theme.isEmpty ? kKinBgThemeAbstract : theme,
        style: json['style']?.toString(),
        fileName: json['fileName']?.toString(),
      );
    }
    if (theme == kKinBgThemeGradient) {
      return KinBackgroundScene.gradient(
        id: id,
        colorHex: json['colorHex']?.toString() ?? kKinDefaultBackgroundColorHex,
        colorHexB:
            json['colorHexB']?.toString() ?? kArcoriAccentHexes.first,
        angleDegrees: _asDouble(json['angleDegrees'], kKinBgAngleDefault),
        saturation: sat,
        lightDark: light,
        textureId: texture,
        textureIntensity: intensity,
      );
    }
    return KinBackgroundScene.solid(
      id: id,
      colorHex: json['colorHex']?.toString() ?? kKinDefaultBackgroundColorHex,
      saturation: sat,
      lightDark: light,
      textureId: texture,
      textureIntensity: intensity,
    );
  }
}

double _asDouble(Object? raw, double fallback) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? fallback;
}

/// Saturation × [saturation], value += [lightDark] (same spirit as Kin customs).
Color adjustKinBackgroundColor(
  Color base, {
  required double saturation,
  required double lightDark,
}) {
  final hsv = HSVColor.fromColor(base);
  final sat = (hsv.saturation * saturation).clamp(0.0, 1.0);
  final value = (hsv.value + lightDark).clamp(0.0, 1.0);
  return hsv.withSaturation(sat).withValue(value).toColor();
}

/// Linear gradient direction for [angleDegrees] (0° = left→right, 90° = top→bottom).
(Alignment, Alignment) kinBackgroundGradientAlignments(double angleDegrees) {
  final rad = angleDegrees * math.pi / 180.0;
  final dx = math.cos(rad);
  final dy = math.sin(rad);
  return (Alignment(-dx, -dy), Alignment(dx, dy));
}

enum KinBackgroundFilterMode {
  theme,
  style,
}

class KinBackgroundCatalog {
  const KinBackgroundCatalog({
    required this.images,
    required this.themes,
    required this.stylesByTheme,
  });

  final List<KinBackgroundOption> images;
  final List<String> themes;
  final Map<String, List<String>> stylesByTheme;

  static const empty = KinBackgroundCatalog(
    images: [],
    themes: [],
    stylesByTheme: {},
  );

  List<KinBackgroundOption> get solids => _solidOptions();

  List<String> filterThemes() {
    final out = <String>[kKinBgThemeSolid, kKinBgThemeGradient];
    for (final t in themes) {
      final u = t.toUpperCase();
      if (u.isEmpty || out.contains(u)) continue;
      out.add(u);
    }
    out.sort((a, b) {
      int rank(String t) {
        if (t == kKinBgThemeSolid) return 0;
        if (t == kKinBgThemeGradient) return 1;
        if (t == kKinBgThemeAbstract) return 2;
        if (t == kKinBgThemeScenery) return 3;
        return 4;
      }

      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.compareTo(b);
    });
    return out;
  }

  List<String> allStyles() {
    final seen = <String>{};
    final out = <String>[];
    for (final styles in stylesByTheme.values) {
      for (final s in styles) {
        final u = s.toUpperCase();
        if (u.isEmpty || !seen.add(u)) continue;
        out.add(u);
      }
    }
    if (out.isEmpty) {
      for (final o in images) {
        final s = o.styleToken;
        if (s == null || s.isEmpty || !seen.add(s)) continue;
        out.add(s);
      }
    }
    out.sort();
    return out;
  }

  List<KinBackgroundOption> filtered({
    required KinBackgroundFilterMode mode,
    String? theme,
    String? styleToken,
  }) {
    if (mode == KinBackgroundFilterMode.theme) {
      final t = (theme ?? kKinBgThemeAbstract).toUpperCase();
      if (t == kKinBgThemeSolid || t == kKinBgThemeGradient) {
        return solids;
      }
      return images.where((o) => o.theme == t).toList();
    }
    final style = styleToken?.toUpperCase();
    if (style == null || style.isEmpty) return const [];
    return images.where((o) => o.styleToken == style).toList();
  }

  KinBackgroundOption? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final o in solids) {
      if (o.id == id) return o;
    }
    for (final o in images) {
      if (o.id == id) return o;
    }
    return null;
  }
}

String titleFromKinBgToken(String token) {
  return token
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
      .join(' ');
}

String kinBackgroundThemeLabel(String theme) {
  switch (theme.toUpperCase()) {
    case kKinBgThemeSolid:
      return 'Solid color';
    case kKinBgThemeGradient:
      return 'Gradient';
    case kKinBgThemeAbstract:
      return 'Abstract';
    case kKinBgThemeScenery:
      return 'Scenery';
    default:
      return titleFromKinBgToken(theme);
  }
}

List<KinBackgroundOption> _solidOptions() {
  return [
    const KinBackgroundOption.color(
      id: 'bg-default',
      displayName: 'Charcoal',
      colorHex: kKinDefaultBackgroundColorHex,
    ),
    for (var i = 0; i < kArcoriAccentHexes.length; i++)
      KinBackgroundOption.color(
        id: 'bg-accent-$i',
        displayName: kArcoriAccentNames[i],
        colorHex: kArcoriAccentHexes[i],
      ),
  ];
}

/// Live catalog from disk scan on the API (add files → appear without client rebuild).
final kinBackgroundCatalogProvider =
    FutureProvider<KinBackgroundCatalog>((ref) async {
  final token = ref.watch(authProvider).accessToken;
  final client = http.Client();
  try {
    final uri =
        Uri.parse('${WsConfig.apiRestBase}/authuser/avari/kin/backgrounds');
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (LOGGING_SWITCH) {
        customlog('KinBackgrounds: status=${response.statusCode}');
      }
      return KinBackgroundCatalog.empty;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['ok'] != true) {
      return KinBackgroundCatalog.empty;
    }
    final data = decoded['data'];
    if (data is! Map) return KinBackgroundCatalog.empty;

    final images = <KinBackgroundOption>[];
    final rawList = data['backgrounds'];
    if (rawList is List) {
      for (final raw in rawList) {
        if (raw is! Map) continue;
        final opt = KinBackgroundOption.fromApi(Map<String, dynamic>.from(raw));
        if (opt.id.isEmpty || !opt.isImage) continue;
        images.add(opt);
      }
    }
    images.sort((a, b) {
      final t = a.theme.compareTo(b.theme);
      if (t != 0) return t;
      return (a.styleToken ?? '').compareTo(b.styleToken ?? '');
    });

    final themes = <String>[];
    final rawThemes = data['themes'];
    if (rawThemes is List) {
      for (final t in rawThemes) {
        final u = t.toString().toUpperCase();
        if (u.isEmpty || themes.contains(u)) continue;
        themes.add(u);
      }
    }
    if (themes.isEmpty) {
      for (final o in images) {
        if (!themes.contains(o.theme)) themes.add(o.theme);
      }
    }

    final stylesByTheme = <String, List<String>>{};
    final rawStyles = data['stylesByTheme'];
    if (rawStyles is Map) {
      rawStyles.forEach((key, value) {
        final theme = key.toString().toUpperCase();
        if (theme.isEmpty || value is! List) return;
        final styles = <String>[];
        for (final s in value) {
          final u = s.toString().toUpperCase();
          if (u.isEmpty || styles.contains(u)) continue;
          styles.add(u);
        }
        styles.sort();
        stylesByTheme[theme] = styles;
      });
    }

    if (LOGGING_SWITCH) {
      customlog(
        'KinBackgrounds: loaded ${images.length} themes=${themes.length}',
      );
    }
    return KinBackgroundCatalog(
      images: images,
      themes: themes,
      stylesByTheme: stylesByTheme,
    );
  } on SocketException {
    return KinBackgroundCatalog.empty;
  } on http.ClientException {
    return KinBackgroundCatalog.empty;
  } on TimeoutException {
    return KinBackgroundCatalog.empty;
  } catch (e) {
    if (LOGGING_SWITCH) {
      customlog('KinBackgrounds: fail $e');
    }
    return KinBackgroundCatalog.empty;
  } finally {
    client.close();
  }
});
