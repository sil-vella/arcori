import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/http/media_url.dart';
import 'kin_backgrounds.dart';
import 'kin_embed_selection.dart';
import 'kin_lottie_background.dart';
import 'kin_lottie_embed.dart';
import 'kin_lottie_style.dart';
import 'kin_models.dart';

/// Local Kin saves: Lottie file + sidecar index under app documents.
class KinSaveStore {
  KinSaveStore({
    FlutterSecureStorage? storage,
    Future<Directory> Function()? documentsDirectory,
    http.Client? httpClient,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory,
        _http = httpClient ?? http.Client();

  static const activeSerialKey = 'arcori_active_kin_save_serial';
  static const counterKey = 'arcori_kin_save_counter';
  static const savesFolderName = 'kin_saves';

  final FlutterSecureStorage _storage;
  final Future<Directory> Function() _documentsDirectory;
  final http.Client _http;

  Future<Directory> _savesDir() async {
    final root = await _documentsDirectory();
    final dir = Directory('${root.path}/$savesFolderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> readActiveSerial() async {
    final v = await _storage.read(key: activeSerialKey);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> writeActiveSerial(String serial) async {
    await _storage.write(key: activeSerialKey, value: serial);
  }

  Future<int> _nextCounter() async {
    final raw = await _storage.read(key: counterKey);
    final current = int.tryParse(raw ?? '') ?? 0;
    final next = current + 1;
    await _storage.write(key: counterKey, value: '$next');
    return next;
  }

  String formatSaveSerial(int n) => 'KSAVE-${n.toString().padLeft(4, '0')}';

  File sidecarFile(Directory dir, String serial) =>
      File('${dir.path}/$serial.json');

  File lottieFile(Directory dir, String serial) =>
      File('${dir.path}/$serial.lottie.json');

  Future<KinSaveDraft?> readActiveDraft() async {
    final serial = await readActiveSerial();
    if (serial == null) return null;
    return readDraft(serial);
  }

  Future<KinSaveDraft?> readDraft(String serial) async {
    final dir = await _savesDir();
    final file = sidecarFile(dir, serial);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return null;
    return KinSaveDraft.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<File?> lottieFileFor(KinSaveDraft draft) async {
    final dir = await _savesDir();
    final file = File('${dir.path}/${draft.lottieRelativePath}');
    if (!await file.exists()) return null;
    return file;
  }

  /// Validates applied customs against [template]; drops disallowed entries.
  List<KinAppliedCustom> filterAllowed(
    KinTemplate template,
    KinCreationCatalog catalog,
    List<KinAppliedCustom> applied,
  ) {
    final out = <KinAppliedCustom>[];
    for (final a in applied) {
      final part = template.partBySerial(a.partSerial);
      if (part == null) continue;
      if (!part.allowsCustom(a.customSerial)) continue;
      final custom = catalog.customBySerial(a.customSerial);
      if (custom == null) continue;
      if (custom.customType == KinCustomType.embedImage) {
        final selected = parseEmbedSelection(a.value);
        final cleaned = <String, KinEmbedTint>{};
        for (final e in selected.entries) {
          if (!part.allowsEmbed(e.key)) continue;
          if (part.placementFor(e.key) == null) continue;
          cleaned[e.key] = e.value;
        }
        if (cleaned.isEmpty) continue;
        out.add(
          KinAppliedCustom(
            partSerial: a.partSerial,
            customSerial: a.customSerial,
            value: encodeEmbedSelection(cleaned),
          ),
        );
        continue;
      } else if (custom.customType == KinCustomType.swapPart) {
        final embedSerial = a.value?.toString() ?? '';
        if (embedSerial.isNotEmpty && !part.allowsEmbed(embedSerial)) {
          continue;
        }
      } else if (custom.customType == KinCustomType.embedHue ||
          custom.customType == KinCustomType.embedLightDark) {
        // Deprecated part-level companions; tints live in embedImage map.
        continue;
      }
      out.add(a);
    }
    return out;
  }

  Future<String> _loadTemplateLottieBody(KinTemplate template, String serial) async {
    final url = resolveMediaUrl(template.lottieUrl);
    if (url.isEmpty) {
      return _placeholderLottieJson(template.displayName, serial);
    }
    try {
      final res = await _http.get(Uri.parse(url));
      if (res.statusCode >= 200 && res.statusCode < 300 && res.body.isNotEmpty) {
        return res.body;
      }
    } catch (_) {
      // Fall through to placeholder.
    }
    return _placeholderLottieJson(template.displayName, serial);
  }

  Future<KinSaveDraft> save({
    required KinTemplate template,
    required KinCreationCatalog catalog,
    required List<KinAppliedCustom> applied,
    String? displayName,
    String? regionCode,
    String? colorHex,
    String? chosenName,
    String? backgroundId,
    KinBackgroundScene? backgroundScene,
    KinBackgroundFilterMode? backgroundFilterMode,
  }) async {
    final allowed = filterAllowed(template, catalog, applied);
    // One active draft: overwrite sidecar/lottie instead of minting KSAVE-NNNN.
    final existingSerial = await readActiveSerial();
    final serial = (existingSerial != null && existingSerial.isNotEmpty)
        ? existingSerial
        : formatSaveSerial(await _nextCounter());
    final dir = await _savesDir();
    final lottieName = '$serial.lottie.json';
    final outLottie = lottieFile(dir, serial);

    final body = await buildBakedLottieJson(
      template: template,
      catalog: catalog,
      applied: allowed,
      backgroundScene: backgroundScene,
      // Pad tall comps to square so disc BoxFit.cover keeps full character.
      expandBackgroundToSquare: true,
    );
    await outLottie.writeAsString(body);

    final name = (chosenName != null && chosenName.trim().isNotEmpty)
        ? chosenName.trim()
        : ((displayName == null || displayName.trim().isEmpty)
            ? template.displayName
            : displayName.trim());
    final filterMode = backgroundFilterMode ?? KinBackgroundFilterMode.theme;
    final draft = KinSaveDraft(
      serial: serial,
      kinSerial: template.serial,
      typeSerial: template.typeSerial,
      displayName: name,
      lottieRelativePath: lottieName,
      applied: allowed,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      regionCode: regionCode,
      colorHex: colorHex,
      chosenName: name,
      backgroundId: backgroundId ?? backgroundScene?.id,
      background: backgroundScene?.toClaimJson(),
      backgroundFilterMode: filterMode.name,
    );
    await sidecarFile(dir, serial).writeAsString(
      const JsonEncoder.withIndent('  ').convert(draft.toJson()),
    );
    await writeActiveSerial(serial);
    return draft;
  }

  /// Full pixel bake for claim / draft: embeds + styles, then BG.
  ///
  /// Square-pad runs inside the BG bake and must run *after* embeds so pad
  /// shifts character + embed layers together. Baking BG/expand first left
  /// catalog embed `p` on the unpadded axis (wings/shield shifted left on HGD).
  ///
  /// Server still re-bakes BG from disk on claim (tall ASP gray fallback).
  Future<String> buildBakedLottieJson({
    required KinTemplate template,
    required KinCreationCatalog catalog,
    required List<KinAppliedCustom> applied,
    KinBackgroundScene? backgroundScene,
    bool expandBackgroundToSquare = true,
    String placeholderSerial = 'CLAIM',
  }) async {
    final allowed = filterAllowed(template, catalog, applied);
    final bodyRaw = await _loadTemplateLottieBody(template, placeholderSerial);
    final styles = resolveLayerStyles(
      template: template,
      catalog: catalog,
      applied: allowed,
    );
    var body = bodyRaw;
    final embedJobs = resolveEmbedJobs(
      template: template,
      catalog: catalog,
      applied: allowed,
    );
    if (embedJobs.isNotEmpty) {
      body = await bakeKinEmbedsIntoLottie(body, embedJobs);
    }
    body = bakeKinLottieJson(body, styles);
    final scene = backgroundScene;
    if (scene != null) {
      body = await bakeKinBackgroundIntoLottie(
        body,
        scene,
        httpClient: _http,
        expandToSquare: expandBackgroundToSquare,
      );
    }
    return body;
  }

  String _placeholderLottieJson(String name, String serial) {
    return jsonEncode({
      'v': '5.7.4',
      'fr': 30,
      'ip': 0,
      'op': 30,
      'w': 512,
      'h': 512,
      'nm': '$name ($serial)',
      'ddd': 0,
      'assets': <dynamic>[],
      'layers': <dynamic>[],
      'meta': {
        'g': 'arcori kin placeholder',
        'kinSave': serial,
      },
    });
  }
}
