/// Catalog design models for Velora browse + Arcori Detail.
library;

double? _readSelectionWeight(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}

class DesignGeneration {
  const DesignGeneration({this.roman, this.number});

  factory DesignGeneration.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DesignGeneration();
    return DesignGeneration(
      roman: json['roman']?.toString(),
      number: json['number'] is int
          ? json['number'] as int
          : int.tryParse('${json['number']}'),
    );
  }

  final String? roman;
  final int? number;

  String? get display {
    if (roman != null && roman!.isNotEmpty) return roman;
    if (number != null) return '$number';
    return null;
  }
}

class DesignLegacy {
  const DesignLegacy({
    this.preservationRequirement,
    this.closureMilestone,
  });

  factory DesignLegacy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DesignLegacy();
    int? asInt(Object? raw) {
      if (raw is int) return raw;
      return int.tryParse('$raw');
    }

    return DesignLegacy(
      preservationRequirement: asInt(json['preservationRequirement']),
      closureMilestone: asInt(json['closureMilestone']),
    );
  }

  final int? preservationRequirement;
  final int? closureMilestone;

  bool get isEmpty =>
      preservationRequirement == null && closureMilestone == null;
}

class DesignSummary {
  const DesignSummary({
    required this.internalId,
    this.design,
    this.theme,
    this.subtheme,
    this.themeCode,
    this.printedRarity,
    this.selectionWeight,
    this.series,
    this.seriesKey,
    this.worldState,
    this.seasonState,
    this.type,
    this.imageUrl,
    this.lottieUrl,
    this.color,
    this.generation,
  });

  factory DesignSummary.fromJson(Map<String, dynamic> json) {
    final gen = json['generation'];
    return DesignSummary(
      internalId: json['internalId']?.toString() ?? '',
      design: json['design']?.toString(),
      theme: json['theme']?.toString(),
      subtheme: json['subtheme']?.toString(),
      themeCode: json['themeCode']?.toString(),
      printedRarity: json['printedRarity']?.toString(),
      selectionWeight: _readSelectionWeight(json['selectionWeight']),
      series: json['series']?.toString(),
      seriesKey: json['seriesKey']?.toString(),
      worldState: json['worldState']?.toString(),
      seasonState: json['seasonState']?.toString(),
      type: json['type']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      lottieUrl: json['lottieUrl']?.toString(),
      color: json['color']?.toString(),
      generation: gen is Map
          ? DesignGeneration.fromJson(Map<String, dynamic>.from(gen))
          : null,
    );
  }

  final String internalId;
  final String? design;
  final String? theme;
  final String? subtheme;
  final String? themeCode;
  final String? printedRarity;
  final double? selectionWeight;
  final String? series;
  final String? seriesKey;
  final String? worldState;
  final String? seasonState;
  final String? type;
  final String? imageUrl;
  final String? lottieUrl;
  final String? color;
  final DesignGeneration? generation;

  String get displayName =>
      (design != null && design!.isNotEmpty) ? design! : internalId;
}

class DesignDetail {
  const DesignDetail({
    required this.internalId,
    this.design,
    this.theme,
    this.subtheme,
    this.themeCode,
    this.printedRarity,
    this.selectionWeight,
    this.series,
    this.seriesKey,
    this.worldState,
    this.seasonState,
    this.type,
    this.imageUrl,
    this.lottieUrl,
    this.color,
    this.loreDescription,
    this.generation,
    this.legacy,
  });

  factory DesignDetail.fromJson(Map<String, dynamic> json) {
    final gen = json['generation'];
    final legacyRaw = json['legacy'];
    return DesignDetail(
      internalId: json['internalId']?.toString() ?? '',
      design: json['design']?.toString(),
      theme: json['theme']?.toString(),
      subtheme: json['subtheme']?.toString(),
      themeCode: json['themeCode']?.toString(),
      printedRarity: json['printedRarity']?.toString(),
      selectionWeight: _readSelectionWeight(json['selectionWeight']),
      series: json['series']?.toString(),
      seriesKey: json['seriesKey']?.toString(),
      worldState: json['worldState']?.toString(),
      seasonState: json['seasonState']?.toString(),
      type: json['type']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      lottieUrl: json['lottieUrl']?.toString(),
      color: json['color']?.toString(),
      loreDescription: json['loreDescription']?.toString(),
      generation: gen is Map
          ? DesignGeneration.fromJson(Map<String, dynamic>.from(gen))
          : null,
      legacy: legacyRaw is Map
          ? DesignLegacy.fromJson(Map<String, dynamic>.from(legacyRaw))
          : null,
    );
  }

  final String internalId;
  final String? design;
  final String? theme;
  final String? subtheme;
  final String? themeCode;
  final String? printedRarity;
  final double? selectionWeight;
  final String? series;
  final String? seriesKey;
  final String? worldState;
  final String? seasonState;
  final String? type;
  final String? imageUrl;
  final String? lottieUrl;
  final String? color;
  final String? loreDescription;
  final DesignGeneration? generation;
  final DesignLegacy? legacy;

  String get displayName =>
      (design != null && design!.isNotEmpty) ? design! : internalId;
}

/// Designs under one series within a theme category.
class VeloraSeriesGroup {
  const VeloraSeriesGroup({
    required this.seriesKey,
    required this.designs,
  });

  final String seriesKey;
  final List<DesignSummary> designs;
}

/// Theme category with nested series groups (theme → series).
class VeloraThemeGroup {
  const VeloraThemeGroup({
    required this.theme,
    required this.series,
  });

  final String theme;
  final List<VeloraSeriesGroup> series;
}

/// Catalog theme from meta (Velora entry buttons).
class CatalogThemeEntry {
  const CatalogThemeEntry({
    required this.theme,
    required this.themeCode,
  });

  factory CatalogThemeEntry.fromJson(Map<String, dynamic> json) {
    return CatalogThemeEntry(
      theme: json['theme']?.toString() ?? '',
      themeCode: json['themeCode']?.toString() ?? '',
    );
  }

  final String theme;
  final String themeCode;

  String get label => theme.isNotEmpty ? theme : themeCode;
}

class StandingsRankEntry {
  const StandingsRankEntry({
    required this.rank,
    required this.displayLabel,
    required this.masteryPoints,
  });

  factory StandingsRankEntry.fromJson(Map<String, dynamic> json) {
    return StandingsRankEntry(
      rank: json['rank'] is int
          ? json['rank'] as int
          : int.tryParse('${json['rank']}') ?? 0,
      displayLabel: json['displayLabel']?.toString() ?? '',
      masteryPoints: json['masteryPoints'] is int
          ? json['masteryPoints'] as int
          : int.tryParse('${json['masteryPoints']}') ?? 0,
    );
  }

  final int rank;
  final String displayLabel;
  final int masteryPoints;
}

class DesignStandings {
  const DesignStandings({
    required this.internalId,
    this.generationNumber,
    this.generationRoman,
    this.fillCurrent = 0,
    this.fillCap = 0,
    this.leaderWindowEndsAt,
    this.ranks = const [],
  });

  factory DesignStandings.fromJson(Map<String, dynamic> json) {
    final gen = json['generation'];
    final fill = json['fill'];
    final rawRanks = json['ranks'];
    return DesignStandings(
      internalId: json['internalId']?.toString() ?? '',
      generationNumber: gen is Map
          ? (gen['number'] is int
              ? gen['number'] as int
              : int.tryParse('${gen['number']}'))
          : null,
      generationRoman: gen is Map ? gen['roman']?.toString() : null,
      fillCurrent: fill is Map
          ? (fill['current'] is int
              ? fill['current'] as int
              : int.tryParse('${fill['current']}') ?? 0)
          : 0,
      fillCap: fill is Map
          ? (fill['cap'] is int
              ? fill['cap'] as int
              : int.tryParse('${fill['cap']}') ?? 0)
          : 0,
      leaderWindowEndsAt: json['leaderWindowEndsAt']?.toString(),
      ranks: rawRanks is List
          ? rawRanks
              .whereType<Map>()
              .map(
                (item) =>
                    StandingsRankEntry.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
          : const [],
    );
  }

  final String internalId;
  final int? generationNumber;
  final String? generationRoman;
  final int fillCurrent;
  final int fillCap;
  final String? leaderWindowEndsAt;
  final List<StandingsRankEntry> ranks;

  bool get isEmpty =>
      ranks.isEmpty && fillCurrent == 0 && fillCap == 0;
}
