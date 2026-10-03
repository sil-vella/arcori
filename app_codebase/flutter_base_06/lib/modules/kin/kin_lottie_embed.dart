import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../core/http/media_url.dart';
import '../../utils/dev_logger.dart';
import 'kin_embed_selection.dart';
import 'kin_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Stable Lottie layer name for an applied embed.
String kinEmbedLayerName(String embedSerial) => 'embed_$embedSerial';

String kinEmbedAssetId(String embedSerial) => 'asset_embed_$embedSerial';

/// One embed insert job resolved from catalog + applied customs.
class KinEmbedBakeJob {
  const KinEmbedBakeJob({
    required this.embedSerial,
    required this.targetLayer,
    required this.side,
    required this.assetPath,
    this.p,
    this.s,
    this.pngBytes,
  });

  final String embedSerial;

  /// Lottie layer `nm` the embed is placed relative to.
  final String targetLayer;

  final KinEmbedSide side;

  /// Bundle asset path or `/catalog-media/...` / absolute URL ([KinEmbed.bakeSource]).
  final String assetPath;
  final List<double>? p;
  final List<double>? s;

  /// When set (tests / preloaded), skip network / [rootBundle] load.
  final Uint8List? pngBytes;
}

/// Resolve embedImage customs into bake jobs (skips missing placement / pool).
///
/// Supports multi-select: [KinCustomType.embedImage] value may be a map/list
/// of serials (see [parseEmbedSelection]).
List<KinEmbedBakeJob> resolveEmbedJobs({
  required KinTemplate template,
  required KinCreationCatalog catalog,
  required List<KinAppliedCustom> applied,
}) {
  final out = <KinEmbedBakeJob>[];
  final seen = <String>{};
  for (final a in applied) {
    final custom = catalog.customBySerial(a.customSerial);
    if (custom == null || custom.customType != KinCustomType.embedImage) {
      continue;
    }
    final part = template.partBySerial(a.partSerial);
    if (part == null) continue;
    final selected = parseEmbedSelection(a.value);
    for (final embedSerial in selected.keys) {
      if (!part.allowsEmbed(embedSerial)) continue;
      final placement = part.placementFor(embedSerial);
      if (placement == null) continue;
      final embed = catalog.embedBySerial(embedSerial);
      if (embed == null || !embed.hasArt) continue;
      if (!seen.add(embedSerial)) continue;
      out.add(
        KinEmbedBakeJob(
          embedSerial: embedSerial,
          targetLayer: placement.targetLayer,
          side: placement.side,
          assetPath: embed.bakeSource,
          p: placement.p,
          s: placement.s,
        ),
      );
    }
  }
  // Same `inFrontOf` target: insert frontmost first, then nest later peers
  // between it and the target → [shield, hatchet, eyes]. HMG/HGD serials
  // rise toward the back of the addition stack (…0026 shield, …0025 hatchet),
  // so sort descending.
  out.sort((a, b) => b.embedSerial.compareTo(a.embedSerial));
  return out;
}

/// Insert embed image layers relative to their target layers. Idempotent per serial.
Future<String> bakeKinEmbedsIntoLottie(
  String rawJson,
  List<KinEmbedBakeJob> jobs, {
  Future<Uint8List?> Function(String assetPath)? loadAsset,
  http.Client? httpClient,
  bool pretty = false,
}) async {
  if (jobs.isEmpty) return rawJson;
  final loader = loadAsset ??
      ((source) => loadKinEmbedBytes(source, httpClient: httpClient));
  final withBytes = <KinEmbedBakeJob>[];
  for (final job in jobs) {
    var bytes = job.pngBytes;
    if (bytes == null || bytes.isEmpty) {
      bytes = await loader(job.assetPath);
    }
    if (bytes == null || bytes.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog(
          'KinEmbed: skip ${job.embedSerial} — no bytes for ${job.assetPath}',
        );
      }
      continue;
    }
    // Keep authored canvas (incl. transparent padding). Independent downscale
    // desyncs full-comp additions from Kin layer transforms / placements.
    withBytes.add(
      KinEmbedBakeJob(
        embedSerial: job.embedSerial,
        targetLayer: job.targetLayer,
        side: job.side,
        assetPath: job.assetPath,
        p: job.p,
        s: job.s,
        pngBytes: bytes,
      ),
    );
  }
  return bakeKinEmbedsIntoLottieSync(rawJson, withBytes, pretty: pretty);
}

/// Sync bake when each job already has [KinEmbedBakeJob.pngBytes].
String bakeKinEmbedsIntoLottieSync(
  String rawJson,
  List<KinEmbedBakeJob> jobs, {
  bool pretty = false,
}) {
  if (jobs.isEmpty) return rawJson;
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map) return rawJson;
  final root = Map<String, dynamic>.from(decoded);

  final assetsRaw = root['assets'];
  final layersRaw = root['layers'];
  if (assetsRaw is! List || layersRaw is! List) return rawJson;

  final assets = <Map<String, dynamic>>[
    for (final a in assetsRaw)
      if (a is Map) Map<String, dynamic>.from(a),
  ];
  final layers = <Map<String, dynamic>>[
    for (final l in layersRaw)
      if (l is Map) Map<String, dynamic>.from(l),
  ];

  final w = (root['w'] is num) ? (root['w'] as num).toInt() : 512;
  final h = (root['h'] is num) ? (root['h'] as num).toInt() : 512;

  for (final job in jobs) {
    final bytes = job.pngBytes;
    if (bytes == null || bytes.isEmpty) continue;
    _upsertEmbed(
      root: root,
      assets: assets,
      layers: layers,
      job: job,
      pngBytes: bytes,
      compW: w,
      compH: h,
    );
  }

  root['assets'] = assets;
  root['layers'] = layers;
  if (pretty) {
    return const JsonEncoder.withIndent('  ').convert(root);
  }
  return jsonEncode(root);
}

/// Compose identity: embed serials + placement (target/side/p/s).
///
/// Tint / part styles stay out — those use [LottieDelegates]. Placement `p`/`s`
/// must invalidate so catalog nudge edits re-bake the preview.
String kinPreviewEmbedSignature({
  required KinTemplate template,
  required KinCreationCatalog catalog,
  required List<KinAppliedCustom> applied,
}) {
  final jobs = resolveEmbedJobs(
    template: template,
    catalog: catalog,
    applied: applied,
  );
  if (jobs.isEmpty) return '';
  final parts = jobs.map((j) {
    final p = j.p?.map((n) => n.toString()).join(',') ?? '';
    final s = j.s?.map((n) => n.toString()).join(',') ?? '';
    return '${j.embedSerial}:${j.side.name}@${j.targetLayer}|p=$p|s=$s';
  }).toList()
    ..sort();
  return parts.join(';');
}

void _upsertEmbed({
  required Map<String, dynamic> root,
  required List<Map<String, dynamic>> assets,
  required List<Map<String, dynamic>> layers,
  required KinEmbedBakeJob job,
  required Uint8List pngBytes,
  required int compW,
  required int compH,
}) {
  final layerName = kinEmbedLayerName(job.embedSerial);
  final assetId = kinEmbedAssetId(job.embedSerial);
  final dataUrl = 'data:image/png;base64,${base64Encode(pngBytes)}';

  final dims = _pngSize(pngBytes);
  final imgW = dims.$1;
  final imgH = dims.$2;

  assets.removeWhere((a) => (a['id']?.toString() ?? '') == assetId);
  assets.add({
    'id': assetId,
    'w': imgW,
    'h': imgH,
    'u': '',
    'p': dataUrl,
    'e': 1,
  });

  layers.removeWhere((L) => (L['nm']?.toString() ?? '') == layerName);

  final targetIdx = layers.indexWhere(
    (L) => (L['nm']?.toString() ?? '') == job.targetLayer,
  );
  if (targetIdx < 0) {
    if (LOGGING_SWITCH) {
      customlog(
        'KinEmbed: target layer missing target=${job.targetLayer} '
        'side=${job.side.name} embed=${job.embedSerial}',
      );
    }
    return;
  }

  var maxInd = 0;
  var maxOp = 30.0;
  for (final layer in layers) {
    final ind = layer['ind'];
    if (ind is int && ind > maxInd) maxInd = ind;
    final op = layer['op'];
    if (op is num && op.toDouble() > maxOp) maxOp = op.toDouble();
  }

  final pos = job.p ?? [0.0, 0.0, 0.0];
  final scale = job.s ?? [100.0, 100.0, 100.0];
  // Full-canvas addition art stacks at origin (same w×h as template).
  final anchor = [0.0, 0.0, 0.0];

  final layer = <String, dynamic>{
    'ddd': 0,
    'ind': maxInd + 1,
    'ty': 2,
    'nm': layerName,
    'refId': assetId,
    'sr': 1,
    'ks': {
      'o': {'a': 0, 'k': 100},
      'r': {'a': 0, 'k': 0},
      'p': {
        'a': 0,
        'k': [pos[0], pos[1], pos.length > 2 ? pos[2] : 0.0],
      },
      'a': {
        'a': 0,
        'k': anchor,
      },
      's': {
        'a': 0,
        'k': [scale[0], scale[1], scale.length > 2 ? scale[2] : 100.0],
      },
    },
    'ao': 0,
    'ip': root['ip'] ?? 0,
    'op': root['op'] ?? maxOp,
    'st': 0,
    'bm': 0,
  };

  // Lower list index = on top.
  final insertAt =
      job.side == KinEmbedSide.inFront ? targetIdx : targetIdx + 1;
  layers.insert(insertAt, layer);
}

(int, int) _pngSize(Uint8List bytes) {
  // IHDR: width/height at bytes 16..23 for standard PNG.
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    if (w > 0 && h > 0) return (w, h);
  }
  return (64, 64);
}

/// Load embed art bytes from catalog-media URL or Flutter asset bundle.
Future<Uint8List?> loadKinEmbedBytes(
  String source, {
  http.Client? httpClient,
}) async {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return null;
  final isNetwork = trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('/catalog-media/') ||
      trimmed.startsWith('/media/');
  if (isNetwork) {
    final url = resolveMediaUrl(trimmed);
    if (url.isEmpty) return null;
    final client = httpClient ?? http.Client();
    try {
      final res = await client.get(Uri.parse(url));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      if (res.bodyBytes.isEmpty) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    } finally {
      if (httpClient == null) client.close();
    }
  }
  try {
    final data = await rootBundle.load(trimmed);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
