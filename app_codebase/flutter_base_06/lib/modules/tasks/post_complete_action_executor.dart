import 'package:flutter/material.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/notifications/notification_screen_registry.dart';
import '../../utils/dev_logger.dart';
import 'tasks_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Client registry for post-complete actions (same pattern as achievements).
Future<void> executePostCompleteAction({
  required BuildContext context,
  required TaskPostCompleteAction action,
}) async {
  final type = action.type.trim().toLowerCase();
  if (type.isEmpty || type == 'none') {
    return;
  }
  if (type == 'move_to_screen') {
    final screen = action.screen?.trim() ?? '';
    if (screen.isEmpty) return;
    final path = resolveNotificationScreenPath(screen);
    if (path == null || path.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('tasks: unknown screen slug=$screen');
      }
      return;
    }
    if (context.mounted) {
      Nav.push(context, path);
    }
    return;
  }
  if (type == 'open_path') {
    final path = action.toPath?.trim() ?? '';
    if (path.isEmpty) return;
    if (context.mounted) {
      Nav.push(context, path);
    }
    return;
  }
  if (LOGGING_SWITCH) {
    customlog('tasks: unknown post_complete_action type=$type');
  }
}
