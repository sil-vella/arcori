import 'package:arcori/core/theme/theme.dart';
import 'package:arcori/modules/match/state/match_snapshot_state.dart';
import 'package:arcori/modules/match/widgets/slam_result_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(SlamResultFront.resetForTest);
  tearDown(SlamResultFront.resetForTest);

  test('slamFlipFaces keeps slam order and catalog faces', () {
    const pieces = [
      MatchPieceView(
        pieceId: 'p2',
        designId: 'ANM-FOX-SER001-0002',
        ownerUserId: 'u',
        seatIndex: 1,
        faceUp: false,
        stackIndex: 1,
        imageUrl: 'assets/images/arcori/practice_arcori_002.webp',
        color: '#112233',
      ),
      MatchPieceView(
        pieceId: 'p1',
        designId: 'ANM-TIG-SER001-0001',
        ownerUserId: 'u',
        seatIndex: 0,
        faceUp: true,
        stackIndex: 0,
        imageUrl: 'assets/images/arcori/practice_arcori_001.webp',
      ),
    ];
    final faces = slamFlipFaces(
      pieces: pieces,
      lastEvent: {
        'result': 'flip',
        'outcome': {
          'flippedPieceIds': ['p1', 'missing', 'p2'],
        },
      },
    );
    expect(faces.map((f) => f.pieceId), ['p1', 'missing', 'p2']);
    expect(faces[0].imageUrl, 'assets/images/arcori/practice_arcori_001.webp');
    expect(faces[1].designId, 'missing');
    expect(faces[2].colorHex, '#112233');
  });

  test('miss event has no flip faces', () {
    expect(
      slamFlipFaces(
        pieces: const [],
        lastEvent: {'result': 'miss', 'outcome': {}},
      ),
      isEmpty,
    );
  });

  test('flight starts at center and mastery pops late', () {
    expect(slamFlipFlightT(t: 0, index: 0, count: 1), 0);
    expect(slamFlipFlightT(t: 1, index: 0, count: 1), 1);
    expect(slamMasteryPopT(0), 0);
    expect(slamMasteryPopT(0.62), 0);
    expect(slamMasteryPopT(1), 1);
    final early = slamFlipFlightT(t: 0.2, index: 1, count: 3);
    final lead = slamFlipFlightT(t: 0.2, index: 0, count: 3);
    expect(lead, greaterThan(early));
  });

  testWidgets('flip modal flies a disc and shows +1 Mastery', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showSlamResultModal(
                  context,
                  lastEvent: {
                    'result': 'flip',
                    'version': 2,
                    'outcome': {
                      'flippedPieceIds': ['p1'],
                    },
                  },
                  actorScoreDelta: 1,
                  flips: const [
                    SlamFlipFace(
                      pieceId: 'p1',
                      designId: 'ANM-TIG-SER001-0001',
                    ),
                  ],
                );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('FLIP'), findsOneWidget);
    expect(find.text('+1'), findsNothing);

    await tester.pump(AppModalMetrics.transitionDuration);
    await tester.pump(kSlamFlipFlight);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Mastery'), findsOneWidget);
    expect(find.text('1 flipped'), findsOneWidget);
  });

  testWidgets('miss modal has no mastery pop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showSlamResultModal(
                  context,
                  lastEvent: {'result': 'miss', 'version': 1},
                  actorScoreDelta: 0,
                );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('MISS'), findsOneWidget);
    expect(find.text('No flips'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
    expect(find.text('Mastery'), findsNothing);
  });

  testWidgets('end modal installs under a live slam result', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const SizedBox.shrink(),
      ),
    );
    final nav = navKey.currentState!;
    final shell = DialogRoute<void>(
      context: nav.context,
      builder: (_) => const Text('shell'),
    );
    final slam = DialogRoute<void>(
      context: nav.context,
      builder: (_) => const Text('slam-card'),
    );
    nav.push(shell);
    await tester.pump();
    nav.push(slam);
    await tester.pump();

    SlamResultFront.markPending();
    final frontReady = SlamResultFront.frontRoute();
    SlamResultFront.shellRoute = shell;
    SlamResultFront.attach(slam);
    expect(await frontReady, slam);

    final end = DialogRoute<void>(
      context: nav.context,
      builder: (_) => const Text('match-complete'),
    );
    final installed = installRouteBehindFront(
      nav,
      end,
      keepInFront: slam,
      shellUnder: shell,
    );
    await tester.pump();

    expect(installed, isTrue);
    expect(slam.isCurrent, isTrue);
    expect(end.isActive, isTrue);
    expect(end.isCurrent, isFalse);
    expect(shell.isActive, isFalse);
    expect(find.text('slam-card'), findsOneWidget);
    expect(find.text('match-complete'), findsOneWidget);
  });
}
