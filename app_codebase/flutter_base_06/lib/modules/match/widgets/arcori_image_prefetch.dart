import 'package:flutter/material.dart';

import '../../../core/http/media_url.dart';
import '../../../utils/dev_logger.dart';
import '../input/slam_resolver.dart' show practiceFaceDefaults;

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Media paths to warm before a match (Play screen / stack).
///
/// Includes practice faces + shared back. Pass inventory / table URLs as [extra].
/// Bundle assets stay as `assets/...`; catalog paths are absolute http(s) URLs.
List<String> collectArcoriArtUrls({Iterable<String?> extra = const []}) {
  final out = <String>{};
  void add(String? raw) {
    final path = raw?.trim() ?? '';
    if (path.isEmpty) return;
    if (isBundleAssetMedia(path)) {
      out.add(bundleAssetPath(path));
      return;
    }
    final url = resolveMediaUrl(path);
    if (url.isNotEmpty) out.add(url);
  }

  out.add(kArcoriBackAssetPath);
  for (final face in practiceFaceDefaults.values) {
    add(face['imageUrl']);
  }
  for (final raw in extra) {
    add(raw);
  }
  return out.toList(growable: false);
}

/// Decode art into Flutter's [ImageCache] so a later flip is instant.
Future<void> precacheArcoriArt(
  BuildContext context,
  Iterable<String> urls,
) async {
  var n = 0;
  for (final url in urls) {
    if (!context.mounted) return;
    final ImageProvider provider =
        isBundleAssetMedia(url) || url.startsWith('assets/')
            ? AssetImage(bundleAssetPath(url))
            : NetworkImage(url);
    await precacheImage(
      provider,
      context,
      onError: (e, _) {
        if (LOGGING_SWITCH) {
          customlog('arcoriArt: precache fail url=$url err=$e');
        }
      },
    );
    n++;
  }
  if (LOGGING_SWITCH) {
    customlog('arcoriArt: precache done count=$n/${urls.length}');
  }
}
