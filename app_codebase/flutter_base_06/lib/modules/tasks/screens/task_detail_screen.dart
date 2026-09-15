import 'package:flutter/material.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../tasks_store.dart';

/// Stub detail for a daily goal or task. Full continue/claim UI later.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final entry = TasksStore.byId(taskId);
    final progress = TasksStore.progressFor(taskId);
    final title = entry?.name.isNotEmpty == true ? entry!.name : taskId;

    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(text: title, icon: Icons.task_alt_outlined),
      ],
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry?.description.isNotEmpty == true
                  ? entry!.description
                  : 'Task details coming soon.',
              style: context.appTypography.body,
            ),
            AppSpacing.gapMd,
            if (entry != null) ...[
              Text(
                'Section: ${entry.isDailyGoal ? 'Daily Goal' : 'Task'}',
                style: context.appTypography.bodySmall,
              ),
              AppSpacing.gapXs,
              Text(
                'Type: ${entry.taskType}',
                style: context.appTypography.bodySmall,
              ),
            ],
            if (progress != null) ...[
              AppSpacing.gapMd,
              Text(
                'Progress: ${progress.progressLabel}',
                style: context.appTypography.body,
              ),
              AppSpacing.gapXs,
              Text(
                'Value: ${progress.value}',
                style: context.appTypography.bodySmall,
              ),
            ],
            AppSpacing.gapLg,
            Text(
              'Continue, claim, and rewards — stub for now.',
              style: context.appTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
