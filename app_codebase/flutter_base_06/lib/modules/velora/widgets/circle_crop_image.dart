import 'package:flutter/material.dart';

import '../../../core/http/media_url.dart';
import '../../../core/theme/theme.dart';

/// True circle crop: parent must be square; image fills via [SizedBox.expand].
class CircleCropImage extends StatelessWidget {
  const CircleCropImage({required this.imageUrl, super.key});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(imageUrl);
    final scheme = context.appColorScheme;
    return ClipOval(
      child: SizedBox.expand(
        child: url.isEmpty
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}
