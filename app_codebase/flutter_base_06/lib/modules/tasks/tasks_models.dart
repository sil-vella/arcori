import '../../core/media/catalog_media.dart';

export '../../core/media/catalog_media.dart';

/// Catalog section for the Tasks screen.
abstract final class TaskSections {
  static const dailyGoals = 'daily_goals';
  static const tasks = 'tasks';
}

class TaskContinueConfig {
  const TaskContinueConfig({
    this.enabled = false,
    this.currency = 'gold_arcori',
    this.cost = 0,
  });

  factory TaskContinueConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TaskContinueConfig();
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return TaskContinueConfig(
      enabled: json['enabled'] == true,
      currency: (json['currency']?.toString() ?? 'gold_arcori').trim(),
      cost: asInt(json['cost']),
    );
  }

  final bool enabled;
  final String currency;
  final int cost;
}

class TaskRewardConfig {
  const TaskRewardConfig({
    this.kind = 'deferred',
    this.placeholder = false,
    this.amount,
  });

  factory TaskRewardConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TaskRewardConfig();
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse('$v');
    }

    final kind = (json['kind']?.toString() ?? 'deferred').trim().toLowerCase();
    var amount = asInt(json['amount']);
    if (amount == null &&
        (kind == 'gold_fragments' || kind == 'mystery_box')) {
      amount = 2;
    }
    return TaskRewardConfig(
      kind: kind,
      placeholder: json['placeholder'] == true,
      amount: amount,
    );
  }

  final String kind;
  final bool placeholder;
  final int? amount;
}

/// Granted loot from POST /daily_goals/claim.
class TaskClaimReward {
  const TaskClaimReward({
    required this.kind,
    required this.amount,
    this.status = 'granted',
    this.goldArcori = 0,
    this.goldFragments = 0,
  });

  factory TaskClaimReward.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TaskClaimReward(kind: 'gold_fragments', amount: 0);
    }
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return TaskClaimReward(
      kind: (json['kind']?.toString() ?? 'gold_fragments').trim().toLowerCase(),
      amount: asInt(json['amount']),
      status: (json['status']?.toString() ?? 'granted').trim().toLowerCase(),
      goldArcori: asInt(json['goldArcori'] ?? json['gold_arcori']),
      goldFragments: asInt(json['goldFragments'] ?? json['gold_fragments']),
    );
  }

  final String kind;
  final int amount;
  final String status;
  final int goldArcori;
  final int goldFragments;
}

class TasksClaimResult {
  const TasksClaimResult({
    required this.progress,
    required this.reward,
  });

  final TasksProgressSnapshot progress;
  final TaskClaimReward reward;
}

/// Daily Cache claim_gate readiness for list / detail / post-match.
enum DailyCacheUiState { locked, ready, claimed }

DailyCacheUiState dailyCacheUiState({
  required TaskCatalogEntry? entry,
  required TasksProgressSnapshot? progress,
}) {
  final row = progress?.byGoalId(entry?.id ?? 'daily_mystery_box');
  if (row?.completedToday == true) return DailyCacheUiState.claimed;
  final requires = entry?.params['requires_goal_ids'] ??
      entry?.params['requiresGoalIds'];
  if (requires is List && progress != null) {
    for (final raw in requires) {
      final id = raw.toString().trim();
      if (id.isEmpty) continue;
      final req = progress.byGoalId(id);
      if (req == null || !req.completedToday) {
        return DailyCacheUiState.locked;
      }
    }
    return DailyCacheUiState.ready;
  }
  // No requirements listed — treat incomplete as ready to attempt claim.
  if (row != null && !row.completedToday) return DailyCacheUiState.ready;
  return DailyCacheUiState.locked;
}

String dailyCacheStatusLabel(DailyCacheUiState state) {
  switch (state) {
    case DailyCacheUiState.claimed:
      return 'Claimed';
    case DailyCacheUiState.ready:
      return 'Ready';
    case DailyCacheUiState.locked:
      return 'Locked';
  }
}

class TaskPostCompleteAction {
  const TaskPostCompleteAction({
    required this.type,
    this.screen,
    this.toPath,
    this.ctaLabel = 'Continue',
  });

  factory TaskPostCompleteAction.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TaskPostCompleteAction(type: 'none');
    }
    return TaskPostCompleteAction(
      type: (json['type']?.toString() ?? 'none').trim().toLowerCase(),
      screen: json['screen']?.toString().trim(),
      toPath: (json['toPath'] ?? json['to_path'])?.toString().trim(),
      ctaLabel:
          (json['ctaLabel'] ?? json['cta_label'])?.toString().trim().isNotEmpty ==
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

/// One catalog row (daily goal or task).
class TaskCatalogEntry {
  const TaskCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.section,
    this.cadence = 'daily',
    this.featured = false,
    this.taskType = '',
    this.params = const {},
    this.continueConfig = const TaskContinueConfig(),
    this.reward = const TaskRewardConfig(),
    this.media = const CatalogMediaMap(),
    this.postCompleteAction = const TaskPostCompleteAction(type: 'none'),
  });

  factory TaskCatalogEntry.fromJson(Map<String, dynamic> json) {
    final paramsRaw = json['params'];
    final sectionRaw =
        (json['section']?.toString() ?? '').trim().toLowerCase();
    final featured = json['featured'] == true;
    final section = sectionRaw == TaskSections.dailyGoals ||
            sectionRaw == TaskSections.tasks
        ? sectionRaw
        : (featured ? TaskSections.dailyGoals : TaskSections.tasks);
    return TaskCatalogEntry(
      id: json['id']?.toString().trim() ?? '',
      name: (json['name'] ?? json['id'])?.toString().trim() ?? '',
      description: json['description']?.toString() ?? '',
      section: section,
      cadence: (json['cadence']?.toString() ?? 'daily').trim().toLowerCase(),
      featured: featured,
      taskType: (json['taskType'] ?? json['task_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      params: paramsRaw is Map
          ? Map<String, dynamic>.from(paramsRaw)
          : const {},
      continueConfig: TaskContinueConfig.fromJson(
        json['continue'] is Map
            ? Map<String, dynamic>.from(json['continue'] as Map)
            : null,
      ),
      reward: TaskRewardConfig.fromJson(
        json['reward'] is Map
            ? Map<String, dynamic>.from(json['reward'] as Map)
            : null,
      ),
      media: CatalogMediaMap.fromJson(json['media']),
      postCompleteAction: TaskPostCompleteAction.fromJson(
        json['postCompleteAction'] is Map
            ? Map<String, dynamic>.from(json['postCompleteAction'] as Map)
            : json['post_complete_action'] is Map
                ? Map<String, dynamic>.from(
                    json['post_complete_action'] as Map,
                  )
                : null,
      ),
    );
  }

  final String id;
  final String name;
  final String description;
  final String section;
  final String cadence;
  final bool featured;
  final String taskType;
  final Map<String, dynamic> params;
  final TaskContinueConfig continueConfig;
  final TaskRewardConfig reward;
  final CatalogMediaMap media;
  final TaskPostCompleteAction postCompleteAction;

  bool get isDailyGoal => section == TaskSections.dailyGoals;
  bool get isTask => section == TaskSections.tasks;
}

class TasksCatalog {
  const TasksCatalog({
    required this.revision,
    required this.schemaVersion,
    required this.dayBoundary,
    required this.goals,
  });

  factory TasksCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['goals'];
    final list = <TaskCatalogEntry>[];
    if (raw is List) {
      final seen = <String>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final entry =
            TaskCatalogEntry.fromJson(Map<String, dynamic>.from(item));
        if (entry.id.isEmpty || !seen.add(entry.id)) continue;
        list.add(entry);
      }
    }
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 1;
    return TasksCatalog(
      revision: json['revision']?.toString() ?? '',
      schemaVersion: asInt(json['schemaVersion'] ?? json['schema_version']),
      dayBoundary:
          (json['dayBoundary'] ?? json['day_boundary'] ?? 'utc').toString(),
      goals: list,
    );
  }

  final String revision;
  final int schemaVersion;
  final String dayBoundary;
  final List<TaskCatalogEntry> goals;

  List<TaskCatalogEntry> get dailyGoals =>
      goals.where((g) => g.isDailyGoal).toList();

  List<TaskCatalogEntry> get tasks => goals.where((g) => g.isTask).toList();
}

class TaskProgressRow {
  const TaskProgressRow({
    required this.goalId,
    this.value = 0,
    this.dayKey,
    this.progressToday = 0,
    this.target = 1,
    this.completedToday = false,
    this.missPending = false,
    this.continueEnabled = false,
    this.continueCost = 0,
    this.taskType = '',
    this.featured = false,
    this.rewardKind = 'deferred',
  });

  factory TaskProgressRow.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return TaskProgressRow(
      goalId: (json['goalId'] ?? json['goal_id'] ?? '').toString().trim(),
      value: asInt(json['value']),
      dayKey: json['dayKey']?.toString() ?? json['day_key']?.toString(),
      progressToday: asInt(json['progressToday'] ?? json['progress_today']),
      target: asInt(json['target']).clamp(1, 999999),
      completedToday: json['completedToday'] == true ||
          json['completed_today'] == true,
      missPending:
          json['missPending'] == true || json['miss_pending'] == true,
      continueEnabled: json['continueEnabled'] == true ||
          json['continue_enabled'] == true,
      continueCost: asInt(json['continueCost'] ?? json['continue_cost']),
      taskType: (json['taskType'] ?? json['task_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      featured: json['featured'] == true,
      rewardKind: (json['rewardKind'] ?? json['reward_kind'] ?? 'deferred')
          .toString()
          .trim()
          .toLowerCase(),
    );
  }

  final String goalId;
  final int value;
  final String? dayKey;
  final int progressToday;
  final int target;
  final bool completedToday;
  final bool missPending;
  final bool continueEnabled;
  final int continueCost;
  final String taskType;
  final bool featured;
  final String rewardKind;

  double get progressFraction {
    if (completedToday) return 1;
    if (target <= 0) return 0;
    return (progressToday / target).clamp(0.0, 1.0);
  }

  String get progressLabel {
    if (missPending) return 'Missed — continue or reset';
    if (completedToday) return 'Done';
    return '$progressToday / $target';
  }
}

class TasksProgressSnapshot {
  const TasksProgressSnapshot({
    required this.revision,
    required this.dayKey,
    this.dayBoundary = 'utc',
    this.noMissStreak = 0,
    this.goldArcori = 0,
    this.goldFragments = 0,
    this.goals = const [],
  });

  factory TasksProgressSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['goals'];
    final list = <TaskProgressRow>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final row = TaskProgressRow.fromJson(Map<String, dynamic>.from(item));
        if (row.goalId.isEmpty) continue;
        list.add(row);
      }
    }
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return TasksProgressSnapshot(
      revision: json['revision']?.toString() ?? '',
      dayKey: (json['dayKey'] ?? json['day_key'] ?? '').toString(),
      dayBoundary:
          (json['dayBoundary'] ?? json['day_boundary'] ?? 'utc').toString(),
      noMissStreak: asInt(json['noMissStreak'] ?? json['no_miss_streak']),
      goldArcori: asInt(json['goldArcori'] ?? json['gold_arcori']),
      goldFragments: asInt(json['goldFragments'] ?? json['gold_fragments']),
      goals: list,
    );
  }

  final String revision;
  final String dayKey;
  final String dayBoundary;
  final int noMissStreak;
  final int goldArcori;
  final int goldFragments;
  final List<TaskProgressRow> goals;

  TaskProgressRow? byGoalId(String id) {
    final key = id.trim();
    for (final g in goals) {
      if (g.goalId == key) return g;
    }
    return null;
  }
}
