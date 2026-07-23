import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../modules/notifications/notifications_state.dart';
import 'response_executor.dart';

typedef NotificationReplyListener = void Function(
  WidgetRef ref,
  NotificationMessage message,
  String optionKey,
  NotificationReplyResult result,
);

final Map<String, NotificationReplyListener> _listeners = {};

void resetNotificationReplyListeners() {
  _listeners.clear();
}

void registerNotificationReplyListener(
  String source,
  NotificationReplyListener listener,
) {
  final key = source.trim();
  if (key.isEmpty) {
    return;
  }
  _listeners[key] = listener;
}

void notifyNotificationReplyListeners({
  required WidgetRef ref,
  required String source,
  required NotificationMessage message,
  required String optionKey,
  required NotificationReplyResult result,
}) {
  final listener = _listeners[source.trim()];
  listener?.call(ref, message, optionKey, result);
}
