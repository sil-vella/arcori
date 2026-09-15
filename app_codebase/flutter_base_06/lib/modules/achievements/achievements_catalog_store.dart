import 'package:flutter/foundation.dart';

import 'achievements_models.dart';

/// In-memory achievements catalog from server JSON.
class AchievementsCatalogStore {
  AchievementsCatalogStore._();

  static final ValueNotifier<int> changeVersion = ValueNotifier<int>(0);

  static String _revision = '';
  static final List<AchievementEntry> _entries = [];
  static final Set<String> _unlockedIds = {};

  static bool _hasDocument = false;
  static bool get hasDocument => _hasDocument;
  static String get revision => _revision;

  static List<AchievementEntry> get all =>
      List<AchievementEntry>.unmodifiable(_entries);

  static Set<String> get unlockedIds => Set.unmodifiable(_unlockedIds);

  static void applyCatalog(AchievementsCatalog catalog) {
    _entries
      ..clear()
      ..addAll(catalog.achievements);
    _revision = catalog.revision;
    _hasDocument = catalog.achievements.isNotEmpty;
    changeVersion.value++;
  }

  static void applyUnlockedIds(Iterable<String> ids) {
    _unlockedIds
      ..clear()
      ..addAll(ids.where((e) => e.trim().isNotEmpty));
    changeVersion.value++;
  }

  static void markUnlocked(Iterable<String> ids) {
    var changed = false;
    for (final id in ids) {
      final key = id.trim();
      if (key.isEmpty) continue;
      if (_unlockedIds.add(key)) changed = true;
    }
    if (changed) changeVersion.value++;
  }

  static AchievementEntry? byId(String id) {
    final key = id.trim();
    if (key.isEmpty) return null;
    for (final e in _entries) {
      if (e.id == key) return e;
    }
    return null;
  }

  static String displayName(String id) {
    final entry = byId(id);
    if (entry != null && entry.achievementName.isNotEmpty) {
      return entry.achievementName;
    }
    return id;
  }

  static bool isUnlocked(String id) => _unlockedIds.contains(id.trim());

  static void clear() {
    _entries.clear();
    _unlockedIds.clear();
    _revision = '';
    _hasDocument = false;
    changeVersion.value++;
  }
}
