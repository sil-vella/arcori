import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth/auth_providers.dart';
import 'notification_modal.dart';
import 'notifications_notifier.dart';
import 'notifications_state.dart';

/// Shows unread instant notification modals and listens for inbox updates.
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
    Future.microtask(_maybeRefreshAndShowModals);
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
      return;
    }
    await ref.read(notificationsProvider.notifier).refreshAll(force: true);
    await _showPendingModals();
  }

  Future<void> _showPendingModals() async {
    if (_modalPipelineRunning || !mounted) {
      return;
    }
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      return;
    }
    final pending =
        ref.read(notificationsProvider.notifier).pendingInstantModals();
    if (pending.isEmpty) {
      return;
    }
    _modalPipelineRunning = true;
    try {
      await showNotificationModalSequence(
        context,
        ref,
        pending,
        onAcknowledged: (message) =>
            ref.read(notificationsProvider.notifier).markRead(message),
        markRead: (message) =>
            ref.read(notificationsProvider.notifier).markRead(message),
      );
    } finally {
      _modalPipelineRunning = false;
    }
  }
}
