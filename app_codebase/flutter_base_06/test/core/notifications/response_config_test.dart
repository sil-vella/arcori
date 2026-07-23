import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/navigation/app_paths.dart';
import 'package:arcori/core/notifications/contracts/register_notification_screen_contract.dart';
import 'package:arcori/core/notifications/notification_screen_registry.dart';
import 'package:arcori/core/notifications/response/response_config.dart';

void main() {
  setUp(() {
    resetNotificationScreenRegistry();
    notificationScreenSink.registerScreens([
      const NotificationNavigableScreen(
        slug: 'example_module',
        path: AppPaths.exampleModule,
      ),
      const NotificationNavigableScreen(
        slug: 'notifications',
        path: AppPaths.notifications,
      ),
    ]);
  });

  test('parses navigate response from message data', () {
    final config = NotificationResponseConfig.fromMessageData({
      'response': {
        'type': 'navigate',
        'buttons': [
          {'label': 'Explore', 'screen': 'example_module'},
          {'label': 'Custom', 'to_path': '/account?tab=sign-in'},
        ],
      },
    });

    expect(config, isA<NavigateResponseConfig>());
    final navigate = config! as NavigateResponseConfig;
    expect(navigate.buttons, hasLength(2));
    expect(navigate.buttons.first.screen, 'example_module');
    expect(navigate.buttons.last.toPath, '/account?tab=sign-in');
  });

  test('parses reply response from message data', () {
    final config = NotificationResponseConfig.fromMessageData({
      'response': {
        'type': 'reply',
        'options': [
          {'key': 'accept', 'label': 'Accept'},
        ],
      },
    });

    expect(config, isA<ReplyResponseConfig>());
    final reply = config! as ReplyResponseConfig;
    expect(reply.options.single.key, 'accept');
  });

  test('resolveNotificationScreenPath uses registry', () {
    expect(
      resolveNotificationScreenPath('example_module'),
      '/example-module',
    );
  });
}
