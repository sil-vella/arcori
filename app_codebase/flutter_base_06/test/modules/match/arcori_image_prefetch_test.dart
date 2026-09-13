import 'package:arcori/core/http/media_url.dart';
import 'package:arcori/modules/match/widgets/arcori_image_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collectArcoriArtUrls includes practice faces + shared back', () {
    final urls = collectArcoriArtUrls();
    expect(urls, isNotEmpty);
    expect(urls, contains(kArcoriBackAssetPath));
    expect(
      urls.any((u) => u.contains('practice_arcori_001')),
      isTrue,
    );
    expect(
      urls.any((u) => u.contains('practice_arcori_002')),
      isTrue,
    );
    expect(
      urls.any((u) => u.contains('practice_arcori_003')),
      isTrue,
    );
    expect(
      urls.any((u) => u.contains('ANM-TIG')),
      isFalse,
    );
  });

  test('collectArcoriArtUrls adds inventory extras once', () {
    const extra =
        '/catalog-media/001_genesis/animals/ANM-TIG-SER001-0001.webp';
    final urls = collectArcoriArtUrls(extra: [extra, extra]);
    final tiger = resolveMediaUrl(extra);
    expect(urls.where((u) => u == tiger), hasLength(1));
  });
}
