import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modal/modal.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_router.dart';
import '../../core/notifications/response/response_config.dart';
import '../../core/notifications/response/response_executor.dart';
import '../../core/notifications/subtype/subtype_registry.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/theme/theme.dart';
import '../../utils/dev_logger.dart';
import 'notifications_api.dart';
import 'notifications_notifier.dart';
import 'notifications_state.dart';
import '../achievements/achievement_unlock_modal.dart';
import '../achievements/achievements_catalog_store.dart';
import '../legacy/legacy_mint_complete_modal.dart';
import '../legacy/legacy_preserve_flow.dart';
import '../tasks/daily_goal_complete_modal.dart';
import 'register_progress_notifications.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Shows one or more notifications in a single modal session.
///
/// The modal cycles [pending] one message at a time with [kNotificationInterMessageDelay]
/// between messages (subtype spec may override delay per message).
Future<void> showNotificationModalSequence(
  BuildContext context,
  WidgetRef ref,
  List<NotificationMessage> pending, {
  Future<void> Function(NotificationMessage message)? onAcknowledged,
  Future<void> Function(NotificationMessage message)? markRead,
}) async {
  if (pending.isEmpty) {
    return;
  }
  await AppModal.showCentered(
    context,
    barrierDismissible: true,
    useRootNavigator: true,
    builder: (dialogContext) => _NotificationSequenceModal(
      pending: pending,
      ref: ref,
      onAcknowledged: onAcknowledged,
      markRead: markRead,
      onMessageShown: (message) {
        ref.read(notificationsProvider.notifier).markModalShown(
              message.msgId ?? message.id,
            );
      },
    ),
  );
}

/// Shows a single notification (wraps [showNotificationModalSequence]).
Future<void> showNotificationModal(
  BuildContext context,
  WidgetRef ref,
  NotificationMessage message, {
  Future<void> Function()? onAcknowledged,
  Future<void> Function()? markRead,
}) {
  return showNotificationModalSequence(
    context,
    ref,
    [message],
    onAcknowledged: onAcknowledged == null
        ? null
        : (_) => onAcknowledged(),
    markRead: markRead == null ? null : (_) => markRead(),
  );
}

class _NotificationSequenceModal extends StatefulWidget {
  const _NotificationSequenceModal({
    required this.pending,
    required this.ref,
    this.onAcknowledged,
    this.markRead,
    required this.onMessageShown,
  });

  final List<NotificationMessage> pending;
  final WidgetRef ref;
  final Future<void> Function(NotificationMessage message)? onAcknowledged;
  final Future<void> Function(NotificationMessage message)? markRead;
  final void Function(NotificationMessage message) onMessageShown;

  @override
  State<_NotificationSequenceModal> createState() =>
      _NotificationSequenceModalState();
}

class _NotificationSequenceModalState extends State<_NotificationSequenceModal> {
  int _index = 0;
  bool _advancing = false;

  NotificationMessage get _message => widget.pending[_index];

  @override
  void initState() {
    super.initState();
    _onMessageBecameCurrent(_message);
  }

  void _onMessageBecameCurrent(NotificationMessage message) {
    if (!isAchievementUnlockNotification(
      source: message.source,
      subtype: message.subtype,
    )) {
      return;
    }
    final entry = achievementEntryFromNotificationData(message.data);
    if (entry != null) {
      AchievementsCatalogStore.markUnlocked([entry.id]);
    }
  }

  Future<void> _completeCurrentMessage({required bool runAcknowledged}) async {
    if (_advancing) {
      return;
    }
    _advancing = true;
    widget.onMessageShown(_message);

    Future<void> ackSafe() async {
      if (!runAcknowledged) return;
      try {
        await widget.onAcknowledged?.call(_message);
      } catch (err) {
        if (LOGGING_SWITCH) {
          customlog(
            'notifications: acknowledge failed id=${_message.id} err=$err',
          );
        }
      }
    }

    final isLast = _index >= widget.pending.length - 1;
    if (isLast) {
      // Dismiss first so X / Play-now always close even if markRead hangs.
      if (mounted) {
        AppModal.dismiss(context);
      }
      unawaited(ackSafe());
      return;
    }

    await ackSafe();
    if (!mounted) {
      return;
    }
    final delay = interMessageDelayFor(
      source: _message.source,
      category: _message.category,
      subtype: _message.subtype,
    );
    await Future<void>.delayed(delay);
    if (!mounted) {
      return;
    }
    setState(() {
      _index++;
      _advancing = false;
    });
    _onMessageBecameCurrent(_message);
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final config = _filteredResponseConfig(message);

    final celebrate = _progressCelebrateChild(
      context: context,
      message: message,
      config: config,
    );
    if (celebrate != null) {
      return celebrate;
    }

    if (config is NavigateResponseConfig) {
      return AppCenteredModal(
        title: message.title,
        onClose: () => _completeCurrentMessage(runAcknowledged: true),
        child: Text(
          message.body,
          style: context.appTypography.body,
        ),
        actions: [
          for (var index = 0; index < config.buttons.length; index++)
            _navigateActionButton(
              context: context,
              message: message,
              config: config,
              button: config.buttons[index],
              markRead: () async {
                await widget.markRead?.call(message);
              },
              isPrimary: index == 0,
              onComplete: () => _completeCurrentMessage(runAcknowledged: false),
            ),
        ],
      );
    }

    if (config is ReplyResponseConfig) {
      final token = widget.ref.read(authProvider).accessToken ?? '';
      final api = widget.ref.read(notificationsApiClientProvider);
      return AppCenteredModal(
        title: message.title,
        onClose: () => _completeCurrentMessage(runAcknowledged: true),
        child: Text(
          message.body,
          style: context.appTypography.body,
        ),
        actions: [
          for (var index = 0; index < config.options.length; index++)
            _replyActionButton(
              context: context,
              ref: widget.ref,
              message: message,
              config: config,
              option: config.options[index],
              accessToken: token,
              api: api,
              markRead: () async {
                await widget.markRead?.call(message);
              },
              isPrimary: index == 0,
              onComplete: () => _completeCurrentMessage(runAcknowledged: false),
            ),
        ],
      );
    }

    return AppCenteredModal(
      title: message.title,
      onClose: () => _completeCurrentMessage(runAcknowledged: true),
      child: Text(
        message.body,
        style: context.appTypography.body,
      ),
      actions: [
        FilledButton(
          style: context.appButtons.primary.filled,
          onPressed: () => _completeCurrentMessage(runAcknowledged: true),
          child: Text(_acknowledgeLabel(message)),
        ),
      ],
    );
  }

  Widget? _progressCelebrateChild({
    required BuildContext context,
    required NotificationMessage message,
    required NotificationResponseConfig? config,
  }) {
    final isUnlock = isAchievementUnlockNotification(
      source: message.source,
      subtype: message.subtype,
    );
    final isDaily = isDailyCompleteNotification(
      source: message.source,
      subtype: message.subtype,
    );
    final isLegacy = isLegacyOfferNotification(
      source: message.source,
      subtype: message.subtype,
    );
    if (!isUnlock && !isDaily && !isLegacy) {
      return null;
    }

    if (isLegacy) {
      final offers = legacyOffersFromNotificationData(message.data);
      if (offers.isEmpty) {
        return null;
      }
      final preservable = offers.where((o) => o.canPreserve).toList();
      final token = widget.ref.read(authProvider).accessToken ?? '';
      return AppCenteredModal(
        title: message.title.isNotEmpty
            ? message.title
            : (preservable.length > 1
                ? 'Legacy preserve (${preservable.length})'
                : 'Legacy preserve available'),
        showCloseButton: false,
        child: LegacyOfferCelebrateBody(
          offers: preservable.isNotEmpty ? preservable : offers,
          actionsBuilder: (ctx, selected, unselected) => [
            if (token.isNotEmpty) ...[
              FilledButton(
                style: context.appButtons.primary.filled,
                onPressed: () async {
                  final mint = await submitLegacyPreserveSelection(
                    accessToken: token,
                    selected: selected,
                    decline: unselected,
                  );
                  await _completeCurrentMessage(runAcknowledged: true);
                  if (mint != null) {
                    await showLegacyMintCompleteModal(mint);
                  }
                },
                child: Text(
                  selected.isEmpty
                      ? 'Open leader window'
                      : (selected.length == 1
                          ? 'Preserve selected'
                          : 'Preserve ${selected.length} selected'),
                ),
              ),
              AppSpacing.gapSm,
              OutlinedButton(
                onPressed: () async {
                  await submitLegacyPreserveSelection(
                    accessToken: token,
                    selected: const [],
                    decline: preservable.isNotEmpty ? preservable : offers,
                  );
                  await _completeCurrentMessage(runAcknowledged: true);
                },
                child: const Text('Preserve none'),
              ),
              AppSpacing.gapSm,
            ],
            OutlinedButton(
              onPressed: () =>
                  _completeCurrentMessage(runAcknowledged: true),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }

    final navigate = config is NavigateResponseConfig ? config : null;
    final actionWidgets = <Widget>[
      if (navigate != null)
        for (var index = 0; index < navigate.buttons.length; index++) ...[
          if (index > 0) AppSpacing.gapSm,
          _navigateActionButton(
            context: context,
            message: message,
            config: navigate,
            button: navigate.buttons[index],
            markRead: () async {
              await widget.markRead?.call(message);
            },
            isPrimary: index == 0,
            onComplete: () => _completeCurrentMessage(runAcknowledged: false),
          ),
        ],
      AppSpacing.gapSm,
      OutlinedButton(
        onPressed: () => _completeCurrentMessage(runAcknowledged: true),
        child: const Text('Dismiss'),
      ),
    ];

    if (isUnlock) {
      final entry = achievementEntryFromNotificationData(message.data);
      if (entry == null) {
        return null;
      }
      return AppCenteredModal(
        title: message.title.isNotEmpty ? message.title : 'Achievement unlocked',
        showCloseButton: false,
        child: AchievementUnlockCelebrateBody(
          entry: entry,
          actions: actionWidgets,
        ),
      );
    }

    final entry = taskEntryFromNotificationData(message.data);
    if (entry == null) {
      return null;
    }
    return AppCenteredModal(
      title: message.title.isNotEmpty
          ? message.title
          : (entry.isDailyGoal ? 'Daily goal complete' : 'Task complete'),
      showCloseButton: false,
      child: DailyGoalCompleteCelebrateBody(
        entry: entry,
        actions: actionWidgets,
      ),
    );
  }
}

NotificationResponseConfig? _filteredResponseConfig(
  NotificationMessage message,
) {
  final config = message.responseConfig;
  if (config is! NavigateResponseConfig) {
    return config;
  }
  final spec = resolveSubtypeSpec(
    source: message.source,
    category: message.category,
    subtype: message.subtype,
  );
  if (spec.allowedScreens.isEmpty) {
    return config;
  }
  final filtered = config.buttons
      .where(
        (button) =>
            button.screen == null ||
            spec.allowedScreens.contains(button.screen),
      )
      .toList();
  if (filtered.isEmpty) {
    return null;
  }
  return NavigateResponseConfig(
    buttons: filtered,
    markReadOnAction: config.markReadOnAction,
  );
}

Widget _navigateActionButton({
  required BuildContext context,
  required NotificationMessage message,
  required NavigateResponseConfig config,
  required NavigateButton button,
  required Future<void> Function()? markRead,
  required bool isPrimary,
  required Future<void> Function() onComplete,
}) {
  final style = isPrimary
      ? context.appButtons.primary.filled
      : context.appButtons.secondary.text;
  final child = Text(button.label);
  Future<void> onTap() async {
    // Mark read + close modal before navigate. Pushing while the modal is
    // open (or when already on the target screen) can orphan the popup so
    // Play now / X never dismisses.
    try {
      if (config.markReadOnAction) {
        await markRead?.call();
      }
    } catch (err) {
      if (LOGGING_SWITCH) {
        customlog('notifications: markRead on navigate failed err=$err');
      }
    }
    if (context.mounted) {
      await onComplete();
    }

    final path = resolveNavigatePath(button);
    if (path == null || path.isEmpty) return;

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

    final rootCtx = appRootNavigatorKey.currentContext;
    if (rootCtx == null || !rootCtx.mounted) return;
    final current = _normalizeNavPath(Nav.matchedLocation(rootCtx));
    final target = _normalizeNavPath(path);
    if (current == target) {
      if (LOGGING_SWITCH) {
        customlog(
          'notifications: Play now skip nav (already on $target)',
        );
      }
      return;
    }
    Nav.go(rootCtx, path);
  }

  if (isPrimary) {
    return FilledButton(
      style: style,
      onPressed: onTap,
      child: child,
    );
  }
  return TextButton(
    style: style,
    onPressed: onTap,
    child: child,
  );
}

String _normalizeNavPath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '/';
  if (trimmed.length > 1 && trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

Widget _replyActionButton({
  required BuildContext context,
  required WidgetRef ref,
  required NotificationMessage message,
  required ReplyResponseConfig config,
  required ReplyOption option,
  required String accessToken,
  required NotificationsApiClient api,
  required Future<void> Function()? markRead,
  required bool isPrimary,
  required Future<void> Function() onComplete,
}) {
  Future<void> onTap() async {
    if (accessToken.isEmpty) {
      return;
    }
    final optionKey = option.key.trim().toLowerCase();
    final result = await executeReply(
      ref: ref,
      api: api,
      accessToken: accessToken,
      message: message,
      optionKey: optionKey,
      config: config,
      markRead: markRead,
    );

    if (!result.success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit your response')),
      );
      return;
    }

    if (context.mounted) {
      await onComplete();
    }
  }

  final style = isPrimary
      ? context.appButtons.primary.filled
      : context.appButtons.secondary.text;
  final child = Text(option.label);
  if (isPrimary) {
    return FilledButton(
      style: style,
      onPressed: onTap,
      child: child,
    );
  }
  return TextButton(
    style: style,
    onPressed: onTap,
    child: child,
  );
}

String _acknowledgeLabel(NotificationMessage message) {
  if (message.responses.isEmpty) {
    return 'OK';
  }
  final label = message.responses.first['label']?.toString();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return 'OK';
}
