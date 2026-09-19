/// Series / generation / serial parsed from a catalog [designId].
///
/// Wire shape: `THEME-CODE-SERnnn-GENnnn-####`
/// e.g. `ANM-TIG-SER001-GEN001-0001` (SER = series, GEN = generation).
/// Legacy ids without GEN (`ANM-TIG-SER001-0001`) treat generation as I.
class ArcoriDesignLabels {
  const ArcoriDesignLabels({
    required this.series,
    required this.generation,
    required this.serial,
  });

  final String series;
  final String generation;
  final String serial;

  factory ArcoriDesignLabels.fromDesignId(String designId) {
    final id = designId.trim();
    if (id.isEmpty) {
      return const ArcoriDesignLabels(
        series: '—',
        generation: '—',
        serial: '—',
      );
    }
    final parts = id.split('-');
    final serial = parts.isNotEmpty ? parts.last : id;

    var serToken = '';
    var genToken = '';
    for (final p in parts) {
      final upper = p.toUpperCase();
      if (upper.length > 3 && upper.startsWith('SER')) {
        serToken = upper;
      } else if (upper.length > 3 && upper.startsWith('GEN')) {
        genToken = upper;
      }
    }

    final serN = int.tryParse(serToken.replaceFirst('SER', '')) ?? 0;
    final genN = int.tryParse(genToken.replaceFirst('GEN', '')) ??
        (genToken.isEmpty ? 1 : 0);

    final series = switch (serN) {
      0 => 'Creation',
      1 => 'Genesis',
      2 => 'Pioneers',
      3 => 'Foundations',
      4 => 'Civilizations',
      _ => serToken.isNotEmpty ? serToken : '—',
    };
    final generation =
        genN > 0 ? _roman(genN) : (genToken.isNotEmpty ? genToken : '—');

    return ArcoriDesignLabels(
      series: series,
      generation: generation,
      serial: serial,
    );
  }

  static String _roman(int n) {
    const table = <int, String>{
      1: 'I',
      2: 'II',
      3: 'III',
      4: 'IV',
      5: 'V',
      6: 'VI',
      7: 'VII',
      8: 'VIII',
      9: 'IX',
      10: 'X',
    };
    return table[n] ?? n.toString();
  }
}
