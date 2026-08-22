import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/app_router.dart';
import '../../core/notifications/response/reply_listener_registry.dart';
import '../../core/notifications/response/response_executor.dart';
import '../../core/notifications/subtype/notification_subtype_spec.dart';
import '../../core/notifications/subtype/subtype_registry.dart';
import '../notifications/notifications_state.dart';
import '../../utils/dev_logger.dart';
import 'play_notifier.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const _friendMatchInviteSource = 'friend_match_invite';

/// Play-module notification subtype + reply follow-up (Accept → join lobby).
void registerPlayNotifications() {
  notificationSubtypeSink.registerSubtypes([
    const NotificationSubtypeSpec(
      source: _friendMatchInviteSource,
      category: 'friend_match',
      subtype: 'invite_v1',
      modalPriority: 70,
    ),
  ]);
  registerNotificationReplyListener(
    _friendMatchInviteSource,
    _onFriendMatchInviteReply,
  );
}

void _onFriendMatchInviteReply(
  WidgetRef ref,
  NotificationMessage message,
  String optionKey,
  NotificationReplyResult result,
) {
  if (LOGGING_SWITCH) {
    customlog(
      'play: invite reply option=$optionKey success=${result.success} '
      'subtype=${message.subtype ?? '-'}',
    );
  }
  if (optionKey != 'accept' || !result.success) {
    return;
  }
  final inviteId = result.data?['inviteId']?.toString() ?? '';
  if (inviteId.isEmpty) {
    if (LOGGING_SWITCH) {
      customlog('play: invite reply accept missing inviteId');
    }
    return;
  }
  SchedulerBinding.instance.addPostFrameCallback((_) {
    unawaited(ref.read(appRouterProvider).push(AppPaths.play));
    final notifier = ref.read(matchFlowProvider.notifier);
    notifier.startPlay();
    unawaited(notifier.startInviteJoin(inviteId: inviteId));
  });
}
