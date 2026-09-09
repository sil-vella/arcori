/// Series / generation / serial parsed from a catalog [designId].
///
/// Wire shape: `THEME-CODE-GENnnn-ssss` (e.g. `ANM-TIG-GEN001-0001`).
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

    var genToken = '';
    for (final p in parts) {
      if (p.length > 3 && p.startsWith('GEN')) {
        genToken = p;
        break;
      }
    }
    final n = int.tryParse(genToken.replaceFirst('GEN', '')) ?? 0;
    final generation = n > 0 ? _roman(n) : (genToken.isNotEmpty ? genToken : '—');
    final series = switch (n) {
      1 => 'Genesis',
      2 => 'Pioneers',
      _ => genToken.isNotEmpty ? genToken : '—',
    };
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
