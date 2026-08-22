import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_router.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../utils/dev_logger.dart';
import 'notification_modal.dart';
import 'notifications_notifier.dart';
import 'notifications_state.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Shows unread instant notification modals and listens for inbox updates.
///
/// Lives above [MaterialApp.router], so instant modals use
/// [appRootNavigatorKey] — this widget's [context] has no [Navigator] / [Theme].
class NotificationHost extends ConsumerStatefulWidget {
  const NotificationHost({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends ConsumerState<NotificationHost> {
  bool _modalPipelineRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeRefreshAndShowModals());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NotificationsState>(notificationsProvider, (_, __) {
      unawaited(_showPendingModals());
    });
    ref.listen(authProvider, (previous, next) {
      if (!next.isBootstrapping && next.isAuthenticated) {
        unawaited(_maybeRefreshAndShowModals());
      }
    });
    return widget.child;
  }

  Future<void> _maybeRefreshAndShowModals() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      if (LOGGING_SWITCH) {
        customlog('NotificationHost: skip refresh (not authenticated)');
      }
      return;
    }
    if (LOGGING_SWITCH) {
      customlog('NotificationHost: refresh + show pending');
    }
    await ref.read(notificationsProvider.notifier).refreshAll(force: true);
    await _showPendingModals();
  }

  Future<void> _showPendingModals() async {
    if (_modalPipelineRunning || !mounted) {
      if (LOGGING_SWITCH) {
        customlog(
          'NotificationHost: skip show pending '
          'running=$_modalPipelineRunning mounted=$mounted',
        );
      }
      return;
    }
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      if (LOGGING_SWITCH) {
        customlog('NotificationHost: skip show pending (not authenticated)');
      }
      return;
    }
    final pending =
        ref.read(notificationsProvider.notifier).pendingInstantModals();
    if (pending.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('NotificationHost: skip show pending (none)');
      }
      return;
    }
    final navContext = appRootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) {
      if (LOGGING_SWITCH) {
        customlog(
          'NotificationHost: skip show pending (no root navigator) '
          'count=${pending.length}',
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_showPendingModals());
      });
      return;
    }
    if (LOGGING_SWITCH) {
      customlog(
        'NotificationHost: showing ${pending.length} modal(s) '
        'sources=${pending.map((m) => '${m.source}/${m.subtype ?? '-'}').join(',')}',
      );
    }
    final drainedKeys = {
      for (final message in pending) message.msgId ?? message.id,
    };
    _modalPipelineRunning = true;
    try {
      await showNotificationModalSequence(
        navContext,
        ref,
        pending,
        onAcknowledged: (message) =>
            ref.read(notificationsProvider.notifier).markRead(message),
        markRead: (message) =>
            ref.read(notificationsProvider.notifier).markRead(message),
      );
    } catch (err) {
      if (LOGGING_SWITCH) {
        customlog('NotificationHost: modal sequence failed err=$err');
      }
    } finally {
      _modalPipelineRunning = false;
    }
    if (!mounted) {
      return;
    }
    final leftover = ref
        .read(notificationsProvider.notifier)
        .pendingInstantModals()
        .where((message) => !drainedKeys.contains(message.msgId ?? message.id))
        .toList();
    if (leftover.isNotEmpty) {
      if (LOGGING_SWITCH) {
        customlog(
          'NotificationHost: drain leftover count=${leftover.length}',
        );
      }
      unawaited(_showPendingModals());
    }
  }
}
