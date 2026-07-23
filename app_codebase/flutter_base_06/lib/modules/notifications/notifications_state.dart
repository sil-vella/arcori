/// Notification message wire models.
library;

import '../../core/notifications/subtype/subtype_registry.dart';
import '../../core/notifications/response/response_config.dart';

class NotificationMessage {
  const NotificationMessage({
    required this.id,
    required this.origin,
    required this.source,
    required this.type,
    required this.title,
    required this.body,
    this.category,
    this.subtype,
    this.msgId,
    this.data = const {},
    this.responses = const [],
    this.readAt,
    this.userRead = false,
    this.createdAt,
  });

  final String id;
  final String origin;
  final String source;
  final String type;
  final String? category;
  final String? subtype;
  final String? msgId;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> responses;
  final String? readAt;
  final bool userRead;
  final String? createdAt;

  bool get isGlobal => origin == 'global';
  bool get isUnread => isGlobal ? !userRead : readAt == null;
  bool get isInstant => type == kNotificationTypeInstant;

  NotificationResponseConfig? get responseConfig =>
      NotificationResponseConfig.fromMessageData(data);

  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    final responsesRaw = json['responses'];
    final responses = responsesRaw is List
        ? responsesRaw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final dataRaw = json['data'];
    return NotificationMessage(
      id: json['id']?.toString() ?? '',
      origin: json['origin']?.toString() ?? 'user',
      source: json['source']?.toString() ?? '',
      type: json['type']?.toString() ?? kNotificationTypeInstant,
      category: json['category']?.toString(),
      subtype: json['subtype']?.toString(),
      msgId: json['msg_id']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : const {},
      responses: responses,
      readAt: json['read_at']?.toString(),
      userRead: json['user_read'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class NotificationsState {
  const NotificationsState({
    this.messages = const [],
    this.globalBroadcasts = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.errorMessage,
    this.lastFetchedAt,
    this.shownModalIds = const {},
  });

  final List<NotificationMessage> messages;
  final List<NotificationMessage> globalBroadcasts;
  final int unreadCount;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastFetchedAt;
  final Set<String> shownModalIds;

  NotificationsState copyWith({
    List<NotificationMessage>? messages,
    List<NotificationMessage>? globalBroadcasts,
    int? unreadCount,
    bool? isLoading,
    String? errorMessage,
    DateTime? lastFetchedAt,
    Set<String>? shownModalIds,
    bool clearError = false,
  }) {
    return NotificationsState(
      messages: messages ?? this.messages,
      globalBroadcasts: globalBroadcasts ?? this.globalBroadcasts,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      shownModalIds: shownModalIds ?? this.shownModalIds,
    );
  }

  List<NotificationMessage> get instantModalCandidates {
    final globals = globalBroadcasts.where(
      (message) => message.isInstant && message.isUnread,
    );
    final userInstants = messages.where(
      (message) => message.isInstant && message.isUnread,
    );
    final combined = [...globals, ...userInstants];
    combined.sort(_compareModalPriority);
    return combined;
  }
}

int _compareModalPriority(NotificationMessage a, NotificationMessage b) {
  final priorityA = resolveSubtypeSpec(
    source: a.source,
    category: a.category,
    subtype: a.subtype,
  ).modalPriority;
  final priorityB = resolveSubtypeSpec(
    source: b.source,
    category: b.category,
    subtype: b.subtype,
  ).modalPriority;
  if (priorityA != priorityB) {
    return priorityA.compareTo(priorityB);
  }
  final createdA = a.createdAt ?? '';
  final createdB = b.createdAt ?? '';
  return createdA.compareTo(createdB);
}

const kNotificationTypeInstant = 'instant';
const kNotificationTypeInbox = 'inbox';

const kNotificationInterMessageDelay = Duration(milliseconds: 700);

const kNotificationsFetchThrottle = Duration(seconds: 15);
