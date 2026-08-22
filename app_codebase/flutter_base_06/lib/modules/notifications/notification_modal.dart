import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modal/modal.dart';
import '../../core/notifications/response/response_config.dart';
import '../../core/notifications/response/response_executor.dart';
import '../../core/notifications/subtype/subtype_registry.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/theme/theme.dart';
import 'notifications_api.dart';
import 'notifications_notifier.dart';
import 'notifications_state.dart';

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

  Future<void> _completeCurrentMessage({required bool runAcknowledged}) async {
    if (_advancing) {
      return;
    }
    _advancing = true;
    widget.onMessageShown(_message);
    if (runAcknowledged) {
      await widget.onAcknowledged?.call(_message);
    }
    if (!mounted) {
      return;
    }
    if (_index >= widget.pending.length - 1) {
      AppModal.dismiss(context);
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
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final config = _filteredResponseConfig(message);

    if (config is NavigateResponseConfig) {
      return AppCenteredModal(
        title: message.title,
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
    await executeNavigate(
      context: context,
      message: message,
      button: button,
      config: config,
      markRead: markRead,
    );
    if (context.mounted) {
      await onComplete();
    }
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
