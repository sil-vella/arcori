import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/http/media_url.dart';
import '../../core/modal/modal.dart';
import '../../core/theme/theme.dart';
import '../../utils/dev_logger.dart';
import 'post_complete_action_executor.dart';
import 'tasks_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Sequential daily-goal / task completion celebrations (same shell as achievements).
Future<void> showDailyGoalCompleteSequence(
  BuildContext context, {
  required List<TaskCatalogEntry> completed,
}) async {
  if (completed.isEmpty) return;

  for (final entry in completed) {
    if (!context.mounted) return;
    if (LOGGING_SWITCH) {
      customlog('tasks: celebrate complete id=${entry.id}');
    }
    await AppModal.showCenteredShell<void>(
      context,
      title: entry.isDailyGoal ? 'Daily goal complete' : 'Task complete',
      barrierDismissible: false,
      showCloseButton: false,
      child: DailyGoalCompleteCelebrateBody(
        entry: entry,
        onContinue: () async {
          AppModal.dismiss(context);
          final action = entry.postCompleteAction;
          final hasNav = action.type != 'none' &&
              ((action.screen?.isNotEmpty ?? false) ||
                  (action.toPath?.isNotEmpty ?? false));
          if (hasNav && context.mounted) {
            await executePostCompleteAction(
              context: context,
              action: action,
            );
          }
        },
        onDismiss: () => AppModal.dismiss(context),
      ),
    );
  }
}

/// Parse finalize `daily.goalsCompleted` into catalog rows for celebration.
List<TaskCatalogEntry> completedGoalsFromDailyPayload(
  Map<String, dynamic>? daily,
) {
  if (daily == null || daily.isEmpty) return const [];
  final raw = daily['goalsCompleted'] ?? daily['goals_completed'];
  if (raw is! List) return const [];
  final out = <TaskCatalogEntry>[];
  final seen = <String>{};
  for (final item in raw) {
    if (item is! Map) continue;
    final entry = TaskCatalogEntry.fromJson(Map<String, dynamic>.from(item));
    if (entry.id.isEmpty || !seen.add(entry.id)) continue;
    out.add(entry);
  }
  return out;
}

TaskCatalogEntry? taskEntryFromNotificationData(Map<String, dynamic> data) {
  final raw = data['goal'];
  if (raw is! Map) return null;
  final entry = TaskCatalogEntry.fromJson(Map<String, dynamic>.from(raw));
  if (entry.id.isEmpty) return null;
  return entry;
}

/// Rich celebrate body reused by NotificationHost presenters.
class DailyGoalCompleteCelebrateBody extends StatelessWidget {
  const DailyGoalCompleteCelebrateBody({
    required this.entry,
    this.onContinue,
    this.onDismiss,
    this.actions,
    super.key,
  });

  final TaskCatalogEntry entry;
  final Future<void> Function()? onContinue;
  final VoidCallback? onDismiss;
  final List<Widget>? actions;

  CatalogMediaRef? get _animatedBackground {
    final flat = entry.media['animated_background'] ??
        entry.media['animatedBackground'];
    if (flat != null && flat.isValid) return flat;
    final post = entry.media.postTaskSlot('animation') ??
        entry.media.postTaskSlot('animated_background') ??
        entry.media.postTaskSlot('primary');
    if (post != null && post.isValid) return post;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final action = entry.postCompleteAction;
    final cta = action.ctaLabel.trim().isEmpty ? 'View' : action.ctaLabel;
    final hasNav = action.type != 'none' &&
        ((action.screen?.isNotEmpty ?? false) ||
            (action.toPath?.isNotEmpty ?? false));
    final anim = _animatedBackground;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _CompleteMedia(ref: anim),
          ),
        ),
        AppSpacing.gapSm,
        Text(
          entry.name,
          style: context.appTypography.h3,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXs,
        Text(
          entry.description.isNotEmpty
              ? entry.description
              : 'Nice work — keep going.',
          style: context.appTypography.body,
          textAlign: TextAlign.center,
        ),
        if (actions != null) ...[
          AppSpacing.gapLg,
          ...actions!,
        ] else if (onContinue != null || onDismiss != null) ...[
          AppSpacing.gapLg,
          if (hasNav && onContinue != null)
            FilledButton(
              onPressed: () => unawaited(onContinue!()),
              child: Text(cta),
            ),
          if (hasNav && onContinue != null) AppSpacing.gapSm,
          if (onDismiss != null)
            OutlinedButton(
              onPressed: onDismiss,
              child: Text(hasNav ? 'Dismiss' : cta),
            ),
        ],
      ],
    );
  }
}

class _CompleteMedia extends StatelessWidget {
  const _CompleteMedia({this.ref});

  final CatalogMediaRef? ref;

  @override
  Widget build(BuildContext context) {
    final media = ref;
    if (media == null || !media.isValid) {
      return ColoredBox(
        color: context.appColorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.checklist,
          size: 48,
          color: context.appColorScheme.primary,
        ),
      );
    }

    final url = resolveMediaUrl(media.value);
    if (url.isEmpty) {
      return Icon(
        Icons.checklist,
        size: 48,
        color: context.appColorScheme.primary,
      );
    }

    if (media.type == 'lottie') {
      if (isBundleAssetMedia(media.value)) {
        return Lottie.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.checklist,
            size: 48,
            color: context.appColorScheme.primary,
          ),
        );
      }
      return Lottie.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.checklist,
          size: 48,
          color: context.appColorScheme.primary,
        ),
      );
    }

    if (media.type == 'image') {
      if (isBundleAssetMedia(media.value)) {
        return Image.asset(url, fit: BoxFit.cover);
      }
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.checklist,
          size: 48,
          color: context.appColorScheme.primary,
        ),
      );
    }

    return Icon(
      Icons.checklist,
      size: 48,
      color: context.appColorScheme.primary,
    );
  }
}
