/// Museum browse models — closed Legacy generations (world archive).
library;

class MuseumItem {
  const MuseumItem({
    required this.designId,
    required this.displayName,
    required this.generationNumber,
    required this.legacyState,
    required this.historySummary,
    this.closedAt,
    this.actorUserId,
    this.actorDisplayName,
    this.actorRole,
    this.imageUrl,
    this.color,
    this.seriesKey,
    this.theme,
    this.id,
  });

  factory MuseumItem.fromJson(Map<String, dynamic> json) {
    final designId = json['designId']?.toString() ?? '';
    final name = json['displayName']?.toString().trim() ?? '';
    final genRaw = json['generationNumber'];
    final gen = genRaw is int
        ? genRaw
        : int.tryParse('${genRaw ?? ''}') ?? 0;
    return MuseumItem(
      designId: designId,
      displayName: name.isNotEmpty ? name : designId,
      generationNumber: gen,
      legacyState: (json['legacyState']?.toString() ?? '').toLowerCase(),
      historySummary: json['historySummary']?.toString() ?? '',
      closedAt: json['closedAt']?.toString(),
      actorUserId: json['actorUserId']?.toString(),
      actorDisplayName: json['actorDisplayName']?.toString(),
      actorRole: json['actorRole']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      color: json['color']?.toString(),
      seriesKey: json['seriesKey']?.toString(),
      theme: json['theme']?.toString(),
      id: json['id']?.toString(),
    );
  }

  final String designId;
  final String displayName;
  final int generationNumber;
  final String legacyState;
  final String historySummary;
  final String? closedAt;
  final String? actorUserId;
  final String? actorDisplayName;
  final String? actorRole;
  final String? imageUrl;
  final String? color;
  final String? seriesKey;
  final String? theme;
  final String? id;

  bool get isPreserved => legacyState == 'preserved';
  bool get isLost => legacyState == 'lost';

  String get outcomeLabel {
    if (isPreserved) return 'Preserved';
    if (isLost) return 'Lost';
    return legacyState;
  }

  String get genCaption {
    final outcome = outcomeLabel.trim();
    if (outcome.isEmpty) return 'Gen $generationNumber';
    return 'Gen $generationNumber · $outcome';
  }
}

class MuseumListPage {
  const MuseumListPage({
    required this.items,
    this.nextCursor,
  });

  factory MuseumListPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <MuseumItem>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) {
          items.add(MuseumItem.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    final cursor = json['nextCursor']?.toString().trim();
    return MuseumListPage(
      items: items,
      nextCursor: (cursor != null && cursor.isNotEmpty) ? cursor : null,
    );
  }

  final List<MuseumItem> items;
  final String? nextCursor;
}

class MuseumBannerPage {
  const MuseumBannerPage({this.items = const []});

  final List<MuseumItem> items;

  MuseumItem? get item => items.isEmpty ? null : items.first;
}

class MuseumSeriesOption {
  const MuseumSeriesOption({
    required this.key,
    required this.label,
  });

  factory MuseumSeriesOption.fromJson(Map<String, dynamic> json) {
    final key = json['key']?.toString().trim() ?? '';
    final label = json['label']?.toString().trim() ?? '';
    return MuseumSeriesOption(
      key: key,
      label: label.isNotEmpty ? label : key,
    );
  }

  final String key;
  final String label;
}

class MuseumSeriesPage {
  const MuseumSeriesPage({required this.series});

  factory MuseumSeriesPage.fromJson(Map<String, dynamic> json) {
    final raw = json['series'];
    final series = <MuseumSeriesOption>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) {
          series.add(
            MuseumSeriesOption.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
    }
    return MuseumSeriesPage(series: series);
  }

  final List<MuseumSeriesOption> series;
}
