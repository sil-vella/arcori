import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/screen/module_screen_registrar.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/theme/theme.dart';
import 'notification_modal.dart';
import 'notifications_notifier.dart';
import 'notifications_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    ref.listen(authProvider, (previous, next) {
      if (!next.isBootstrapping && next.isAuthenticated) {
        notifier.refreshAll(force: true);
      }
    });

    final allMessages = [
      ...notifications.globalBroadcasts,
      ...notifications.messages,
    ];

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(
          text: 'Notifications',
          icon: Icons.notifications_outlined,
        ),
      ],
      child: notifications.isLoading && allMessages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : allMessages.isEmpty
              ? Center(
                  child: Text(
                    'No notifications yet',
                    style: context.appTypography.body,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => notifier.refreshAll(force: true),
                  child: ListView.separated(
                    padding: AppSpacing.screenPadding,
                    itemCount: allMessages.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final message = allMessages[index];
                      return _NotificationTile(
                        message: message,
                        onTap: () async {
                          await showNotificationModal(
                            context,
                            ref,
                            message,
                            onAcknowledged: () => notifier.markRead(message),
                            markRead: () => notifier.markRead(message),
                          );
                        },
                        onDelete: () => notifier.deleteMessage(message),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.message,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationMessage message;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.appColorScheme;
    return Material(
      color: message.isUnread ? AppColors.primaryPastel : scheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: AppSpacing.screenPaddingCompact,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: context.appTypography.title.copyWith(
                        fontWeight: message.isUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (message.subtype != null && message.subtype!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          message.subtype!,
                          style: context.appTypography.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        message.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTypography.body,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
