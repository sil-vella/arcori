import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/navigation/app_paths.dart';
import 'package:arcori/core/notifications/contracts/register_notification_screen_contract.dart';
import 'package:arcori/core/notifications/notification_screen_registry.dart';
import 'package:arcori/core/notifications/response/response_config.dart';
import 'package:arcori/core/notifications/response/response_executor.dart';

void main() {
  setUp(() {
    resetNotificationScreenRegistry();
    notificationScreenSink.registerScreens([
      const NotificationNavigableScreen(
        slug: 'notifications',
        path: AppPaths.notifications,
      ),
    ]);
  });

  test('resolveNavigatePath prefers screen registry', () {
    final path = resolveNavigatePath(
      const NavigateButton(label: 'Go', screen: 'notifications'),
    );
    expect(path, '/notifications');
  });

  test('resolveNavigatePath falls back to to_path', () {
    final path = resolveNavigatePath(
      const NavigateButton(label: 'Go', toPath: '/account'),
    );
    expect(path, '/account');
  });
}
