import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/bottom_nav/bottom_nav_controller.dart';
import 'package:arcori/core/bottom_nav/contracts/register_bottom_nav_contract.dart';

import '../../helpers/app_test_boot.dart';

void main() {
  group('BottomNavController scope enforcement', () {
    test('locationMatchesScope accepts exact and nested paths', () {
      const scope = BottomNavModuleScope(
        moduleId: 'ws_demo',
        pathPrefixes: ['/ws-demo'],
      );

      expect(
        BottomNavController.locationMatchesScope('/ws-demo', scope),
        isTrue,
      );
      expect(
        BottomNavController.locationMatchesScope('/ws-demo/settings', scope),
        isTrue,
      );
      expect(
        BottomNavController.locationMatchesScope('/sample', scope),
        isFalse,
      );
    });
  });

  group('ShellBottomBar screen scope', () {
    testWidgets('home screen hides bottom actions by default', (tester) async {
      await bootTestApp(tester);

      expect(find.byTooltip('Connect both WS'), findsNothing);
      expect(find.byIcon(Icons.link), findsNothing);
    });

    testWidgets('ws demo screen shows module bottom actions', (tester) async {
      await bootTestApp(tester);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.text('WS Demo'));
      await tester.pumpAndSettle();

      expect(find.text('WebSocket demo'), findsOneWidget);
      expect(find.byTooltip('Connect both WS'), findsOneWidget);
    });

    testWidgets('sample screen does not show ws bottom actions', (tester) async {
      await bootTestApp(tester);

      await tester.tap(find.text('Open sample module'));
      await tester.pumpAndSettle();

      expect(find.text('Sample feature'), findsOneWidget);
      expect(find.byTooltip('Connect both WS'), findsNothing);
      expect(find.byTooltip('Ping Dart'), findsNothing);
    });

    testWidgets('popping from ws demo hides bottom actions on home', (tester) async {
      await bootTestApp(tester);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.text('WS Demo'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Connect both WS'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Open sample module'), findsOneWidget);
      expect(find.byTooltip('Connect both WS'), findsNothing);
    });
    testWidgets('example module shows home navigation action', (tester) async {
      await bootTestApp(tester);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Example module'));
      await tester.pumpAndSettle();

      expect(find.text('example_module'), findsOneWidget);
      expect(find.byTooltip('Go to Home'), findsOneWidget);

      await tester.tap(find.byTooltip('Go to Home'));
      await tester.pumpAndSettle();

      expect(find.text('Open sample module'), findsOneWidget);
      expect(find.byTooltip('Go to Home'), findsNothing);
    });
  });
}
