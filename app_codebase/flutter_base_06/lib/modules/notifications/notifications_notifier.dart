import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_policy.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/ws/app_resume_hooks.dart';
import 'notifications_api.dart';
import 'notifications_state.dart';

final notificationsApiClientProvider = Provider<NotificationsApiClient>(
  (ref) => NotificationsApiClient(),
);

class NotificationsNotifier extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        state = const NotificationsState();
      }
      if (!next.isBootstrapping && next.isAuthenticated) {
        unawaited(refreshAll(force: true));
      }
    });
    return const NotificationsState();
  }

  NotificationsApiClient get _api => ref.read(notificationsApiClientProvider);

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> refreshAll({bool force = false}) async {
    await Future.wait([
      refreshInbox(force: force),
      refreshGlobals(force: force),
    ]);
  }

  Future<void> refreshInbox({bool force = false}) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    if (!force && !_shouldFetch()) {
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final outcome = await _api.fetchMessages(accessToken: token);
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForOutcome(outcome),
      );
      return;
    }
    final result = outcome.data!;
    state = state.copyWith(
      messages: result.messages,
      unreadCount: _combinedUnreadCount(
        userUnread: result.unreadCount,
        globalUnread: state.globalBroadcasts.where((m) => m.isUnread).length,
      ),
      isLoading: false,
      lastFetchedAt: DateTime.now(),
      clearError: true,
    );
  }

  Future<void> refreshGlobals({bool force = false}) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    if (!force && !_shouldFetch()) {
      return;
    }
    final outcome = await _api.fetchGlobals(accessToken: token);
    if (!outcome.isSuccess) {
      state = state.copyWith(errorMessage: _messageForOutcome(outcome));
      return;
    }
    final result = outcome.data!;
    state = state.copyWith(
      globalBroadcasts: result.messages,
      unreadCount: _combinedUnreadCount(
        userUnread: state.messages.where((m) => m.isUnread).length,
        globalUnread: result.unreadCount,
      ),
      lastFetchedAt: DateTime.now(),
      clearError: true,
    );
  }

  Future<void> onInboxChanged({bool force = true}) => refreshAll(force: force);

  Future<void> markRead(NotificationMessage message) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    if (message.isGlobal) {
      final outcome = await _api.markGlobalRead(
        accessToken: token,
        globalMessageIds: [message.id],
      );
      if (!outcome.isSuccess) {
        return;
      }
      state = state.copyWith(
        globalBroadcasts: [
          for (final item in state.globalBroadcasts)
            if (item.id == message.id)
              NotificationMessage(
                id: item.id,
                origin: item.origin,
                source: item.source,
                type: item.type,
                category: item.category,
                subtype: item.subtype,
                msgId: item.msgId,
                title: item.title,
                body: item.body,
                data: item.data,
                responses: item.responses,
                readAt: DateTime.now().toIso8601String(),
                userRead: true,
                createdAt: item.createdAt,
              )
            else
              item,
        ],
      );
      return;
    }

    final outcome = await _api.markRead(
      accessToken: token,
      messageIds: [message.id],
    );
    if (!outcome.isSuccess) {
      return;
    }
    state = state.copyWith(
      messages: [
        for (final item in state.messages)
          if (item.id == message.id)
            NotificationMessage(
              id: item.id,
              origin: item.origin,
              source: item.source,
              type: item.type,
              category: item.category,
              subtype: item.subtype,
              msgId: item.msgId,
              title: item.title,
              body: item.body,
              data: item.data,
              responses: item.responses,
              readAt: DateTime.now().toIso8601String(),
              userRead: item.userRead,
              createdAt: item.createdAt,
            )
          else
            item,
      ],
    );
  }

  Future<void> deleteMessage(NotificationMessage message) async {
    if (message.isGlobal) {
      await markRead(message);
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final outcome = await _api.deleteMessages(
      accessToken: token,
      messageIds: [message.id],
    );
    if (!outcome.isSuccess) {
      return;
    }
    state = state.copyWith(
      messages: state.messages.where((item) => item.id != message.id).toList(),
    );
  }

  void markModalShown(String modalKey) {
    state = state.copyWith(
      shownModalIds: {...state.shownModalIds, modalKey},
    );
  }

  List<NotificationMessage> pendingInstantModals() {
    final shown = state.shownModalIds;
    return state.instantModalCandidates
        .where((message) => !shown.contains(_modalKey(message)))
        .toList();
  }

  bool _shouldFetch() {
    final last = state.lastFetchedAt;
    if (last == null) {
      return true;
    }
    return DateTime.now().difference(last) >= kNotificationsFetchThrottle;
  }

  int _combinedUnreadCount({
    required int userUnread,
    required int globalUnread,
  }) =>
      userUnread + globalUnread;

  String? _messageForOutcome(NotificationsApiOutcome<dynamic> outcome) {
    if (outcome.isNetworkError) {
      return 'Network error — check your connection';
    }
    final error = outcome.error;
    if (error == null) {
      return null;
    }
    final action = actionForApiError(error, isWebSocket: false);
    if (action == ErrorAction.showMessage) {
      return error.message;
    }
    return error.message;
  }

  String _modalKey(NotificationMessage message) =>
      message.msgId ?? message.id;
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);

void registerNotificationsResumeHook() {
  registerAppResumeHook((ref) async {
    if (!ref.read(authProvider).isAuthenticated) {
      return;
    }
    await ref.read(notificationsProvider.notifier).refreshAll(force: true);
  });
}
