import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:arcori/core/app_bar/app_bar_controller.dart';
import 'package:arcori/core/app_bar/app_bar_scope.dart';
import 'package:arcori/core/bottom_nav/bottom_nav_controller.dart';
import 'package:arcori/core/bottom_nav/bottom_nav_scope.dart';
import 'package:arcori/core/navigation/app_paths.dart';
import 'package:arcori/core/screen/shell_chrome_controller.dart';
import 'package:arcori/core/screen/shell_chrome_scope.dart';
import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/play/play_models.dart';
import 'package:arcori/modules/play/screens/play_screen.dart';

void main() {
  testWidgets('Play hub shows featured + match types inline (no type popup)',
      (tester) async {
    final appBarController = AppBarController();
    final bottomNavController = BottomNavController();
    addTearDown(appBarController.dispose);
    addTearDown(bottomNavController.dispose);
    addTearDown(resetShellChromeController);

    final router = GoRouter(
      initialLocation: AppPaths.play,
      routes: [
        GoRoute(
          path: AppPaths.play,
          builder: (context, state) => const PlayScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: AppBarScope(
          controller: appBarController,
          child: BottomNavScope(
            controller: bottomNavController,
            child: ShellChromeScope(
              controller: shellChromeController,
              child: MaterialApp.router(
                theme: AppTheme.light,
                routerConfig: router,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Featured'), findsOneWidget);
    expect(find.text('Match types'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Quick Start'), findsWidgets);
    expect(find.text('Special Event'), findsWidgets);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Choose match type'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Play'), findsNothing);
    expect(kPlayFeaturedTypes, containsAll([
      MatchType.quickStart,
      MatchType.specialEvent,
    ]));
  });
}
