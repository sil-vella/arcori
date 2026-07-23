import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/notifications/notifications_state.dart';

void main() {
  test('instantModalCandidates includes unread instant only', () {
    const state = NotificationsState(
      messages: [
        NotificationMessage(
          id: '1',
          origin: 'user',
          source: 'core',
          type: kNotificationTypeInstant,
          title: 'Instant',
          body: 'Show me',
        ),
        NotificationMessage(
          id: '2',
          origin: 'user',
          source: 'core',
          type: kNotificationTypeInbox,
          title: 'Inbox',
          body: 'List only',
        ),
      ],
      globalBroadcasts: [
        NotificationMessage(
          id: 'glob_abc',
          origin: 'global',
          source: 'global_broadcast',
          type: kNotificationTypeInstant,
          title: 'Welcome',
          body: 'Hello',
        ),
      ],
    );

    final candidates = state.instantModalCandidates;
    expect(candidates.length, 2);
    expect(candidates.any((message) => message.id == '1'), isTrue);
    expect(candidates.any((message) => message.id == 'glob_abc'), isTrue);
    expect(candidates.any((message) => message.id == '2'), isFalse);
  });
}
