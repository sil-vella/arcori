import 'package:flutter_test/flutter_test.dart';

import 'package:arcori/core/notifications/subtype/notification_subtype_spec.dart';
import 'package:arcori/core/notifications/subtype/subtype_registry.dart';

void main() {
  setUp(() {
    resetNotificationSubtypeRegistry();
    registerBuiltinNotificationSubtypes();
  });

  test('resolveSubtypeSpec returns registered allowed screens', () {
    final spec = resolveSubtypeSpec(
      source: 'example_module',
      category: 'demo',
      subtype: 'example_navigate_demo',
    );
    expect(spec.allowedScreens, contains('home'));
    expect(spec.modalPriority, 50);
  });

  test('interMessageDelayFor defaults to 700ms', () {
    final delay = interMessageDelayFor(
      source: 'example_module',
      category: 'demo',
      subtype: 'example_reply_demo',
    );
    expect(delay, const Duration(milliseconds: kDefaultInterMessageDelayMs));
  });
}
