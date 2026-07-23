import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/intro/intro_lottie_screen.dart';

void main() {
  testWidgets('intro lottie loads and finishes', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: IntroLottieScreen(onFinished: () => finished = true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(IntroLottieScreen), findsOneWidget);
    expect(find.text('WF Brand Lottie'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });
}
