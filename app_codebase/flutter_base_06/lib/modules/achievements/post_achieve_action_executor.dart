import 'package:flutter/material.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/notifications/notification_screen_registry.dart';
import '../../utils/dev_logger.dart';
import 'achievements_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Client registry for post-achieve actions (like notification navigate).
Future<void> executePostAchieveAction({
  required BuildContext context,
  required PostAchieveAction action,
}) async {
  final type = action.type.trim().toLowerCase();
  if (type.isEmpty || type == PostAchieveActionTypes.none) {
    return;
  }
  if (type == PostAchieveActionTypes.moveToScreen) {
    final screen = action.screen?.trim() ?? '';
    if (screen.isEmpty) return;
    final path = resolveNotificationScreenPath(screen);
    if (path == null || path.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('achievements: unknown screen slug=$screen');
      }
      return;
    }
    if (context.mounted) {
      Nav.push(context, path);
    }
    return;
  }
  if (type == PostAchieveActionTypes.openPath) {
    final path = action.toPath?.trim() ?? '';
    if (path.isEmpty) return;
    if (context.mounted) {
      Nav.push(context, path);
    }
    return;
  }
  // Unknown types no-op so older clients stay safe when catalog grows.
  if (LOGGING_SWITCH) {
    customlog('achievements: unknown post_achieve_action type=$type');
  }
}
