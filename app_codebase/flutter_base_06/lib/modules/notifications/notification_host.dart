import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/app_router.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../utils/dev_logger.dart';
import '../play/play_models.dart';
import '../play/play_notifier.dart';
import 'notification_modal.dart';
import 'notifications_notifier.dart';
import 'notifications_state.dart';
import 'register_progress_notifications.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Shows unread instant notification modals and listens for inbox updates.
///
/// Lives above [MaterialApp.router], so instant modals use
/// [appRootNavigatorKey] — this widget's [context] has no [Navigator] / [Theme].
///
/// Achievement unlock / daily-complete / legacy-offer instants only present when
/// match flow is idle / selectingType, and the player is on a hub screen
/// (Home, Play, Tasks, Avari, Achievements — same as subtype allowedScreens).
/// Other instant subtypes (e.g. friend-match invite) keep existing app-wide behavior.
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
  GoRouter? _router;
  VoidCallback? _routeListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachRouteListener();
      unawaited(_maybeRefreshAndShowModals());
    });
  }

  @override
  void dispose() {
    _detachRouteListener();
    super.dispose();
  }

  void _attachRouteListener() {
    if (_routeListener != null) return;
    final router = ref.read(appRouterProvider);
    _router = router;
    _routeListener = () {
      unawaited(_showPendingModals());
    };
    router.routerDelegate.addListener(_routeListener!);
  }

  void _detachRouteListener() {
    final listener = _routeListener;
    final router = _router;
    if (listener != null && router != null) {
      router.routerDelegate.removeListener(listener);
    }
    _routeListener = null;
    _router = null;
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
    ref.listen(matchFlowProvider, (previous, next) {
      final wasUnsafe = previous != null && !_phaseIsSafe(previous.phase);
      final nowSafe = _phaseIsSafe(next.phase);
      if (wasUnsafe && nowSafe) {
        if (LOGGING_SWITCH) {
          customlog(
            'NotificationHost: match flow safe again '
            'phase=${next.phase.name} — re-show pending',
          );
        }
        unawaited(_showPendingModals());
      } else if (nowSafe && previous?.phase != next.phase) {
        unawaited(_showPendingModals());
      }
    });
    return widget.child;
  }

  bool _phaseIsSafe(MatchFlowPhase phase) {
    return phase == MatchFlowPhase.idle ||
        phase == MatchFlowPhase.selectingType;
  }

  String _currentPath() {
    try {
      final router = ref.read(appRouterProvider);
      final matched = router.routerDelegate.currentConfiguration.uri.path;
      if (matched.isEmpty) return AppPaths.home;
      return matched;
    } catch (_) {
      return '';
    }
  }

  bool _isSafeSurface() {
    final phase = ref.read(matchFlowProvider).phase;
    if (!_phaseIsSafe(phase)) {
      return false;
    }
    final path = _currentPath();
    // Match phase already blocks in-match / post-match. Allow hub screens that
    // progress subtypes list (tasks/avari/achievements) — otherwise Done →
    // /tasks (Daily nudge / View Daily) defers offer_v1 forever.
    return path == AppPaths.home ||
        path == AppPaths.play ||
        path == AppPaths.tasks ||
        path == AppPaths.avari ||
        path == AppPaths.achievements;
  }

  bool _isProgressCelebrate(NotificationMessage message) {
    return isAchievementUnlockNotification(
          source: message.source,
          subtype: message.subtype,
        ) ||
        isDailyCompleteNotification(
          source: message.source,
          subtype: message.subtype,
        ) ||
        isLegacyOfferNotification(
          source: message.source,
          subtype: message.subtype,
        ) ||
        isLegacyLeaderPressureNotification(
          source: message.source,
          subtype: message.subtype,
        ) ||
        isLegacyLeaderChaseNotification(
          source: message.source,
          subtype: message.subtype,
        );
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
    final safe = _isSafeSurface();
    var pending =
        ref.read(notificationsProvider.notifier).pendingInstantModals();
    if (!safe) {
      pending = pending.where((m) => !_isProgressCelebrate(m)).toList();
      if (LOGGING_SWITCH && pending.isEmpty) {
        customlog(
          'NotificationHost: skip show pending (unsafe surface; '
          'progress celebrates deferred) '
          'path=${_currentPath()} phase=${ref.read(matchFlowProvider).phase.name}',
        );
      }
    }
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
