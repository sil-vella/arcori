import 'package:arcori/modules/match/widgets/arcori_design_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses SER + GEN design id', () {
    final labels =
        ArcoriDesignLabels.fromDesignId('ANM-TIG-SER001-GEN001-0001');
    expect(labels.series, 'Genesis');
    expect(labels.generation, 'I');
    expect(labels.serial, '0001');
  });

  test('parses civilizations series', () {
    final labels =
        ArcoriDesignLabels.fromDesignId('CAP-RCX-SER004-GEN001-0001');
    expect(labels.series, 'Civilizations');
    expect(labels.generation, 'I');
    expect(labels.serial, '0001');
  });

  test('parses pioneers series with gen II', () {
    final labels =
        ArcoriDesignLabels.fromDesignId('SPC-DSR-SER002-GEN002-0008');
    expect(labels.series, 'Pioneers');
    expect(labels.generation, 'II');
    expect(labels.serial, '0008');
  });

  test('legacy id without GEN defaults generation to I', () {
    final labels = ArcoriDesignLabels.fromDesignId('ANM-TIG-SER001-0001');
    expect(labels.series, 'Genesis');
    expect(labels.generation, 'I');
    expect(labels.serial, '0001');
  });

  test('empty id yields placeholders', () {
    final labels = ArcoriDesignLabels.fromDesignId('');
    expect(labels.series, '—');
    expect(labels.generation, '—');
    expect(labels.serial, '—');
  });
}
