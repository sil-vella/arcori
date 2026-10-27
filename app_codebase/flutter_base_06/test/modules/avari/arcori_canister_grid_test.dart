import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/avari/avari_models.dart';
import 'package:arcori/modules/avari/circulating_browse.dart';
import 'package:arcori/modules/avari/widgets/arcori_canister_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a canister reports that canister', (tester) async {
    final canisters = packCirculatingCanisters([
      const AvariInventoryItem(designId: 'a', displayName: 'Amber', masteryPoints: 4),
    ]);
    CirculatingCanister? tapped;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ArcoriCanisterGrid(
            canisters: canisters,
            onTap: (canister) => tapped = canister,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('circulating-canister-0')));
    expect(tapped?.filling, isTrue);
    expect(tapped?.items.single.designId, 'a');
    expect(find.text('1 / 100'), findsOneWidget);
    expect(find.text('Tap to open'), findsOneWidget);
  });
}
