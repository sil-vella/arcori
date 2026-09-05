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
  });

  factory AvariMasterySummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AvariMasterySummary();
    final rawTop = json['top'];
    return AvariMasterySummary(
      designsTracked: json['designsTracked'] is int
          ? json['designsTracked'] as int
          : int.tryParse('${json['designsTracked']}') ?? 0,
      top: rawTop is List
          ? rawTop.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const [],
    );
  }

  final int designsTracked;
  final List<String> top;
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

/// Circulating Arcori access or owned slammer — catalog face fields included.
class AvariInventoryItem {
  const AvariInventoryItem({
    required this.designId,
    required this.displayName,
    this.imageUrl,
    this.color,
    this.source,
    this.permanent,
    this.chargesRemaining,
  });

  factory AvariInventoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['designId']?.toString() ?? '';
    final name = json['displayName']?.toString().trim() ?? '';
    return AvariInventoryItem(
      designId: id,
      displayName: name.isNotEmpty ? name : id,
      imageUrl: json['imageUrl']?.toString(),
      color: json['color']?.toString(),
      source: json['source']?.toString(),
      permanent: json['permanent'] is bool ? json['permanent'] as bool : null,
      chargesRemaining: json['chargesRemaining'] is int
          ? json['chargesRemaining'] as int
          : int.tryParse('${json['chargesRemaining'] ?? ''}'),
    );
  }

  final String designId;
  final String displayName;
  final String? imageUrl;
  final String? color;
  final String? source;
  final bool? permanent;
  final int? chargesRemaining;
}

class AvariProfile {
  const AvariProfile({
    required this.identity,
    required this.rank,
    required this.titles,
    required this.mastery,
    required this.stats,
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
      kin: json['kin'],
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
      access: parseItems(json['access']),
      slammers: parseItems(json['slammers']),
    );
  }

  final AvariIdentity identity;
  final AvariRank rank;
  final List<String> titles;
  final Object? kin;
  final AvariMasterySummary mastery;
  final AvariStats stats;
  final List<AvariInventoryItem> access;
  final List<AvariInventoryItem> slammers;
}
