import 'package:flutter/material.dart';

import '../../core/http/media_url.dart';

/// Transparent hand art. Contain keeps the wrist, which a disc crop would cut.
class HandArt extends StatelessWidget {
  const HandArt({
    required this.imageUrl,
    required this.width,
    required this.height,
    super.key,
  });

  final String? imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final path = (imageUrl ?? '').trim();
    final child = path.isEmpty
        ? const SizedBox.shrink()
        : isBundleAssetMedia(path)
        ? Image.asset(
            bundleAssetPath(path),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          )
        : Image.network(
            resolveMediaUrl(path),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
    return SizedBox(width: width, height: height, child: child);
  }
}
