/// Wire models for achievements catalog + unlock rows from finalize.

import '../../core/media/catalog_media.dart';

export '../../core/media/catalog_media.dart';

class PostAchieveAction {
  const PostAchieveAction({
    required this.type,
    this.screen,
    this.toPath,
    this.ctaLabel = 'Continue',
  });

  factory PostAchieveAction.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PostAchieveAction(type: PostAchieveActionTypes.none);
    }
    return PostAchieveAction(
      type: (json['type']?.toString() ?? PostAchieveActionTypes.none)
          .trim()
          .toLowerCase(),
      screen: json['screen']?.toString().trim(),
      toPath: (json['toPath'] ?? json['to_path'])?.toString().trim(),
      ctaLabel: (json['ctaLabel'] ?? json['cta_label'])?.toString().trim().isNotEmpty ==
              true
          ? (json['ctaLabel'] ?? json['cta_label']).toString().trim()
          : 'Continue',
    );
  }

  final String type;
  final String? screen;
  final String? toPath;
  final String ctaLabel;
}

abstract final class PostAchieveActionTypes {
  static const none = 'none';
  static const moveToScreen = 'move_to_screen';
  static const openPath = 'open_path';
}

class AchievementEntry {
  const AchievementEntry({
    required this.id,
    required this.achievementName,
    required this.description,
    required this.achievementType,
    this.params = const {},
    this.media = const CatalogMediaMap(),
    this.postAchieveAction = const PostAchieveAction(
      type: PostAchieveActionTypes.none,
    ),
  });

  factory AchievementEntry.fromJson(Map<String, dynamic> json) {
    final paramsRaw = json['params'];
    return AchievementEntry(
      id: json['id']?.toString().trim() ?? '',
      achievementName:
          (json['achievementName'] ?? json['achievement_name'] ?? json['id'])
                  ?.toString()
                  .trim() ??
              '',
      description: json['description']?.toString() ?? '',
      achievementType:
          (json['achievementType'] ?? json['achievement_type'] ?? '')
              .toString()
              .trim()
              .toLowerCase(),
      params: paramsRaw is Map
          ? Map<String, dynamic>.from(paramsRaw)
          : const {},
      media: CatalogMediaMap.fromJson(json['media']),
      postAchieveAction: PostAchieveAction.fromJson(
        json['postAchieveAction'] is Map
            ? Map<String, dynamic>.from(json['postAchieveAction'] as Map)
            : json['post_achieve_action'] is Map
                ? Map<String, dynamic>.from(json['post_achieve_action'] as Map)
                : null,
      ),
    );
  }

  final String id;
  final String achievementName;
  final String description;
  final String achievementType;
  final Map<String, dynamic> params;
  final CatalogMediaMap media;
  final PostAchieveAction postAchieveAction;

  CatalogMediaRef? mediaSlot(String key) => media[key];
  CatalogMediaRef? postTaskMedia(String key) => media.postTaskSlot(key);
}

class AchievementsCatalog {
  const AchievementsCatalog({
    required this.revision,
    required this.schemaVersion,
    required this.achievements,
  });

  factory AchievementsCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['achievements'];
    final list = <AchievementEntry>[];
    if (raw is List) {
      final seen = <String>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final entry =
            AchievementEntry.fromJson(Map<String, dynamic>.from(item));
        if (entry.id.isEmpty || !seen.add(entry.id)) continue;
        list.add(entry);
      }
    }
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 1;
    return AchievementsCatalog(
      revision: json['revision']?.toString() ?? '',
      schemaVersion: asInt(json['schemaVersion'] ?? json['schema_version']),
      achievements: list,
    );
  }

  final String revision;
  final int schemaVersion;
  final List<AchievementEntry> achievements;
}
