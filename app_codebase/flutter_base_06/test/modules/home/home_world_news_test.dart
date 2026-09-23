import 'package:arcori/modules/avari/avari_models.dart';
import 'package:arcori/modules/notifications/notifications_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MasteryRecentChange tickerLabel', () {
    const row = MasteryRecentChange(
      designId: 'DES-1',
      displayName: 'Tiger',
      delta: 3,
    );
    expect(row.tickerLabel, 'Tiger +3');
  });

  test('World news filter by category', () {
    final messages = [
      NotificationMessage.fromJson({
        'id': '1',
        'origin': 'global',
        'source': 'world',
        'type': 'inbox',
        'category': 'news',
        'subtype': 'admin_v1',
        'title': 'News',
        'body': 'Body',
        'created_at': '2026-09-20T12:00:00Z',
      }),
      NotificationMessage.fromJson({
        'id': '2',
        'origin': 'user',
        'source': 'achievements',
        'type': 'instant',
        'category': 'progress',
        'subtype': 'unlock_v1',
        'title': 'Unlock',
        'body': 'Nope',
      }),
    ];
    final news = messages
        .where((m) => (m.category ?? '').trim() == 'news')
        .toList();
    expect(news.length, 1);
    expect(news.first.title, 'News');
  });
}
