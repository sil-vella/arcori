import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/play/game_controls_prefs.dart';
import 'package:arcori/modules/play/slam_control_mode_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlamControlModeUi', () {
    test('accel uses phone-motion copy and rotation icon', () {
      expect(SlamControlMode.accel.label, 'Phone motion');
      expect(SlamControlMode.accel.icon, Icons.screen_rotation);
      expect(SlamControlMode.accel.caption, contains('Tilt'));
      expect(SlamControlMode.accel.caption, contains('Shake'));
    });

    test('touch uses swipe copy and swipe icon', () {
      expect(SlamControlMode.touch.label, 'Touch');
      expect(SlamControlMode.touch.icon, Icons.swipe_down);
      expect(SlamControlMode.touch.caption, contains('Drag'));
      expect(SlamControlMode.touch.caption, contains('Swipe'));
    });
  });

  testWidgets('indicator shows mode icon and label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SlamControlModeIndicator(mode: SlamControlMode.accel),
        ),
      ),
    );

    expect(find.text('Phone motion'), findsOneWidget);
    expect(find.textContaining('Tilt to aim'), findsOneWidget);
    expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
  });
}
