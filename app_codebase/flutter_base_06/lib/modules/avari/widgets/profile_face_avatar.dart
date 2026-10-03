import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/http/media_url.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';

/// Circular profile media: Kin Lottie (``.json``) or raster image URL.
///
/// No [ArcoriCylinder] — just the face art clipped to a circle.
class ProfileFaceAvatar extends StatelessWidget {
  const ProfileFaceAvatar({
    this.avatarUrl,
    this.size = 72,
    this.fallbackIcon = Icons.person_outline,
    this.fallbackLabel,
    super.key,
  });

  final String? avatarUrl;
  final double size;
  final IconData fallbackIcon;

  /// When [avatarUrl] is empty, show this letter instead of [fallbackIcon].
  final String? fallbackLabel;

  static bool isLottieAvatarUrl(String? url) {
    final path = (url ?? '').trim().split('?').first.toLowerCase();
    return path.endsWith('.json');
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(avatarUrl);
    final iconSize = size * 0.4;
    Widget child;
    if (resolved.isEmpty) {
      final label = (fallbackLabel ?? '').trim();
      child = label.isNotEmpty
          ? Center(
              child: Text(
                label[0].toUpperCase(),
                style: context.appTypography.title.copyWith(
                  color: AppChrome.onSurface,
                  fontSize: size * 0.35,
                ),
              ),
            )
          : Icon(
              fallbackIcon,
              size: iconSize.clamp(18, 48),
              color: AppChrome.onSurfaceMuted,
            );
    } else if (isLottieAvatarUrl(resolved)) {
      child = Lottie.network(
        resolved,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(
          fallbackIcon,
          size: iconSize.clamp(18, 48),
          color: AppChrome.onSurfaceMuted,
        ),
      );
    } else {
      child = Image.network(
        resolved,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(
          fallbackIcon,
          size: iconSize.clamp(18, 48),
          color: AppChrome.onSurfaceMuted,
        ),
      );
    }

    return ClipOval(
      child: ColoredBox(
        color: AppChrome.fieldFill,
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }
}
