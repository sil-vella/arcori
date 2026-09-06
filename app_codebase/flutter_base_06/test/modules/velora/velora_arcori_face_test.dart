import 'package:arcori/core/theme/app_theme.dart';
import 'package:arcori/modules/match/widgets/arcori_cylinder.dart';
import 'package:arcori/modules/match/widgets/arcori_look.dart';
import 'package:arcori/modules/velora/velora_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DesignSummary parses catalog color for the rim', () {
    final summary = DesignSummary.fromJson({
      'internalId': 'ANM-TIG-GEN001-0001',
      'design': 'Tiger',
      'imageUrl': '/catalog-media/genesis/animals/ANM-TIG-GEN001-0001.webp',
      'color': '#C6A15B',
    });
    expect(summary.color, '#C6A15B');
    expect(
      ArcoriLook(
        designId: summary.internalId,
        imageUrl: summary.imageUrl,
        colorHex: summary.color,
      ).accent,
      const Color(0xFFC6A15B),
    );
  });

  test('DesignDetail parses catalog color and legacy', () {
    final detail = DesignDetail.fromJson({
      'internalId': 'ANM-TIG-GEN001-0001',
      'design': 'Tiger',
      'color': '#C6A15B',
      'seasonState': 'Active',
      'legacy': {
        'preservationRequirement': 500,
        'closureMilestone': 1000,
      },
    });
    expect(detail.color, '#C6A15B');
    expect(detail.legacy?.preservationRequirement, 500);
    expect(detail.legacy?.closureMilestone, 1000);
  });

  testWidgets('Velora face paints catalog rim in front of art', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: ArcoriCylinder(
              look: ArcoriLook(
                designId: 'ANM-TIG-GEN001-0001',
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
}
