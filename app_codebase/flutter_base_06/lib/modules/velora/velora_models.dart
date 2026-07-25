/// Catalog design models for Velora browse + Arcori Detail.
library;

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

class DesignSummary {
  const DesignSummary({
    required this.internalId,
    this.design,
    this.theme,
    this.subtheme,
    this.themeCode,
    this.printedRarity,
    this.series,
    this.seriesKey,
    this.worldState,
    this.seasonState,
    this.type,
    this.imageUrl,
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
      series: json['series']?.toString(),
      seriesKey: json['seriesKey']?.toString(),
      worldState: json['worldState']?.toString(),
      seasonState: json['seasonState']?.toString(),
      type: json['type']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
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
  final String? series;
  final String? seriesKey;
  final String? worldState;
  final String? seasonState;
  final String? type;
  final String? imageUrl;
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
    this.series,
    this.seriesKey,
    this.worldState,
    this.seasonState,
    this.type,
    this.imageUrl,
    this.loreDescription,
    this.generation,
  });

  factory DesignDetail.fromJson(Map<String, dynamic> json) {
    final gen = json['generation'];
    return DesignDetail(
      internalId: json['internalId']?.toString() ?? '',
      design: json['design']?.toString(),
      theme: json['theme']?.toString(),
      subtheme: json['subtheme']?.toString(),
      themeCode: json['themeCode']?.toString(),
      printedRarity: json['printedRarity']?.toString(),
      series: json['series']?.toString(),
      seriesKey: json['seriesKey']?.toString(),
      worldState: json['worldState']?.toString(),
      seasonState: json['seasonState']?.toString(),
      type: json['type']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      loreDescription: json['loreDescription']?.toString(),
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
  final String? series;
  final String? seriesKey;
  final String? worldState;
  final String? seasonState;
  final String? type;
  final String? imageUrl;
  final String? loreDescription;
  final DesignGeneration? generation;

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
