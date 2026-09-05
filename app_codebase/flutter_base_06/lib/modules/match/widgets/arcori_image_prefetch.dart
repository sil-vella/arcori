import 'package:flutter/material.dart';

import '../../../core/http/media_url.dart';
import '../../../utils/dev_logger.dart';
import '../input/slam_resolver.dart' show practiceFaceDefaults;

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Absolute catalog-media URLs to warm before a match (Play screen / stack).
///
/// Always includes practice Tiger / White Tiger stubs. Pass inventory and
/// table-piece URLs as [extra].
List<String> collectArcoriArtUrls({Iterable<String?> extra = const []}) {
  final out = <String>{};
  void add(String? raw) {
    final url = resolveMediaUrl(raw);
    if (url.isNotEmpty) out.add(url);
  }

  for (final face in practiceFaceDefaults.values) {
    add(face['imageUrl']);
  }
  for (final raw in extra) {
    add(raw);
  }
  return out.toList(growable: false);
}

/// Decode catalog art into Flutter's [ImageCache] so a later flip is instant.
Future<void> precacheArcoriArt(
  BuildContext context,
  Iterable<String> urls,
) async {
  var n = 0;
  for (final url in urls) {
    if (!context.mounted) return;
    await precacheImage(
      NetworkImage(url),
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
