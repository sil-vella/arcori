import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/avari/avari_models.dart';
import 'package:arcori/modules/avari/widgets/slammer_inventory_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows slammer name, mastery, and catalog attributes', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SlammerInventoryTile(
            onTap: () => taps += 1,
            item: const AvariInventoryItem(
              designId: 'SLM-STR-SER001-0001',
              displayName: 'Starter Slammer',
              color: '#C6A15B',
              masteryPoints: 12.4,
              mintReach: 750,
              gameplayAttributes: SlammerGameplayAttributes(
                impact: 5,
                precision: 5,
                control: 5,
                recovery: 5,
                spread: 5,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Starter Slammer'), findsOneWidget);
    expect(find.textContaining('Mastery'), findsOneWidget);
    expect(find.textContaining('12.4/750'), findsOneWidget);
    expect(find.textContaining('Impact'), findsOneWidget);
    expect(find.textContaining('Precision'), findsOneWidget);
    expect(find.textContaining('Control'), findsOneWidget);
    expect(find.textContaining('Recovery'), findsOneWidget);
    expect(find.textContaining('Spread'), findsOneWidget);

    await tester.tap(find.text('Starter Slammer'));
    await tester.pump();
    expect(taps, 1);
  });
}
