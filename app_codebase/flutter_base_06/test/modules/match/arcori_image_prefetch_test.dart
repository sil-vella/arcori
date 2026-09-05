import 'package:arcori/core/http/media_url.dart';
import 'package:arcori/modules/match/widgets/arcori_image_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collectArcoriArtUrls always includes practice stubs', () {
    final urls = collectArcoriArtUrls();
    expect(urls, isNotEmpty);
    expect(
      urls.any((u) => u.contains('ANM-TIG-GEN001-0001')),
      isTrue,
    );
    expect(
      urls.any((u) => u.contains('ANM-WTI-GEN001-0002')),
      isTrue,
    );
  });

  test('collectArcoriArtUrls adds inventory extras once', () {
    const extra =
        '/catalog-media/genesis/animals/ANM-TIG-GEN001-0001.webp';
    final urls = collectArcoriArtUrls(extra: [extra, extra]);
    final tiger = resolveMediaUrl(extra);
    expect(urls.where((u) => u == tiger), hasLength(1));
  });
}
