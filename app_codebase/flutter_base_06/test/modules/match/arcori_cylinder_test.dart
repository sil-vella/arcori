import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/match/widgets/arcori_cylinder.dart';
import 'package:arcori/modules/match/widgets/arcori_look.dart';
import 'package:arcori/modules/match/widgets/arcori_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog hex drives rim; inner line stays in-family', () {
    const look = ArcoriLook(
      designId: 'ARC-ANI-GEN001-0001',
      colorHex: '#C6A15B',
    );
    expect(look.accent, const Color(0xFFC6A15B));
    expect(look.innerLineColor, arcoriBackInnerLineColor(look.backColor));
  });

  group('arcoriBackInnerLineColor', () {
    test('light gold back gets a darker same-hue line', () {
      const gold = Color(0xFFC6A15B);
      final line = arcoriBackInnerLineColor(gold);
      final backHsl = HSLColor.fromColor(gold);
      final lineHsl = HSLColor.fromColor(line);
      expect(backHsl.lightness, greaterThan(kArcoriBackLightnessPivot));
      expect(lineHsl.lightness, lessThan(backHsl.lightness));
      expect(_hueDelta(backHsl.hue, lineHsl.hue), lessThan(1.5));
    });

    test('dark maroon back gets a lighter same-hue line', () {
      const maroon = Color(0xFF7A3142);
      final line = arcoriBackInnerLineColor(maroon);
      final backHsl = HSLColor.fromColor(maroon);
      final lineHsl = HSLColor.fromColor(line);
      expect(backHsl.lightness, lessThan(kArcoriBackLightnessPivot));
      expect(lineHsl.lightness, greaterThan(backHsl.lightness));
      expect(_hueDelta(backHsl.hue, lineHsl.hue), lessThan(1.5));
    });

    test('light ivory back gets a darker line', () {
      const ivory = Color(0xFFD8CDB8);
      final line = arcoriBackInnerLineColor(ivory);
      expect(
        HSLColor.fromColor(line).lightness,
        lessThan(HSLColor.fromColor(ivory).lightness),
      );
    });
  });

  testWidgets('face-up paints rim in front of the face', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: ArcoriCylinder(
              look: ArcoriLook(
                designId: 'ARC-ANI-GEN001-0001',
                colorHex: '#C6A15B',
              ),
              size: 72,
              showThickness: false,
            ),
          ),
        ),
      ),
    );

    final paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
          (w) => w.painter is ArcoriRimPainter,
        );
    final painter = paint.painter! as ArcoriRimPainter;
    expect(painter.rimColor, const Color(0xFFC6A15B));
    expect(painter.paintInnerLine, isFalse);
  });

  testWidgets('back face paints auto-contrast inner line at rim', (tester) async {
    const look = ArcoriLook(
      designId: 'ARC-ANI-GEN001-0001',
      colorHex: '#C6A15B',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: ArcoriCylinder(
              look: look,
              size: 72,
              faceUp: false,
              showThickness: false,
            ),
          ),
        ),
      ),
    );

    final paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
          (w) => w.painter is ArcoriRimPainter,
        );
    final painter = paint.painter! as ArcoriRimPainter;
    expect(painter.paintInnerLine, isTrue);
    expect(painter.innerLineWidth, kArcoriInnerLineWidth);
    expect(painter.innerLineColor, look.innerLineColor);
  });
}

double _hueDelta(double a, double b) {
  final d = (a - b).abs();
  return d > 180 ? 360 - d : d;
}
