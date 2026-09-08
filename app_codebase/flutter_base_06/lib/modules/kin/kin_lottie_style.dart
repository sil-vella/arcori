import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';

import 'kin_models.dart';

/// Per-layer style resolved from applied customs (for live preview + bake).
class KinLayerStyle {
  const KinLayerStyle({
    this.hueDegrees = 0,
    this.saturation = 1,
    this.lightDark = 0,
    this.replaceColor,
    this.embedSerial,
  });

  final double hueDegrees;
  final double saturation;
  /// Offset on HSV value (−1…1); positive = lighter.
  final double lightDark;
  final Color? replaceColor;
  final String? embedSerial;

  bool get hasColorEffect =>
      replaceColor != null ||
      hueDegrees.abs() > 0.01 ||
      (saturation - 1).abs() > 0.01 ||
      lightDark.abs() > 0.01 ||
      (embedSerial != null && embedSerial!.isNotEmpty);

  Color transform(Color base) {
    // Must match [toColorFilter] so baked Lottie == live preview.
    if (replaceColor != null) {
      // BlendMode.modulate: keep shading, tint toward replace color.
      return Color.fromARGB(
        (base.a * 255.0).round().clamp(0, 255),
        (base.r * replaceColor!.r * 255.0).round().clamp(0, 255),
        (base.g * replaceColor!.g * 255.0).round().clamp(0, 255),
        (base.b * replaceColor!.b * 255.0).round().clamp(0, 255),
      );
    }
    final matrix = _effectMatrix();
    return _applyColorMatrix(base, matrix);
  }

  /// Live preview filter for **image** layers (Kin templates are mostly ty=2).
  ColorFilter toColorFilter() {
    if (replaceColor != null) {
      return ColorFilter.mode(replaceColor!, BlendMode.modulate);
    }
    return ColorFilter.matrix(_effectMatrix());
  }

  List<double> _effectMatrix() {
    return _hueSatValueMatrix(
      hueDegrees: hueDegrees +
          (embedSerial != null && embedSerial!.isNotEmpty ? 40.0 : 0.0),
      saturation: saturation *
          (embedSerial != null && embedSerial!.isNotEmpty ? 1.15 : 1.0),
      valueOffset: lightDark,
    );
  }
}

/// Resolve styles keyed by Lottie [KinPart.styleLayerNames].
Map<String, KinLayerStyle> resolveLayerStyles({
  required KinTemplate template,
  required KinCreationCatalog catalog,
  required List<KinAppliedCustom> applied,
}) {
  final byPart = <String, Map<String, Object?>>{};
  for (final a in applied) {
    byPart.putIfAbsent(a.partSerial, () => {})[a.customSerial] = a.value;
  }

  final out = <String, KinLayerStyle>{};
  for (final part in template.parts) {
    final values = byPart[part.serial];
    if (values == null || values.isEmpty) continue;

    var hue = 0.0;
    var sat = 1.0;
    var lightDark = 0.0;
    Color? replace;
    String? embed;

    for (final entry in values.entries) {
      if (!part.allowsCustom(entry.key)) continue;
      final custom = catalog.customBySerial(entry.key);
      if (custom == null) continue;
      switch (custom.customType) {
        case KinCustomType.hue:
          if (entry.value is num) hue = (entry.value as num).toDouble();
          break;
        case KinCustomType.saturation:
          if (entry.value is num) sat = (entry.value as num).toDouble();
          break;
        case KinCustomType.lightDark:
          if (entry.value is num) lightDark = (entry.value as num).toDouble();
          break;
        case KinCustomType.color:
          final hex = entry.value?.toString();
          if (hex != null && hex.isNotEmpty) {
            replace = _parseHex(hex);
          }
          break;
        case KinCustomType.embedImage:
        case KinCustomType.swapPart:
          final s = entry.value?.toString();
          if (s != null && s.isNotEmpty && part.allowsEmbed(s)) {
            embed = s;
          }
          break;
      }
    }

    final style = KinLayerStyle(
      hueDegrees: hue,
      saturation: sat,
      lightDark: lightDark,
      replaceColor: replace,
      embedSerial: embed,
    );
    if (!style.hasColorEffect) continue;
    for (final layer in part.styleLayerNames) {
      out[layer] = style;
    }
  }
  return out;
}

LottieDelegates? buildKinLottieDelegates(Map<String, KinLayerStyle> styles) {
  if (styles.isEmpty) return null;
  final values = <ValueDelegate>[];
  for (final entry in styles.entries) {
    final layer = entry.key;
    final style = entry.value;
    final filter = style.toColorFilter();
    // Image layers (ty=2) — Kin templates.
    values.add(ValueDelegate.colorFilter([layer], value: filter));
    values.add(ValueDelegate.colorFilter([layer, '**'], value: filter));
    // Shape fills (ty=4) — some walkie overlays.
    values.add(
      ValueDelegate.color(
        [layer, '**'],
        callback: (frame) {
          final base = frame.endValue ?? frame.startValue ?? Colors.grey;
          return style.transform(base);
        },
      ),
    );
  }
  return LottieDelegates(values: values);
}

/// Bake fill colors + embedded PNG assets so the saved file shows customs offline.
String bakeKinLottieJson(
  String rawJson,
  Map<String, KinLayerStyle> styles,
) {
  if (styles.isEmpty) return rawJson;
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map) return rawJson;
  final root = Map<String, dynamic>.from(decoded);

  final assetsRaw = root['assets'];
  final assetsById = <String, Map<String, dynamic>>{};
  if (assetsRaw is List) {
    for (var i = 0; i < assetsRaw.length; i++) {
      final a = assetsRaw[i];
      if (a is! Map) continue;
      final map = Map<String, dynamic>.from(a);
      final id = map['id']?.toString() ?? '';
      if (id.isNotEmpty) assetsById[id] = map;
      assetsRaw[i] = map;
    }
  }

  final assetStyles = <String, KinLayerStyle>{};
  final layers = root['layers'];
  if (layers is List) {
    _collectAssetStyles(
      layers,
      styles: styles,
      assetsById: assetsById,
      out: assetStyles,
    );
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (layer is! Map) continue;
      final name = layer['nm']?.toString() ?? '';
      final style = styles[name];
      if (style == null) continue;
      final shapes = layer['shapes'];
      if (shapes is List) {
        _bakeShapes(shapes, style);
      }
    }
  }

  for (final entry in assetStyles.entries) {
    final asset = assetsById[entry.key];
    if (asset == null) continue;
    final baked = _bakeEmbeddedPng(asset['p']?.toString(), entry.value);
    if (baked != null) {
      asset['p'] = baked;
      asset['e'] = 1;
    }
  }

  return const JsonEncoder.withIndent('  ').convert(root);
}

void _collectAssetStyles(
  List<dynamic> layers, {
  required Map<String, KinLayerStyle> styles,
  required Map<String, Map<String, dynamic>> assetsById,
  required Map<String, KinLayerStyle> out,
}) {
  for (final layer in layers) {
    if (layer is! Map) continue;
    final name = layer['nm']?.toString() ?? '';
    final style = styles[name];
    final ty = layer['ty'];
    final refId = layer['refId']?.toString() ?? '';
    if (style != null && refId.isNotEmpty) {
      if (ty == 2) {
        out[refId] = style;
      } else if (ty == 0) {
        final precomp = assetsById[refId];
        final nested = precomp?['layers'];
        if (nested is List) {
          for (final sub in nested) {
            if (sub is! Map) continue;
            if (sub['ty'] != 2) continue;
            final subRef = sub['refId']?.toString() ?? '';
            if (subRef.isEmpty) continue;
            // Prefer styles keyed by sublayer name; else inherit precomp style.
            final subName = sub['nm']?.toString() ?? '';
            out[subRef] = styles[subName] ?? style;
          }
        }
      }
    }
    // Nested names inside precomps (style key is sublayer, not parent).
    if (ty == 0 && refId.isNotEmpty) {
      final precomp = assetsById[refId];
      final nested = precomp?['layers'];
      if (nested is List) {
        _collectAssetStyles(
          nested,
          styles: styles,
          assetsById: assetsById,
          out: out,
        );
      }
    }
  }
}

String? _bakeEmbeddedPng(String? dataUrl, KinLayerStyle style) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  const prefix = 'data:image/png;base64,';
  if (!dataUrl.startsWith(prefix)) return null;
  try {
    final bytes = base64Decode(dataUrl.substring(prefix.length));
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final out = img.Image.from(decoded);
    for (final p in out) {
      if (p.a == 0) continue;
      final base = Color.fromARGB(
        p.a.toInt(),
        p.r.toInt(),
        p.g.toInt(),
        p.b.toInt(),
      );
      final tinted = style.transform(base);
      p
        ..r = (tinted.r * 255.0).round().clamp(0, 255)
        ..g = (tinted.g * 255.0).round().clamp(0, 255)
        ..b = (tinted.b * 255.0).round().clamp(0, 255)
        ..a = (tinted.a * 255.0).round().clamp(0, 255);
    }
    final encoded = img.encodePng(out);
    return '$prefix${base64Encode(encoded)}';
  } catch (_) {
    return null;
  }
}

void _bakeShapes(List<dynamic> shapes, KinLayerStyle style) {
  for (var i = 0; i < shapes.length; i++) {
    final shape = shapes[i];
    if (shape is! Map) continue;
    final map = Map<String, dynamic>.from(shape);
    final ty = map['ty']?.toString();
    if (ty == 'fl' || ty == 'st') {
      final c = map['c'];
      if (c is Map) {
        final ck = c['k'];
        if (ck is List && ck.length >= 3 && ck.every((e) => e is num)) {
          final base = Color.fromARGB(
            ((ck.length > 3 ? (ck[3] as num) : 1.0) * 255).round().clamp(0, 255),
            ((ck[0] as num) * 255).round().clamp(0, 255),
            ((ck[1] as num) * 255).round().clamp(0, 255),
            ((ck[2] as num) * 255).round().clamp(0, 255),
          );
          final out = style.transform(base);
          map['c'] = {
            ...Map<String, dynamic>.from(c),
            'a': 0,
            'k': [
              out.r,
              out.g,
              out.b,
              out.a,
            ],
          };
        }
      }
    }
    final nested = map['it'];
    if (nested is List) {
      final copy = List<dynamic>.from(nested);
      _bakeShapes(copy, style);
      map['it'] = copy;
    }
    shapes[i] = map;
  }
}

/// 5×4 color matrix: hue rotate + sat scale + value offset (approx).
List<double> _hueSatValueMatrix({
  required double hueDegrees,
  required double saturation,
  required double valueOffset,
}) {
  // Luminance weights (Rec. 709).
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;

  final sat = saturation.clamp(0.0, 3.0);
  final sr = (1 - sat) * lr;
  final sg = (1 - sat) * lg;
  final sb = (1 - sat) * lb;

  // Saturation matrix.
  final m = <double>[
    sr + sat, sg, sb, 0, 0,
    sr, sg + sat, sb, 0, 0,
    sr, sg, sb + sat, 0, 0,
    0, 0, 0, 1, 0,
  ];

  final hue = hueDegrees * math.pi / 180.0;
  final cosH = math.cos(hue);
  final sinH = math.sin(hue);
  // Hue rotation around luminance axis.
  final hr = <double>[
    lr + cosH * (1 - lr) + sinH * (-lr),
    lg + cosH * (-lg) + sinH * (-lg),
    lb + cosH * (-lb) + sinH * (1 - lb),
    0,
    0,
    lr + cosH * (-lr) + sinH * 0.143,
    lg + cosH * (1 - lg) + sinH * 0.140,
    lb + cosH * (-lb) + sinH * (-0.283),
    0,
    0,
    lr + cosH * (-lr) + sinH * (-(1 - lr)),
    lg + cosH * (-lg) + sinH * lg,
    lb + cosH * (1 - lb) + sinH * lb,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  final combined = _mulColorMatrix(hr, m);
  final v = valueOffset.clamp(-1.0, 1.0) * 255.0;
  combined[4] += v;
  combined[9] += v;
  combined[14] += v;
  return combined;
}

List<double> _mulColorMatrix(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      out[row * 5 + col] = a[row * 5 + 0] * b[0 * 5 + col] +
          a[row * 5 + 1] * b[1 * 5 + col] +
          a[row * 5 + 2] * b[2 * 5 + col] +
          a[row * 5 + 3] * b[3 * 5 + col] +
          (col == 4 ? a[row * 5 + 4] : 0);
    }
  }
  return out;
}

/// Apply Flutter [ColorFilter.matrix] math (RGB in 0–255, alpha passthrough).
Color _applyColorMatrix(Color base, List<double> m) {
  final r = base.r * 255.0;
  final g = base.g * 255.0;
  final b = base.b * 255.0;
  final a = base.a * 255.0;
  final nr = m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4];
  final ng = m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9];
  final nb = m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14];
  final na = m[15] * r + m[16] * g + m[17] * b + m[18] * a + m[19];
  return Color.fromARGB(
    na.round().clamp(0, 255),
    nr.round().clamp(0, 255),
    ng.round().clamp(0, 255),
    nb.round().clamp(0, 255),
  );
}

Color? _parseHex(String raw) {
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(v);
}
