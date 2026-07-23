import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/app_test_boot.dart';

void main() {
  group('Nav push/pop chrome', () {
    testWidgets('root shows hamburger on the right and no back button', (tester) async {
      await bootTestApp(tester);

      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Open sample module'), findsOneWidget);
    });

    testWidgets('push shows back on the left and pop returns home', (tester) async {
      await bootTestApp(tester);

      await tester.tap(find.text('Open sample module'));
      await tester.pumpAndSettle();

      expect(find.text('Sample feature'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Open sample module'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('drawer push navigates and back unwinds the stack', (tester) async {
      await bootTestApp(tester);

      await tester.tap(find.text('Open sample module'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.text('WS Demo'));
      await tester.pumpAndSettle();

      expect(find.text('WebSocket demo'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Sample feature'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Open sample module'), findsOneWidget);
    });

    testWidgets('app bar title follows the current screen and updates on pop', (tester) async {
      await bootTestApp(tester);

      expect(find.text('Home'), findsOneWidget);

      await tester.tap(find.text('Open sample module'));
      await tester.pumpAndSettle();

      expect(find.text('Sample module'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Sample module'), findsNothing);
    });

    testWidgets('re-selecting the current drawer row only closes the drawer', (tester) async {
      await bootTestApp(tester);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      expect(find.text('Open sample module'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
