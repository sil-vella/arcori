import 'package:arcori/modules/match/widgets/arcori_design_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses genesis design id into series / gen / serial', () {
    final labels = ArcoriDesignLabels.fromDesignId('ANM-TIG-GEN001-0001');
    expect(labels.series, 'Genesis');
    expect(labels.generation, 'I');
    expect(labels.serial, '0001');
  });

  test('parses pioneers generation II', () {
    final labels = ArcoriDesignLabels.fromDesignId('SPC-DSR-GEN002-0008');
    expect(labels.series, 'Pioneers');
    expect(labels.generation, 'II');
    expect(labels.serial, '0008');
  });

  test('empty id yields placeholders', () {
    final labels = ArcoriDesignLabels.fromDesignId('');
    expect(labels.series, '—');
    expect(labels.generation, '—');
    expect(labels.serial, '—');
  });
}
