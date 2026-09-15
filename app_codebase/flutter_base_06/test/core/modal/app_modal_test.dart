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

    testWidgets('dismiss removes buried popup under a newer modal', (tester) async {
      BuildContext? buriedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    AppModal.showCenteredShell<void>(
                      context,
                      title: 'Buried',
                      showCloseButton: false,
                      child: Builder(
                        builder: (dialogContext) {
                          buriedContext = dialogContext;
                          return const Text('first overlay');
                        },
                      ),
                    );
                  },
                  child: const Text('Open buried'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open buried'));
      await tester.pumpAndSettle();
      expect(find.text('first overlay'), findsOneWidget);

      final outer = tester.element(find.text('Open buried'));
      AppModal.showCenteredShell<void>(
        outer,
        title: 'On top',
        showCloseButton: false,
        child: const Text('second overlay'),
      );
      await tester.pumpAndSettle();
      expect(find.text('second overlay'), findsOneWidget);
      expect(find.text('first overlay'), findsOneWidget);

      AppModal.dismiss(buriedContext!);
      await tester.pumpAndSettle();

      expect(find.text('first overlay'), findsNothing);
      expect(find.text('second overlay'), findsOneWidget);
    });

    testWidgets('dismiss no-ops inactive popup without popping newer modal',
        (tester) async {
      BuildContext? firstContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    AppModal.showCenteredShell<void>(
                      context,
                      title: 'First',
                      showCloseButton: false,
                      child: Builder(
                        builder: (dialogContext) {
                          firstContext = dialogContext;
                          return const Text('first overlay');
                        },
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final outer = tester.element(find.text('Open'));
      // Pop first, then show second — first context is inactive.
      AppModal.dismiss(firstContext!);
      await tester.pumpAndSettle();

      AppModal.showCenteredShell<void>(
        outer,
        title: 'Second',
        showCloseButton: false,
        child: const Text('second overlay'),
      );
      await tester.pumpAndSettle();
      expect(find.text('second overlay'), findsOneWidget);

      // Stale dismiss must not steal the newer modal.
      AppModal.dismiss(firstContext!);
      await tester.pumpAndSettle();
      expect(find.text('second overlay'), findsOneWidget);
    });
  });
}
