import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/avari/avari_models.dart';
import 'package:arcori/modules/avari/widgets/arcori_container_bank.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zero mastery does not count toward a container', () {
    expect(
      ArcoriContainerBank.countTowardContainers(const [
        AvariInventoryItem(
          designId: 'a',
          displayName: 'Held',
          masteryPoints: 4,
        ),
        AvariInventoryItem(
          designId: 'b',
          displayName: 'Lost',
          masteryPoints: 0,
        ),
      ]),
      1,
    );
  });

  testWidgets('one container per 100, with progress on the next', (
    tester,
  ) async {
    await tester.pumpWidget(_bank(250));
    await tester.pump();

    expect(find.byKey(const ValueKey('arcori-container-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('arcori-container-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('arcori-container-progress')), findsOneWidget);
    expect(find.text('50 / 100'), findsOneWidget);
  });

  testWidgets('no Arcori still shows an empty container', (tester) async {
    await tester.pumpWidget(_bank(0));
    await tester.pump();

    expect(find.byKey(const ValueKey('arcori-container-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('arcori-container-0')), findsNothing);
    expect(find.text('0 / 100'), findsOneWidget);
  });

  testWidgets('an exact hundred keeps the next container empty', (
    tester,
  ) async {
    await tester.pumpWidget(_bank(100));
    await tester.pump();

    expect(find.byKey(const ValueKey('arcori-container-0')), findsOneWidget);
    expect(find.text('0 / 100'), findsOneWidget);
  });
}

Widget _bank(int count) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: _ContainerSlot.height,
        child: ArcoriContainerBank(count: count),
      ),
    ),
  );
}

/// Matches the bank slot so the horizontal list has a bounded height.
abstract final class _ContainerSlot {
  static const double height = 200;
}
