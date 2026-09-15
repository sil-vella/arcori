/// Shared catalog media refs for goals / achievements / tasks.
///
/// Flat slots: `{ "type": "image", "value": "/catalog-media/..." }`
/// Post-completion group under [postTaskKey] with multiple named clips.
library;

const String kCatalogMediaPostTaskKey = 'post_task';

/// One media leaf: type (image|lottie|audio|…) + value (path/url).
class CatalogMediaRef {
  const CatalogMediaRef({required this.type, required this.value});

  factory CatalogMediaRef.fromJson(Map<String, dynamic> json) {
    return CatalogMediaRef(
      type: (json['type'] ?? json['mediaType'] ?? json['media_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      value: (json['value'] ?? json['url'] ?? json['path'] ?? '')
          .toString()
          .trim(),
    );
  }

  final String type;
  final String value;

  bool get isValid => type.isNotEmpty && value.isNotEmpty;
}

/// Parsed media map: flat slots + optional [postTask] nested slots.
class CatalogMediaMap {
  const CatalogMediaMap({
    this.slots = const {},
    this.postTask = const {},
  });

  factory CatalogMediaMap.fromJson(dynamic raw) {
    if (raw is! Map) return const CatalogMediaMap();
    final slots = <String, CatalogMediaRef>{};
    final postTask = <String, CatalogMediaRef>{};

    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      final lower = key.toLowerCase();
      if (lower == kCatalogMediaPostTaskKey ||
          lower == 'post_achieve' ||
          lower == 'post_goal' ||
          lower == 'posttask' ||
          lower == 'postachieve' ||
          lower == 'postgoal') {
        _parsePostTaskGroup(entry.value, postTask);
        continue;
      }
      if (entry.value is Map) {
        final ref = CatalogMediaRef.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (ref.isValid) {
          slots[key] = ref;
        }
      }
    }
    return CatalogMediaMap(slots: slots, postTask: postTask);
  }

  final Map<String, CatalogMediaRef> slots;
  final Map<String, CatalogMediaRef> postTask;

  bool get isEmpty => slots.isEmpty && postTask.isEmpty;
  bool get isNotEmpty => !isEmpty;

  CatalogMediaRef? operator [](String key) {
    if (key == kCatalogMediaPostTaskKey) return null;
    return slots[key];
  }

  CatalogMediaRef? postTaskSlot(String key) => postTask[key];
}

void _parsePostTaskGroup(dynamic raw, Map<String, CatalogMediaRef> out) {
  if (raw is Map) {
    // Single leaf under post_task → "primary".
    final asLeaf = CatalogMediaRef.fromJson(Map<String, dynamic>.from(raw));
    final hasNestedLeaves = raw.values.any((v) => v is Map);
    if (asLeaf.isValid &&
        (raw.containsKey('type') ||
            raw.containsKey('mediaType') ||
            raw.containsKey('media_type')) &&
        !hasNestedLeaves) {
      out['primary'] = asLeaf;
      return;
    }
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty || entry.value is! Map) continue;
      final ref = CatalogMediaRef.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
      if (ref.isValid) out[key] = ref;
    }
    return;
  }
  if (raw is List) {
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final ref = CatalogMediaRef.fromJson(map);
      if (!ref.isValid) continue;
      final key = (map['key'] ?? map['name'] ?? 'item_$i').toString().trim();
      out[key.isEmpty ? 'item_$i' : key] = ref;
    }
  }
}
