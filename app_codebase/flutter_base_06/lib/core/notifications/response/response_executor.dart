import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_navigation.dart';
import '../../../modules/notifications/notifications_api.dart';
import '../../../modules/notifications/notifications_state.dart';
import '../subtype/subtype_registry.dart';
import '../notification_screen_registry.dart';
import 'reply_listener_registry.dart';
import 'response_config.dart';

String? resolveNavigatePath(NavigateButton button) {
  final screen = button.screen;
  if (screen != null && screen.isNotEmpty) {
    return resolveNotificationScreenPath(screen);
  }
  final toPath = button.toPath;
  if (toPath != null && toPath.isNotEmpty) {
    return toPath;
  }
  return null;
}

Future<void> executeNavigate({
  required BuildContext context,
  required NotificationMessage message,
  required NavigateButton button,
  required NavigateResponseConfig config,
  Future<void> Function()? markRead,
}) async {
  final spec = resolveSubtypeSpec(
    source: message.source,
    category: message.category,
    subtype: message.subtype,
  );
  final screen = button.screen;
  if (screen != null &&
      spec.allowedScreens.isNotEmpty &&
      !spec.allowedScreens.contains(screen)) {
    return;
  }
  final path = resolveNavigatePath(button);
  if (path != null && context.mounted) {
    Nav.push(context, path);
  }
  if (config.markReadOnAction) {
    await markRead?.call();
  }
}

class NotificationReplyResult {
  const NotificationReplyResult({
    required this.success,
    this.data,
  });

  final bool success;
  final Map<String, dynamic>? data;
}

Future<NotificationReplyResult> executeReply({
  required WidgetRef ref,
  required NotificationsApiClient api,
  required String accessToken,
  required NotificationMessage message,
  required String optionKey,
  required ReplyResponseConfig config,
  Future<void> Function()? markRead,
}) async {
  final outcome = await api.submitResponse(
    accessToken: accessToken,
    messageId: message.isGlobal ? null : message.id,
    globalMessageId: message.isGlobal ? message.id : null,
    optionKey: optionKey,
  );
  if (!outcome.isSuccess) {
    return const NotificationReplyResult(success: false);
  }

  final dataRaw = outcome.data;
  final nested = dataRaw is Map<String, dynamic> ? dataRaw['data'] : null;
  final data = nested is Map ? Map<String, dynamic>.from(nested) : null;
  if (config.markReadOnSuccess) {
    await markRead?.call();
  }

  notifyNotificationReplyListeners(
    ref: ref,
    source: message.source,
    message: message,
    optionKey: optionKey,
    result: NotificationReplyResult(success: true, data: data),
  );

  return NotificationReplyResult(success: true, data: data);
}
