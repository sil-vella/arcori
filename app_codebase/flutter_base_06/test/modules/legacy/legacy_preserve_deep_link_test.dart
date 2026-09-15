import 'package:flutter_test/flutter_test.dart';

import 'package:arcori/core/navigation/app_paths.dart';
import 'package:arcori/modules/legacy/legacy_preserve_flow.dart';

void main() {
  group('LegacyPreserveDeepLinkHandler.paramsFromUri', () {
    test('parses custom scheme host', () {
      final uri = Uri.parse(
        'arcori://legacy-preserve-complete?intentId=i1&orderId=o1',
      );
      final p = LegacyPreserveDeepLinkHandler.paramsFromUri(uri);
      expect(p?.intentId, 'i1');
      expect(p?.orderId, 'o1');
    });

    test('parses https app link path', () {
      final uri = Uri.parse(
        'https://app.example.com${AppPaths.legacyPreserveComplete}'
        '?intentId=i2&orderId=o2',
      );
      final p = LegacyPreserveDeepLinkHandler.paramsFromUri(uri);
      expect(p?.intentId, 'i2');
      expect(p?.orderId, 'o2');
    });

    test('rejects missing params', () {
      final uri = Uri.parse('arcori://legacy-preserve-complete?intentId=i1');
      expect(LegacyPreserveDeepLinkHandler.paramsFromUri(uri), isNull);
    });
  });
}
