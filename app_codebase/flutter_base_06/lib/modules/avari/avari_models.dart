/// Avari profile models (identity + game stubs).
library;

class AvariIdentity {
  const AvariIdentity({
    required this.userId,
    required this.displayName,
    required this.title,
    required this.accountType,
    this.email,
    this.avatarUrl,
  });

  factory AvariIdentity.fromJson(Map<String, dynamic> json) {
    return AvariIdentity(
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Avari',
      email: json['email']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      accountType: json['accountType']?.toString() ?? 'Regular',
      title: json['title']?.toString() ?? 'Avari',
    );
  }

  final String userId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String accountType;
  final String title;
}

class AvariRank {
  const AvariRank({
    required this.xp,
    required this.level,
    this.label,
  });

  factory AvariRank.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AvariRank(xp: 0, level: 1);
    }
    return AvariRank(
      xp: json['xp'] is int ? json['xp'] as int : int.tryParse('${json['xp']}') ?? 0,
      level: json['level'] is int
          ? json['level'] as int
          : int.tryParse('${json['level']}') ?? 1,
      label: json['label']?.toString(),
    );
  }

  final int xp;
  final int level;
  final String? label;
}

class AvariMasterySummary {
  const AvariMasterySummary({
    this.designsTracked = 0,
    this.top = const [],
    this.masteryValueLabel = 'Fair',
  });

  factory AvariMasterySummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AvariMasterySummary();
    final rawTop = json['top'];
    final rawLabel = json['masteryValueLabel']?.toString().trim() ?? '';
    return AvariMasterySummary(
      designsTracked: json['designsTracked'] is int
          ? json['designsTracked'] as int
          : int.tryParse('${json['designsTracked']}') ?? 0,
      top: rawTop is List
          ? rawTop.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const [],
      masteryValueLabel: rawLabel.isNotEmpty ? rawLabel : 'Fair',
    );
  }

  final int designsTracked;
  final List<String> top;

  /// Fair … Priceless — computed on the backend from Mastery Value / circulating N.
  final String masteryValueLabel;
}

class AvariStats {
  const AvariStats({
    this.matchesPlayed = 0,
    this.wins = 0,
    this.flips = 0,
  });

  factory AvariStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AvariStats();
    int asInt(Object? v) =>
        v is int ? v : int.tryParse('$v') ?? 0;
    return AvariStats(
      matchesPlayed: asInt(json['matchesPlayed']),
      wins: asInt(json['wins']),
      flips: asInt(json['flips']),
    );
  }

  final int matchesPlayed;
  final int wins;
  final int flips;
}

/// Wallet currency only (not catalog / not playable).
class AvariEconomy {
  const AvariEconomy({
    this.goldArcori = 0,
    this.goldFragments = 0,
  });

  factory AvariEconomy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AvariEconomy();
    int asInt(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    return AvariEconomy(
      goldArcori: asInt(json['goldArcori']),
      goldFragments: asInt(json['goldFragments']),
    );
  }

  final int goldArcori;
  final int goldFragments;
}

/// Catalog slam stats (1–10). Recovery is shown on profile even though slam does not use it yet.
class SlammerGameplayAttributes {
  const SlammerGameplayAttributes({
    this.impact,
    this.precision,
    this.control,
    this.recovery,
    this.spread,
  });

  static const List<(String key, String label)> displayOrder = [
    ('impact', 'Impact'),
    ('precision', 'Precision'),
    ('control', 'Control'),
    ('recovery', 'Recovery'),
    ('spread', 'Spread'),
  ];

  static SlammerGameplayAttributes? tryParse(Object? raw) {
    if (raw is! Map) return null;
    int? parseOne(Object? value) {
      if (value == null || value is bool) return null;
      int? n;
      if (value is int) {
        n = value;
      } else if (value is num) {
        n = value.toInt();
      } else {
        n = int.tryParse(value.toString().trim());
      }
      if (n == null) return null;
      if (n < 1) return 1;
      if (n > 10) return 10;
      return n;
    }

    final parsed = SlammerGameplayAttributes(
      impact: parseOne(raw['impact']),
      precision: parseOne(raw['precision']),
      control: parseOne(raw['control']),
      recovery: parseOne(raw['recovery']),
      spread: parseOne(raw['spread']),
    );
    if (parsed.labeledValues.isEmpty) return null;
    return parsed;
  }

  final int? impact;
  final int? precision;
  final int? control;
  final int? recovery;
  final int? spread;

  /// GDD order: Impact, Precision, Control, Recovery, Spread.
  List<(String label, int value)> get labeledValues {
    final byKey = <String, int?>{
      'impact': impact,
      'precision': precision,
      'control': control,
      'recovery': recovery,
      'spread': spread,
    };
    return [
      for (final entry in displayOrder)
        if (byKey[entry.$1] != null) (entry.$2, byKey[entry.$1]!),
    ];
  }
}

/// Circulating Arcori access or owned slammer — catalog face fields included.
class AvariInventoryItem {
  const AvariInventoryItem({
    required this.designId,
    required this.displayName,
    this.imageUrl,
    this.lottieUrl,
    this.faceMedia,
    this.background,
    this.color,
    this.source,
    this.permanent,
    this.chargesRemaining,
    this.gameplayAttributes,
    this.masteryPoints = 0,
    this.mintReach,
  });

  factory AvariInventoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['designId']?.toString() ?? '';
    final name = json['displayName']?.toString().trim() ?? '';
    final mintRaw = json['mintReach'];
    int? mintReach;
    if (mintRaw is int) {
      mintReach = mintRaw > 0 ? mintRaw : null;
    } else {
      final parsed = int.tryParse('${mintRaw ?? ''}');
      mintReach = (parsed != null && parsed > 0) ? parsed : null;
    }
    final bg = json['background'];
    return AvariInventoryItem(
      designId: id,
      displayName: name.isNotEmpty ? name : id,
      imageUrl: json['imageUrl']?.toString(),
      lottieUrl: json['lottieUrl']?.toString(),
      faceMedia: json['faceMedia']?.toString(),
      background: bg is Map ? Map<String, dynamic>.from(bg) : null,
      color: json['color']?.toString(),
      source: json['source']?.toString(),
      permanent: json['permanent'] is bool ? json['permanent'] as bool : null,
      chargesRemaining: json['chargesRemaining'] is int
          ? json['chargesRemaining'] as int
          : int.tryParse('${json['chargesRemaining'] ?? ''}'),
      gameplayAttributes: SlammerGameplayAttributes.tryParse(
        json['gameplayAttributes'],
      ),
      masteryPoints: json['masteryPoints'] is int
          ? json['masteryPoints'] as int
          : int.tryParse('${json['masteryPoints'] ?? ''}') ?? 0,
      mintReach: mintReach,
    );
  }

  final String designId;
  final String displayName;
  final String? imageUrl;

  /// Kin (and future Lottie faces) — public media URL.
  final String? lottieUrl;

  /// `webp` | `lottie` when known.
  final String? faceMedia;

  /// Kin disc background (claim JSON) when face is Lottie.
  final Map<String, dynamic>? background;
  final String? color;
  final String? source;
  final bool? permanent;
  final int? chargesRemaining;
  final SlammerGameplayAttributes? gameplayAttributes;
  final int masteryPoints;

  /// Catalog `legacy.preservationRequirement` — mint reach for this design.
  final int? mintReach;

  bool get hasLottieFace {
    final media = faceMedia?.trim().toLowerCase();
    if (media == 'lottie') return true;
    final url = lottieUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  /// Profile label: mastery / mint reach (e.g. `3/500`).
  String get masteryOverMintReach {
    final reach = mintReach;
    if (reach == null) return '$masteryPoints';
    return '$masteryPoints/$reach';
  }
}

/// Server Genesis Kin (player_kin + catalog_design summary fields).
class AvariKin {
  const AvariKin({
    required this.subtheme,
    required this.style,
    required this.finish,
    required this.effect,
    required this.genesisDesignId,
    required this.chosenName,
    this.customization = const {},
    this.regionCode,
    this.color,
    this.series,
    this.generationRoman,
    this.generationNumber,
    this.lottieUrl,
    this.catalogDesign,
    this.masteryPoints = 0,
    this.mintReach,
  });

  factory AvariKin.fromJson(Map<String, dynamic> json) {
    final gen = json['generation'];
    Map<String, dynamic>? genMap;
    if (gen is Map) {
      genMap = Map<String, dynamic>.from(gen);
    }
    final custom = json['customization'];
    final design = json['catalogDesign'];
    String? regionFromDesign;
    String? colorFromDesign;
    String? seriesFromDesign;
    String? romanFromDesign;
    int? mintFromDesign;
    if (design is Map) {
      colorFromDesign = design['color']?.toString();
      seriesFromDesign = design['series']?.toString();
      final loc = design['location'];
      if (loc is Map) {
        regionFromDesign = loc['regionCode']?.toString();
      }
      final dGen = design['generation'];
      if (dGen is Map) {
        romanFromDesign = dGen['roman']?.toString();
      }
      final legacy = design['legacy'];
      if (legacy is Map) {
        final raw = legacy['preservationRequirement'];
        if (raw is int && raw > 0) {
          mintFromDesign = raw;
        } else {
          final parsed = int.tryParse('${raw ?? ''}');
          if (parsed != null && parsed > 0) mintFromDesign = parsed;
        }
      }
    }
    final mintRaw = json['mintReach'];
    int? mintReach;
    if (mintRaw is int) {
      mintReach = mintRaw > 0 ? mintRaw : null;
    } else {
      final parsed = int.tryParse('${mintRaw ?? ''}');
      mintReach = (parsed != null && parsed > 0) ? parsed : mintFromDesign;
    }
    return AvariKin(
      subtheme: json['subtheme']?.toString() ?? '',
      style: json['style']?.toString() ?? 'Chibi',
      finish: json['finish']?.toString() ?? 'Standard',
      effect: json['effect']?.toString() ?? 'None',
      genesisDesignId: json['genesisDesignId']?.toString() ?? '',
      chosenName: json['chosenName']?.toString() ?? '',
      customization: custom is Map
          ? Map<String, dynamic>.from(custom)
          : const {},
      regionCode: json['regionCode']?.toString() ?? regionFromDesign,
      color: json['color']?.toString() ?? colorFromDesign,
      series: json['series']?.toString() ?? seriesFromDesign,
      generationRoman: genMap?['roman']?.toString() ?? romanFromDesign,
      generationNumber: genMap?['number'] is int
          ? genMap!['number'] as int
          : int.tryParse('${genMap?['number'] ?? ''}'),
      lottieUrl: json['lottieUrl']?.toString(),
      catalogDesign:
          design is Map ? Map<String, dynamic>.from(design) : null,
      masteryPoints: json['masteryPoints'] is int
          ? json['masteryPoints'] as int
          : int.tryParse('${json['masteryPoints'] ?? ''}') ?? 0,
      mintReach: mintReach,
    );
  }

  final String subtheme;
  final String style;
  final String finish;
  final String effect;
  final String genesisDesignId;
  final String chosenName;
  final Map<String, dynamic> customization;
  final String? regionCode;
  final String? color;
  final String? series;
  final String? generationRoman;
  final int? generationNumber;
  final String? lottieUrl;
  final Map<String, dynamic>? catalogDesign;
  final int masteryPoints;
  final int? mintReach;

  String get masteryOverMintReach {
    final reach = mintReach ?? 500;
    return '$masteryPoints/$reach';
  }

  Map<String, dynamic>? get background {
    final raw = customization['background'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String? get backgroundImageUrl {
    final url = background?['imageUrl']?.toString().trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  String? get backgroundColorHex {
    final hex = background?['colorHex']?.toString().trim();
    if (hex == null || hex.isEmpty) return null;
    return hex;
  }
}

class AvariProfile {
  const AvariProfile({
    required this.identity,
    required this.rank,
    required this.titles,
    required this.mastery,
    required this.stats,
    this.economy = const AvariEconomy(),
    this.kin,
    this.access = const [],
    this.slammers = const [],
  });

  factory AvariProfile.fromJson(Map<String, dynamic> json) {
    final identityRaw = json['identity'];
    final titlesRaw = json['titles'];
    List<AvariInventoryItem> parseItems(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => AvariInventoryItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.designId.isNotEmpty)
          .toList();
    }

    AvariKin? kin;
    final kinRaw = json['kin'];
    if (kinRaw is Map) {
      kin = AvariKin.fromJson(Map<String, dynamic>.from(kinRaw));
    }

    return AvariProfile(
      identity: identityRaw is Map
          ? AvariIdentity.fromJson(Map<String, dynamic>.from(identityRaw))
          : const AvariIdentity(
              userId: '',
              displayName: 'Avari',
              title: 'Avari',
              accountType: 'Regular',
            ),
      rank: AvariRank.fromJson(
        json['rank'] is Map
            ? Map<String, dynamic>.from(json['rank'] as Map)
            : null,
      ),
      titles: titlesRaw is List
          ? titlesRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const ['Avari'],
      kin: kin,
      mastery: AvariMasterySummary.fromJson(
        json['mastery'] is Map
            ? Map<String, dynamic>.from(json['mastery'] as Map)
            : null,
      ),
      stats: AvariStats.fromJson(
        json['stats'] is Map
            ? Map<String, dynamic>.from(json['stats'] as Map)
            : null,
      ),
      economy: AvariEconomy.fromJson(
        json['economy'] is Map
            ? Map<String, dynamic>.from(json['economy'] as Map)
            : null,
      ),
      access: parseItems(json['access']),
      slammers: parseItems(json['slammers']),
    );
  }

  final AvariIdentity identity;
  final AvariRank rank;
  final List<String> titles;
  final AvariKin? kin;
  final AvariMasterySummary mastery;
  final AvariStats stats;
  final AvariEconomy economy;
  final List<AvariInventoryItem> access;
  final List<AvariInventoryItem> slammers;
}

/// One design mastery delta from match finalize.
class MasteryChange {
  const MasteryChange({
    required this.designId,
    required this.delta,
    required this.pointsBefore,
    required this.pointsAfter,
    required this.flips,
    required this.kind,
    this.mintReach,
    this.displayName,
    this.imageUrl,
    this.color,
    this.generationNumber = 1,
  });

  factory MasteryChange.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    final mintRaw = json['mintReach'];
    int? mintReach;
    if (mintRaw is int) {
      mintReach = mintRaw > 0 ? mintRaw : null;
    } else {
      final parsed = int.tryParse('${mintRaw ?? ''}');
      mintReach = (parsed != null && parsed > 0) ? parsed : null;
    }
    final name = json['displayName']?.toString().trim() ?? '';
    final id = json['designId']?.toString() ?? '';
    return MasteryChange(
      designId: id,
      delta: asInt(json['delta']),
      pointsBefore: asInt(json['pointsBefore']),
      pointsAfter: asInt(json['pointsAfter']),
      flips: asInt(json['flips']),
      kind: json['kind']?.toString() ?? 'own',
      mintReach: mintReach,
      displayName: name.isNotEmpty ? name : (id.isNotEmpty ? id : null),
      imageUrl: json['imageUrl']?.toString(),
      color: json['color']?.toString(),
      generationNumber: asInt(json['generationNumber']).clamp(1, 9999),
    );
  }

  final String designId;
  final int delta;
  final int pointsBefore;
  final int pointsAfter;
  final int flips;
  final String kind;
  final int? mintReach;
  final String? displayName;
  final String? imageUrl;
  final String? color;
  final int generationNumber;

  String get masteryOverMintReach {
    final reach = mintReach;
    if (reach == null) return '$pointsAfter';
    return '$pointsAfter/$reach';
  }

  String get relativeDeltaLabel {
    final sign = delta >= 0 ? '+' : '';
    return '$sign$delta';
  }
}

/// Payload from `POST /authuser/avari/match/finalize`.
class MatchFinalizeResult {
  const MatchFinalizeResult({
    required this.applied,
    required this.reason,
    required this.matchId,
    this.goldFragmentsDelta = 0,
    this.goldArcoriDelta = 0,
    this.goldFragments = 0,
    this.goldArcori = 0,
    this.feeFragments = 0,
    this.flipsRewarded = 0,
    this.rankXpDelta = 0,
    this.masteryChanges = const [],
    this.daily,
    this.mint,
  });

  factory MatchFinalizeResult.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['masteryChanges'];
    int asInt(dynamic v) =>
        v is int ? v : int.tryParse('$v') ?? 0;
    return MatchFinalizeResult(
      applied: json['applied'] == true,
      reason: json['reason']?.toString() ?? '',
      matchId: json['matchId']?.toString() ?? '',
      goldFragmentsDelta: asInt(json['goldFragmentsDelta']),
      goldArcoriDelta: asInt(json['goldArcoriDelta']),
      goldFragments: asInt(json['goldFragments']),
      goldArcori: asInt(json['goldArcori']),
      feeFragments: asInt(json['feeFragments']),
      flipsRewarded: asInt(json['flipsRewarded']),
      rankXpDelta: asInt(json['rankXpDelta']),
      masteryChanges: rawChanges is List
          ? rawChanges
              .whereType<Map>()
              .map((e) => MasteryChange.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      daily: json['daily'] is Map
          ? Map<String, dynamic>.from(json['daily'] as Map)
          : null,
      mint: json['mint'] is Map
          ? Map<String, dynamic>.from(json['mint'] as Map)
          : null,
    );
  }

  final bool applied;
  final String reason;
  final String matchId;
  final int goldFragmentsDelta;
  final int goldArcoriDelta;
  final int goldFragments;
  final int goldArcori;
  final int feeFragments;
  final int flipsRewarded;
  final int rankXpDelta;
  final List<MasteryChange> masteryChanges;
  final Map<String, dynamic>? daily;
  final Map<String, dynamic>? mint;
}
