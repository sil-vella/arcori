import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/http/media_url.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';

/// Face shown for the player: Kin Lottie, then identity art, then a stored URL.
String? resolveProfileFaceUrl({
  String? kinLottieUrl,
  String? identityAvatarUrl,
  String? userAvatarUrl,
}) {
  final kin = kinLottieUrl?.trim() ?? '';
  if (kin.isNotEmpty) return kin;
  final identity = identityAvatarUrl?.trim() ?? '';
  if (identity.isNotEmpty) return identity;
  final user = userAvatarUrl?.trim() ?? '';
  if (user.isNotEmpty) return user;
  return null;
}

/// Circular profile media: Kin Lottie (``.json``) or raster image URL.
///
/// No [ArcoriCylinder] — just the face art clipped to a circle.
class ProfileFaceAvatar extends StatelessWidget {
  const ProfileFaceAvatar({
    this.avatarUrl,
    this.size = 72,
    super.key,
  });

  final String? avatarUrl;
  final double size;

  static bool isLottieAvatarUrl(String? url) {
    final path = (url ?? '').trim().split('?').first.toLowerCase();
    return path.endsWith('.json');
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(avatarUrl);
    Widget child;
    if (resolved.isEmpty) {
      child = AppMarkIcon(AppMarks.avari, size: size * 0.72);
    } else if (isLottieAvatarUrl(resolved)) {
      child = Lottie.network(
        resolved,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) =>
            AppMarkIcon(AppMarks.avari, size: size * 0.72),
      );
    } else {
      child = Image.network(
        resolved,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) =>
            AppMarkIcon(AppMarks.avari, size: size * 0.72),
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
