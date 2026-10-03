import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../core/http/media_url.dart';
import '../../utils/dev_logger.dart';
import 'kin_backgrounds.dart';
import 'kin_lottie_optimize.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const String kKinLottieBackgroundAssetId = 'asset_background';
const String kKinLottieBackgroundLayerName = 'background';
const String kKinLottieMetallicPlateLayerName = 'metallic_plate';
const String kKinLottieMetallicPlateAssetId = 'asset_metallic_plate';

/// Fallback fill when an image background cannot be loaded/decoded.
const Color kKinBackgroundBakeFallback = Color(0xFF2A2A2E);

/// Bake [scene] into Lottie JSON as the bottom ``background`` image layer.
///
/// Existing template ``background`` layers (Entelair copper plate) are renamed
/// to [kKinLottieMetallicPlateLayerName] so the claim scene sits **behind** the
/// plate (plate is face/character art, not a replaceable BG).
///
/// [expandToSquare]: when true (default), pad tall Entelair comps so disc
/// faces keep the full character under [BoxFit.cover] (claim + draft).
/// Live customize preview uses a separate scene stack + [BoxFit.contain]
/// and does not need this pad.
///
/// Background rasters are capped at [kKinBgBakeMaxEdge] for **all** templates
/// (ASP/ALC/HGD/…); layer scale fills the (possibly larger) composition.
Future<String> bakeKinBackgroundIntoLottie(
  String rawJson,
  KinBackgroundScene scene, {
  http.Client? httpClient,
  bool expandToSquare = true,
}) async {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map) return rawJson;
  final root = Map<String, dynamic>.from(decoded);

  final assetsRaw = root['assets'];
  final assets = <Map<String, dynamic>>[];
  if (assetsRaw is List) {
    for (final a in assetsRaw) {
      if (a is Map) assets.add(Map<String, dynamic>.from(a));
    }
  }
  root['assets'] = assets;

  final layersRaw = root['layers'];
  final layers = <Map<String, dynamic>>[];
  if (layersRaw is List) {
    for (final L in layersRaw) {
      if (L is Map) layers.add(Map<String, dynamic>.from(L));
    }
  }
  root['layers'] = layers;

  _promoteExistingBackgroundToMetallic(layers, assets);
  final size = expandToSquare
      ? _expandToSquareCanvas(root, layers)
      : (
          (root['w'] is num) ? (root['w'] as num).toInt() : 512,
          (root['h'] is num) ? (root['h'] as num).toInt() : 512,
        );
  final w = size.$1;
  final h = size.$2;
  final bake = kinBgBakeRasterSize(w, h);

  final pngBytes = await _rasterizeKinBackgroundScene(
    scene,
    w: bake.bakeW,
    h: bake.bakeH,
    httpClient: httpClient,
  );
  if (pngBytes == null || pngBytes.isEmpty) {
    return const JsonEncoder.withIndent('  ').convert(root);
  }
  final dataUrl = 'data:image/png;base64,${base64Encode(pngBytes)}';
  _upsertBackgroundAsset(
    assets,
    dataUrl: dataUrl,
    w: bake.bakeW,
    h: bake.bakeH,
  );
  _upsertBackgroundLayer(layers, scalePct: bake.scalePct);

  return const JsonEncoder.withIndent('  ').convert(root);
}

/// Cap BG raster to [kKinBgBakeMaxEdge]; return layer scale % to cover [w]x[h].
@visibleForTesting
({int bakeW, int bakeH, double scalePct}) kinBgBakeRasterSize(int w, int h) {
  final ww = w < 1 ? 1 : w;
  final hh = h < 1 ? 1 : h;
  final edge = ww > hh ? ww : hh;
  if (edge <= kKinBgBakeMaxEdge) {
    return (bakeW: ww, bakeH: hh, scalePct: 100.0);
  }
  final s = kKinBgBakeMaxEdge / edge;
  return (
    bakeW: math.max(1, (ww * s).round()),
    bakeH: math.max(1, (hh * s).round()),
    scalePct: 100.0 / s,
  );
}

/// Pad non-square comps so claim BG fills circular disc faces under BoxFit.contain.
(int, int) _expandToSquareCanvas(
  Map<String, dynamic> root,
  List<Map<String, dynamic>> layers,
) {
  var w = (root['w'] is num) ? (root['w'] as num).toInt() : 512;
  var h = (root['h'] is num) ? (root['h'] as num).toInt() : 512;
  if (w < 1) w = 512;
  if (h < 1) h = 512;
  if (w == h) return (w, h);
  final side = w > h ? w : h;
  final padX = (side - w) / 2.0;
  final padY = (side - h) / 2.0;
  root['w'] = side;
  root['h'] = side;
  for (final layer in layers) {
    final ks = layer['ks'];
    if (ks is! Map) continue;
    final p = ks['p'];
    if (p is! Map || (p['a'] is num && (p['a'] as num).toInt() != 0)) {
      continue;
    }
    final k = p['k'];
    if (k is! List || k.length < 2) continue;
    final x = k[0];
    final y = k[1];
    if (x is! num || y is! num) continue;
    k[0] = x.toDouble() + padX;
    k[1] = y.toDouble() + padY;
  }
  return (side, side);
}

void _promoteExistingBackgroundToMetallic(
  List<Map<String, dynamic>> layers,
  List<Map<String, dynamic>> assets,
) {
  final hasMetallic = layers.any(
    (L) => (L['nm']?.toString() ?? '') == kKinLottieMetallicPlateLayerName,
  );
  if (hasMetallic) return;

  for (final layer in layers) {
    if ((layer['nm']?.toString() ?? '') != kKinLottieBackgroundLayerName) {
      continue;
    }
    if (layer['arcoriClaimBg'] == true) return;
    layer['nm'] = kKinLottieMetallicPlateLayerName;
    final ref = layer['refId']?.toString() ?? '';
    if (ref == kKinLottieBackgroundAssetId) {
      for (final asset in assets) {
        if ((asset['id']?.toString() ?? '') != kKinLottieBackgroundAssetId) {
          continue;
        }
        asset['id'] = kKinLottieMetallicPlateAssetId;
        layer['refId'] = kKinLottieMetallicPlateAssetId;
        break;
      }
    }
  }
}

void _upsertBackgroundAsset(
  List<Map<String, dynamic>> assets, {
  required String dataUrl,
  required int w,
  required int h,
}) {
  for (final asset in assets) {
    if ((asset['id']?.toString() ?? '') == kKinLottieBackgroundAssetId) {
      asset['p'] = dataUrl;
      asset['e'] = 1;
      asset['w'] = w;
      asset['h'] = h;
      asset['u'] = '';
      return;
    }
  }
  assets.add({
    'id': kKinLottieBackgroundAssetId,
    'w': w,
    'h': h,
    'u': '',
    'p': dataUrl,
    'e': 1,
  });
}

void _upsertBackgroundLayer(
  List<Map<String, dynamic>> layers, {
  required double scalePct,
}) {
  layers.removeWhere(
    (L) => (L['nm']?.toString() ?? '') == kKinLottieBackgroundLayerName,
  );
  var maxInd = 0;
  var maxOp = 30.0;
  for (final layer in layers) {
    final ind = layer['ind'];
    if (ind is int && ind > maxInd) maxInd = ind;
    final op = layer['op'];
    if (op is num && op.toDouble() > maxOp) maxOp = op.toDouble();
  }
  // Full-bleed like Entelair metallic_plate (top-left at origin).
  // scalePct > 100 when asset was capped below composition size.
  layers.add({
    'ddd': 0,
    'ind': maxInd + 1,
    'ty': 2,
    'nm': kKinLottieBackgroundLayerName,
    'refId': kKinLottieBackgroundAssetId,
    'arcoriClaimBg': true,
    'sr': 1,
    'ks': {
      'o': {'a': 0, 'k': 100},
      'r': {'a': 0, 'k': 0},
      'p': {
        'a': 0,
        'k': [0, 0, 0],
      },
      'a': {
        'a': 0,
        'k': [0, 0, 0],
      },
      's': {
        'a': 0,
        'k': [scalePct, scalePct, 100],
      },
    },
    'ao': 0,
    'ip': 0,
    'op': maxOp,
    'st': 0,
    'bm': 0,
  });
}

Future<Uint8List?> _rasterizeKinBackgroundScene(
  KinBackgroundScene scene, {
  required int w,
  required int h,
  http.Client? httpClient,
}) async {
  if (scene.isImage) {
    final url = resolveMediaUrl(scene.imageUrl);
    if (url.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('KinBgBake: image scene missing url → solid fallback');
      }
      return _solidPng(w, h, kKinBackgroundBakeFallback);
    }
    try {
      final client = httpClient ?? http.Client();
      final res = await client.get(Uri.parse(url));
      if (httpClient == null) client.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (LOGGING_SWITCH) {
          customlog(
            'KinBgBake: HTTP ${res.statusCode} for $url → solid fallback',
          );
        }
        return _solidPng(w, h, kKinBackgroundBakeFallback);
      }
      final covered = await _coverPngViaCanvas(res.bodyBytes, w, h);
      if (covered == null || covered.isEmpty) {
        if (LOGGING_SWITCH) {
          customlog(
            'KinBgBake: decode failed bytes=${res.bodyBytes.length} '
            'url=$url → solid fallback',
          );
        }
        return _solidPng(w, h, kKinBackgroundBakeFallback);
      }
      if (LOGGING_SWITCH) {
        customlog(
          'KinBgBake: ok → ${w}x$h (canvas cover) url=$url',
        );
      }
      return covered;
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('KinBgBake: exception $e url=$url → solid fallback');
      }
      return _solidPng(w, h, kKinBackgroundBakeFallback);
    }
  }

  if (scene.isGradient) {
    final a = scene.adjustedColorA ?? kKinBackgroundBakeFallback;
    final b = scene.adjustedColorB ?? a;
    final angle = scene.angleDegrees ?? kKinBgAngleDefault;
    return _gradientPng(w, h, a, b, angle);
  }

  final color = scene.adjustedColorA ?? kKinBackgroundBakeFallback;
  return _solidPng(w, h, color);
}

/// Flutter codec + canvas [BoxFit.cover] — avoids package:image OOM on tall comps.
Future<Uint8List?> _coverPngViaCanvas(Uint8List bytes, int w, int h) async {
  ui.Codec? codec;
  ui.Image? src;
  ui.Image? out;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    src = frame.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      image: src,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    out = await picture.toImage(w, h);
    picture.dispose();
    final bd = await out.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) return null;
    return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
  } finally {
    src?.dispose();
    out?.dispose();
    codec?.dispose();
  }
}

Uint8List _solidPng(int w, int h, Color color) {
  final out = img.Image(width: w, height: h);
  final r = (color.r * 255.0).round().clamp(0, 255);
  final g = (color.g * 255.0).round().clamp(0, 255);
  final b = (color.b * 255.0).round().clamp(0, 255);
  final a = (color.a * 255.0).round().clamp(0, 255);
  img.fill(
    out,
    color: img.ColorRgba8(r, g, b, a),
  );
  return Uint8List.fromList(img.encodePng(out));
}

Uint8List _gradientPng(
  int w,
  int h,
  Color colorA,
  Color colorB,
  double angleDegrees,
) {
  final out = img.Image(width: w, height: h);
  final rad = angleDegrees * math.pi / 180.0;
  final dx = math.sin(rad);
  final dy = -math.cos(rad);
  final cx = (w - 1) / 2.0;
  final cy = (h - 1) / 2.0;
  var pmin = double.infinity;
  var pmax = -double.infinity;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = (x - cx) * dx + (y - cy) * dy;
      if (p < pmin) pmin = p;
      if (p > pmax) pmax = p;
    }
  }
  final span = (pmax - pmin).abs() < 1e-9 ? 1.0 : (pmax - pmin);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final t = ((x - cx) * dx + (y - cy) * dy - pmin) / span;
      final c = Color.lerp(colorA, colorB, t.clamp(0.0, 1.0))!;
      out.setPixelRgba(
        x,
        y,
        (c.r * 255.0).round().clamp(0, 255),
        (c.g * 255.0).round().clamp(0, 255),
        (c.b * 255.0).round().clamp(0, 255),
        (c.a * 255.0).round().clamp(0, 255),
      );
    }
  }
  return Uint8List.fromList(img.encodePng(out));
}

/// Synchronous solid/gradient bake for unit tests (no network).
@visibleForTesting
String bakeKinBackgroundIntoLottieSync(
  String rawJson,
  KinBackgroundScene scene, {
  bool expandToSquare = true,
}) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map) return rawJson;
  final root = Map<String, dynamic>.from(decoded);
  final assets = <Map<String, dynamic>>[];
  final assetsRaw = root['assets'];
  if (assetsRaw is List) {
    for (final a in assetsRaw) {
      if (a is Map) assets.add(Map<String, dynamic>.from(a));
    }
  }
  root['assets'] = assets;
  final layers = <Map<String, dynamic>>[];
  final layersRaw = root['layers'];
  if (layersRaw is List) {
    for (final L in layersRaw) {
      if (L is Map) layers.add(Map<String, dynamic>.from(L));
    }
  }
  root['layers'] = layers;
  _promoteExistingBackgroundToMetallic(layers, assets);
  final size = expandToSquare
      ? _expandToSquareCanvas(root, layers)
      : (
          (root['w'] is num) ? (root['w'] as num).toInt() : 512,
          (root['h'] is num) ? (root['h'] as num).toInt() : 512,
        );
  final w = size.$1;
  final h = size.$2;
  final bake = kinBgBakeRasterSize(w, h);
  final color = scene.adjustedColorA ?? kKinBackgroundBakeFallback;
  final bytes = scene.isGradient
      ? _gradientPng(
          bake.bakeW,
          bake.bakeH,
          color,
          scene.adjustedColorB ?? color,
          scene.angleDegrees ?? kKinBgAngleDefault,
        )
      : _solidPng(bake.bakeW, bake.bakeH, color);
  final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
  _upsertBackgroundAsset(
    assets,
    dataUrl: dataUrl,
    w: bake.bakeW,
    h: bake.bakeH,
  );
  _upsertBackgroundLayer(layers, scalePct: bake.scalePct);
  return jsonEncode(root);
}
