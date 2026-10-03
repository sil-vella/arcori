/// Hot Kin addition catalog from API (art + attachment specs; no Flutter rebuild).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/ws/ws_config.dart';
import '../../utils/dev_logger.dart';
import 'kin_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// One attachment row from `/authuser/avari/kin/embeds`.
class KinRemoteEmbedAttachment {
  const KinRemoteEmbedAttachment({
    required this.kinSerial,
    required this.partSerial,
    required this.placement,
  });

  factory KinRemoteEmbedAttachment.fromJson(Map<String, dynamic> json) {
    final rawPlacement = json['placement'];
    return KinRemoteEmbedAttachment(
      kinSerial: json['kinSerial']?.toString() ?? '',
      partSerial: json['partSerial']?.toString() ?? '',
      placement: rawPlacement is Map
          ? KinEmbedPlacement.fromJson(Map<String, dynamic>.from(rawPlacement))
          : const KinEmbedPlacement(
              targetLayer: '',
              side: KinEmbedSide.inFront,
            ),
    );
  }

  final String kinSerial;
  final String partSerial;
  final KinEmbedPlacement placement;

  bool get isValid =>
      kinSerial.isNotEmpty && partSerial.isNotEmpty && placement.isValid;
}

/// Remote embed definition (serial + art URL + which Kin parts accept it).
class KinRemoteEmbed {
  const KinRemoteEmbed({
    required this.serial,
    required this.displayName,
    required this.imageUrl,
    this.attachments = const [],
  });

  factory KinRemoteEmbed.fromJson(Map<String, dynamic> json) {
    final rawAtts = json['attachments'];
    final attachments = <KinRemoteEmbedAttachment>[];
    if (rawAtts is List) {
      for (final raw in rawAtts) {
        if (raw is! Map) continue;
        final att = KinRemoteEmbedAttachment.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (att.isValid) attachments.add(att);
      }
    }
    return KinRemoteEmbed(
      serial: json['serial']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      attachments: attachments,
    );
  }

  final String serial;
  final String displayName;
  final String imageUrl;
  final List<KinRemoteEmbedAttachment> attachments;

  bool get isValid =>
      serial.isNotEmpty && imageUrl.isNotEmpty && attachments.isNotEmpty;
}

/// Fetch hot embeds list (empty on failure).
Future<List<KinRemoteEmbed>> fetchKinRemoteEmbeds({
  required String? accessToken,
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  try {
    final uri = Uri.parse('${WsConfig.apiRestBase}/authuser/avari/kin/embeds');
    final headers = <String, String>{};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final response = await client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (LOGGING_SWITCH) {
        customlog('KinEmbeds: status=${response.statusCode}');
      }
      return const [];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['ok'] != true) return const [];
    final data = decoded['data'];
    if (data is! Map) return const [];
    final rawList = data['embeds'];
    if (rawList is! List) return const [];
    final out = <KinRemoteEmbed>[];
    for (final raw in rawList) {
      if (raw is! Map) continue;
      final row = KinRemoteEmbed.fromJson(Map<String, dynamic>.from(raw));
      if (row.isValid) out.add(row);
    }
    if (LOGGING_SWITCH) {
      customlog('KinEmbeds: fetched n=${out.length}');
    }
    return out;
  } catch (e) {
    if (LOGGING_SWITCH) {
      customlog('KinEmbeds: fetch failed $e');
    }
    return const [];
  } finally {
    if (httpClient == null) client.close();
  }
}

/// Merge remote embeds into a bundled catalog (remote wins for art + pools).
///
/// Hue / lightDark stay client-side on selected embeds — not catalog fields.
KinCreationCatalog mergeKinRemoteEmbeds(
  KinCreationCatalog base,
  List<KinRemoteEmbed> remote,
) {
  if (remote.isEmpty) return base;

  final embedsBySerial = <String, KinEmbed>{
    for (final e in base.embeds) e.serial: e,
  };
  final kinsBySerial = <String, KinTemplate>{
    for (final k in base.kins) k.serial: k,
  };

  for (final row in remote) {
    final existing = embedsBySerial[row.serial];
    embedsBySerial[row.serial] = KinEmbed(
      serial: row.serial,
      displayName:
          row.displayName.isNotEmpty ? row.displayName : (existing?.displayName ?? row.serial),
      assetPath: existing?.assetPath ?? '',
      imageUrl: row.imageUrl,
    );

    for (final att in row.attachments) {
      final kin = kinsBySerial[att.kinSerial];
      if (kin == null) {
        if (LOGGING_SWITCH) {
          customlog(
            'KinEmbeds: skip attach ${row.serial} — unknown kin ${att.kinSerial}',
          );
        }
        continue;
      }
      final partIndex = kin.parts.indexWhere((p) => p.serial == att.partSerial);
      if (partIndex < 0) {
        if (LOGGING_SWITCH) {
          customlog(
            'KinEmbeds: skip attach ${row.serial} — unknown part ${att.partSerial}',
          );
        }
        continue;
      }
      final part = kin.parts[partIndex];
      final pool = List<String>.from(part.embedPoolSerials);
      if (!pool.contains(row.serial)) pool.add(row.serial);
      final placements = Map<String, KinEmbedPlacement>.from(part.embedPlacements);
      placements[row.serial] = att.placement;
      final allowed = List<String>.from(part.allowedCustomSerials);
      if (!allowed.contains(kKinEmbedImageSerial)) {
        allowed.add(kKinEmbedImageSerial);
      }
      final newParts = List<KinPart>.from(kin.parts);
      newParts[partIndex] = part.copyWith(
        embedPoolSerials: pool,
        embedPlacements: placements,
        allowedCustomSerials: allowed,
      );
      kinsBySerial[att.kinSerial] = kin.copyWith(parts: newParts);
    }
  }

  // Preserve bundled order; append any new serials at end.
  final embedOrder = <String>[
    for (final e in base.embeds) e.serial,
  ];
  for (final row in remote) {
    if (!embedOrder.contains(row.serial)) embedOrder.add(row.serial);
  }
  final embeds = <KinEmbed>[
    for (final serial in embedOrder)
      if (embedsBySerial.containsKey(serial)) embedsBySerial[serial]!,
  ];

  final kinOrder = <String>[for (final k in base.kins) k.serial];
  final kins = <KinTemplate>[
    for (final serial in kinOrder)
      if (kinsBySerial.containsKey(serial)) kinsBySerial[serial]!,
  ];

  return base.copyWith(embeds: embeds, kins: kins);
}
