import 'kin_models.dart';

/// Per-addition tint stored under an [KinCustomType.embedImage] value map.
class KinEmbedTint {
  const KinEmbedTint({
    this.hue = 0,
    this.lightDark = 0,
  });

  final double hue;
  final double lightDark;

  KinEmbedTint copyWith({double? hue, double? lightDark}) => KinEmbedTint(
        hue: hue ?? this.hue,
        lightDark: lightDark ?? this.lightDark,
      );

  Map<String, dynamic> toJson() => {
        'hue': hue,
        'lightDark': lightDark,
      };

  static KinEmbedTint fromJson(Object? raw) {
    if (raw is Map) {
      final hue = raw['hue'];
      final ld = raw['lightDark'];
      return KinEmbedTint(
        hue: hue is num ? hue.toDouble() : 0,
        lightDark: ld is num ? ld.toDouble() : 0,
      );
    }
    return const KinEmbedTint();
  }
}

/// Selected embeds → tint. Empty = none selected.
///
/// Wire shapes accepted for [KinCustomType.embedImage] `value`:
/// - legacy `String` serial → one selection, default tint
/// - `List` of serials → each with default tint
/// - `Map` serial → `{hue, lightDark}`
Map<String, KinEmbedTint> parseEmbedSelection(Object? value) {
  if (value == null) return const {};
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return const {};
    return {s: const KinEmbedTint()};
  }
  if (value is List) {
    final out = <String, KinEmbedTint>{};
    for (final e in value) {
      final s = e?.toString().trim() ?? '';
      if (s.isEmpty) continue;
      out[s] = const KinEmbedTint();
    }
    return out;
  }
  if (value is Map) {
    final out = <String, KinEmbedTint>{};
    for (final entry in value.entries) {
      final s = entry.key.toString().trim();
      if (s.isEmpty) continue;
      out[s] = KinEmbedTint.fromJson(entry.value);
    }
    return out;
  }
  return const {};
}

/// Encode selection for applied-custom storage / claim payload.
Map<String, dynamic> encodeEmbedSelection(Map<String, KinEmbedTint> selected) {
  final out = <String, dynamic>{};
  for (final e in selected.entries) {
    if (e.key.isEmpty) continue;
    out[e.key] = e.value.toJson();
  }
  return out;
}

/// Resolve which part owns an embed serial (first part with pool + placement).
KinPart? partOwningEmbed(KinTemplate template, String embedSerial) {
  for (final part in template.parts) {
    if (!part.allowsEmbed(embedSerial)) continue;
    if (part.placementFor(embedSerial) == null) continue;
    return part;
  }
  return null;
}

/// All selectable embeds on a Kin (across parts), stable order by part then pool.
List<({KinPart part, KinEmbed embed})> allSelectableEmbeds({
  required KinTemplate template,
  required KinCreationCatalog catalog,
}) {
  final out = <({KinPart part, KinEmbed embed})>[];
  final seen = <String>{};
  for (final part in template.parts) {
    for (final e in catalog.embedsFor(part)) {
      if (!seen.add(e.serial)) continue;
      out.add((part: part, embed: e));
    }
  }
  return out;
}
