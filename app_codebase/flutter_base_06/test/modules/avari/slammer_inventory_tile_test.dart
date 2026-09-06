import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/avari/avari_models.dart';
import 'package:arcori/modules/avari/widgets/slammer_inventory_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows slammer name and catalog attributes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SlammerInventoryTile(
            item: AvariInventoryItem(
              designId: 'SLM-STR-GEN001-0001',
              displayName: 'Starter Slammer',
              color: '#C6A15B',
              gameplayAttributes: const SlammerGameplayAttributes(
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
    expect(find.textContaining('Impact'), findsOneWidget);
    expect(find.textContaining('Precision'), findsOneWidget);
    expect(find.textContaining('Control'), findsOneWidget);
    expect(find.textContaining('Recovery'), findsOneWidget);
    expect(find.textContaining('Spread'), findsOneWidget);
  });
}
