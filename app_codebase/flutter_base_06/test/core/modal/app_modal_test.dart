import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/modal/modal.dart';
import 'package:arcori/core/theme/app_theme.dart';

void main() {
  group('AppModal', () {
    testWidgets('showCenteredShell displays and dismisses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      AppModal.showCenteredShell<void>(
                        context,
                        title: 'Confirm',
                        child: const Text('Delete this item?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Delete this item?'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('showFullScreenShell covers viewport', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    AppModal.showFullScreenShell<void>(
                      context,
                      title: 'Wizard',
                      child: const Text('Step one'),
                    );
                  },
                  child: const Text('Full screen'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Full screen'));
      await tester.pumpAndSettle();

      expect(find.text('Wizard'), findsOneWidget);
      expect(find.text('Step one'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Wizard'), findsNothing);
    });
  });
}
