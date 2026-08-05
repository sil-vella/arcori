import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/app_bar/app_bar_controller.dart';
import 'package:arcori/core/app_bar/app_bar_scope.dart';
import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/play/play_models.dart';
import 'package:arcori/modules/play/play_notifier.dart';
import 'package:arcori/modules/play/screens/play_screen.dart';

void main() {
  testWidgets('Play → type select → stub pipeline → idle on Play',
      (tester) async {
    final appBarController = AppBarController();
    addTearDown(appBarController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: AppBarScope(
          controller: appBarController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: PlayScreen()),
          ),
        ),
      ),
    );

    expect(find.text('Play'), findsWidgets);
    expect(find.text('Press Play to choose a match type.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    expect(find.text('Choose match type'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Quick Start'), findsOneWidget);
    expect(find.text('Special Event'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);

    await tester.tap(find.text('Quick Start'));
    await tester.pumpAndSettle();

    expect(find.text('Choose match type'), findsNothing);
    expect(find.text('Press Play to choose a match type.'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    expect(container.read(matchFlowProvider).isIdle, isTrue);
    expect(container.read(matchFlowProvider).selectedType, isNull);
    expect(container.read(matchFlowProvider).phase, MatchFlowPhase.idle);
  });
}
