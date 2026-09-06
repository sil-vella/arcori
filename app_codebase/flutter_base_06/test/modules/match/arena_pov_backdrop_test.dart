import 'package:arcori/modules/match/widgets/arena_pov_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rest camera is 1 (no upscale of a screen-fitted bitmap)', () {
    expect(arenaPovContainScale(stackFit: 1.0), 1.0);
  });

  test('full stack zoom-out is the fit floor (contain of the oversized mural)', () {
    expect(arenaPovContainScale(stackFit: kStackPovFitMin), kStackPovFitMin);
    expect(arenaPovContainScale(stackFit: 0.01), kStackPovFitMin);
  });

  test('mural scale tracks stack fit 1:1 down to the floor', () {
    const fit = 0.5;
    expect(arenaPovContainScale(stackFit: fit), fit);
  });

  test('discs paint at rest Ø; camera only scales them down', () {
    const restPx = 72.0;
    expect(arenaWorldDiscScale(), 1.0);
    expect(
      restPx * arenaWorldDiscScale() * arenaPovContainScale(stackFit: 1.0),
      closeTo(restPx, 1e-9),
    );
  });

  test('zoom damper eases toward a step target instead of jumping', () {
    var value = 1.0;
    var velocity = 0.0;
    for (var i = 0; i < 12; i++) {
      final next = povZoomSmoothDamp(
        current: value,
        target: kStackPovFitMin,
        velocity: velocity,
        dt: 1 / 60,
      );
      value = next.value;
      velocity = next.velocity;
    }
    expect(value, lessThan(1.0));
    expect(value, greaterThan(kStackPovFitMin + 0.02));
    for (var i = 0; i < 180; i++) {
      final next = povZoomSmoothDamp(
        current: value,
        target: kStackPovFitMin,
        velocity: velocity,
        dt: 1 / 60,
      );
      value = next.value;
      velocity = next.velocity;
    }
    expect(value, closeTo(kStackPovFitMin, 0.01));
  });

  test('disc on-screen size and mural share the same camera scale', () {
    const restPx = 72.0;
    const fit = 0.5;
    final mural = arenaPovContainScale(stackFit: fit);
    final discOnScreen = restPx * arenaWorldDiscScale() * mural;
    expect(discOnScreen, closeTo(restPx * fit, 1e-9));
    expect(mural, fit);
  });

  testWidgets('arena mural is opaque and stacked under the table pieces',
      (tester) async {
    final pov = ValueNotifier<double>(1.0);
    addTearDown(pov.dispose);
    final stackAreaKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: Stack(
            children: [
              Positioned.fill(
                child: ArenaPovBackdrop(
                  imageUrl: 'http://127.0.0.1/missing.webp',
                  povScale: pov,
                  stackAreaKey: stackAreaKey,
                  stackLayer: const ColoredBox(
                    color: Color(0xFFFF0000),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              Positioned(
                key: stackAreaKey,
                left: 0,
                right: 0,
                top: 290,
                height: 220,
                child: const SizedBox.expand(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == const Color(0x73000000),
      ),
      findsNothing,
    );

    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byType(ArenaPovBackdrop),
        matching: find.byType(Stack),
      ).first,
    );
    expect(stack.children.length, 2);
    expect(stack.children.first, isA<Positioned>());
    expect(
      find.descendant(
        of: find.byType(ArenaPovBackdrop),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ArenaPovBackdrop),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFFFF0000),
        ),
      ),
      findsOneWidget,
    );
  });
}
