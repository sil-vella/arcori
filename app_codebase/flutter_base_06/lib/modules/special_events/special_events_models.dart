/// Wire models for special-events catalog.
library;

import '../../core/media/catalog_media.dart';

export '../../core/media/catalog_media.dart';

class SpecialEventProgress {
  const SpecialEventProgress({
    this.matchesCredited = 0,
    this.matchesRequired = 1,
    this.matchesCompleted = 0,
    this.matchesWon = 0,
    this.flips = 0,
  });

  factory SpecialEventProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SpecialEventProgress();
    return SpecialEventProgress(
      matchesCredited: _asInt(json['matchesCredited']),
      matchesRequired: _asInt(json['matchesRequired'], fallback: 1),
      matchesCompleted: _asInt(json['matchesCompleted']),
      matchesWon: _asInt(json['matchesWon']),
      flips: _asInt(json['flips']),
    );
  }

  final int matchesCredited;
  final int matchesRequired;
  final int matchesCompleted;
  final int matchesWon;
  final int flips;

  String get progressLabel => '$matchesCredited/$matchesRequired';
}

class SpecialEventEntry {
  const SpecialEventEntry({
    required this.id,
    required this.name,
    this.subtype = '',
    this.description = '',
    this.eligible = true,
    this.blockedReason,
    this.feeFragments = 2,
    this.rounds = 2,
    this.arcoriSource = '',
    this.minMasteryRatio,
    this.hardPick = false,
    this.media = const CatalogMediaMap(),
    this.progress = const SpecialEventProgress(),
  });

  factory SpecialEventEntry.fromJson(Map<String, dynamic> json) {
    final match = json['match'] is Map
        ? Map<String, dynamic>.from(json['match'] as Map)
        : <String, dynamic>{};
    final arcori = json['arcori'] is Map
        ? Map<String, dynamic>.from(json['arcori'] as Map)
        : <String, dynamic>{};
    final progressRaw = json['progress'];
    double? ratio;
    final ratioRaw = arcori['minMasteryRatio'] ?? arcori['min_mastery_ratio'];
    if (ratioRaw is num) {
      ratio = ratioRaw.toDouble();
    } else if (ratioRaw != null) {
      ratio = double.tryParse(ratioRaw.toString());
    }
    if (ratio != null && ratio <= 0) ratio = null;
    return SpecialEventEntry(
      id: json['id']?.toString().trim() ?? '',
      subtype: json['subtype']?.toString().trim() ?? '',
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : (json['id']?.toString() ?? ''),
      description: json['description']?.toString() ?? '',
      eligible: json['eligible'] != false,
      blockedReason: json['blockedReason']?.toString(),
      feeFragments: _asInt(match['feeFragments'], fallback: 2),
      rounds: _asInt(match['rounds'], fallback: 2),
      arcoriSource: arcori['source']?.toString().trim() ?? '',
      minMasteryRatio: ratio,
      hardPick: arcori['hardPick'] == true || arcori['hard_pick'] == true,
      media: CatalogMediaMap.fromJson(json['media']),
      progress: SpecialEventProgress.fromJson(
        progressRaw is Map
            ? Map<String, dynamic>.from(progressRaw)
            : null,
      ),
    );
  }

  final String id;
  final String subtype;
  final String name;
  final String description;
  final bool eligible;
  final String? blockedReason;
  final int feeFragments;
  final int rounds;

  /// Catalog `arcori.source` (e.g. `active_windows`, `circulation`).
  final String arcoriSource;

  /// When set, candidates need mastery ≥ ratio × mintReach.
  final double? minMasteryRatio;

  /// JSON `arcori.hard_pick` — human must choose before queue.
  final bool hardPick;

  final CatalogMediaMap media;
  final SpecialEventProgress progress;

  bool get requiresActiveWindowPick => arcoriSource == 'active_windows';

  bool get requiresArcoriHardPick =>
      hardPick || requiresActiveWindowPick;

  CatalogMediaRef? get banner =>
      media['banner'] ?? media['special_arena_background'];
}

class SpecialEventsCatalog {
  const SpecialEventsCatalog({
    this.revision = '',
    this.events = const [],
  });

  factory SpecialEventsCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['events'];
    final list = <SpecialEventEntry>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final e = SpecialEventEntry.fromJson(Map<String, dynamic>.from(item));
        if (e.id.isEmpty) continue;
        list.add(e);
      }
    }
    return SpecialEventsCatalog(
      revision: json['revision']?.toString() ?? '',
      events: list,
    );
  }

  final String revision;
  final List<SpecialEventEntry> events;
}

int _asInt(dynamic raw, {int fallback = 0}) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}
