import 'package:flutter/foundation.dart';

import 'tasks_models.dart';

/// In-memory daily goals + tasks catalog and progress.
class TasksStore {
  TasksStore._();

  static final ValueNotifier<int> changeVersion = ValueNotifier<int>(0);

  static String _revision = '';
  static final List<TaskCatalogEntry> _entries = [];
  static TasksProgressSnapshot? _progress;
  static bool _hasDocument = false;

  static bool get hasDocument => _hasDocument;
  static String get revision => _revision;
  static TasksProgressSnapshot? get progress => _progress;

  static List<TaskCatalogEntry> get all =>
      List<TaskCatalogEntry>.unmodifiable(_entries);

  static List<TaskCatalogEntry> get dailyGoals =>
      _entries.where((e) => e.isDailyGoal).toList();

  static List<TaskCatalogEntry> get tasks =>
      _entries.where((e) => e.isTask).toList();

  static void applyCatalog(TasksCatalog catalog) {
    _entries
      ..clear()
      ..addAll(catalog.goals);
    _revision = catalog.revision;
    _hasDocument = catalog.goals.isNotEmpty;
    changeVersion.value++;
  }

  static void applyProgress(TasksProgressSnapshot snapshot) {
    _progress = snapshot;
    changeVersion.value++;
  }

  static TaskCatalogEntry? byId(String id) {
    final key = id.trim();
    if (key.isEmpty) return null;
    for (final e in _entries) {
      if (e.id == key) return e;
    }
    return null;
  }

  static TaskProgressRow? progressFor(String id) =>
      _progress?.byGoalId(id);

  static void clear() {
    _entries.clear();
    _progress = null;
    _revision = '';
    _hasDocument = false;
    changeVersion.value++;
  }
}
