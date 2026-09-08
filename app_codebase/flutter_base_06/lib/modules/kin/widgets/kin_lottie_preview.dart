import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/http/media_url.dart';
import '../../../core/theme/theme.dart';
import '../kin_backgrounds.dart';
import 'kin_background_texture.dart';

/// 30% black scrim over Kin scene backgrounds (preview + disc face).
const double kKinBackgroundScrimOpacity = 0.30;

/// Background + optional texture + scrim + Kin Lottie.
class KinSceneStack extends StatelessWidget {
  const KinSceneStack({
    this.lottieUrl,
    this.file,
    this.delegates,
    this.scene,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.fit = BoxFit.contain,
    super.key,
  });

  final String? lottieUrl;
  final File? file;
  final LottieDelegates? delegates;

  /// Preferred: solid / gradient / image (+ texture) scene.
  final KinBackgroundScene? scene;

  /// Legacy solid fill when [scene] is null.
  final Color? backgroundColor;
  final String? backgroundImageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.appColorScheme;
    final resolved = scene;
    final imageUrl = resolveMediaUrl(
      resolved?.imageUrl ?? backgroundImageUrl,
    );
    final hasImage = imageUrl.isNotEmpty;
    final colorA = resolved?.adjustedColorA ??
        backgroundColor ??
        scheme.surfaceContainerHighest;
    final colorB = resolved?.adjustedColorB;
    final isGradient = resolved?.isGradient == true && colorB != null;
    final angle = resolved?.angleDegrees ?? kKinBgAngleDefault;

    Widget lottieChild;
    final local = file;
    if (local != null) {
      lottieChild = Lottie.file(
        local,
        fit: fit,
        delegates: delegates,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      final lottieResolved = resolveMediaUrl(lottieUrl);
      if (lottieResolved.isEmpty) {
        lottieChild = Center(
          child: Icon(
            Icons.auto_awesome_outlined,
            color: scheme.onSurfaceVariant,
          ),
        );
      } else {
        lottieChild = Lottie.network(
          lottieResolved,
          fit: fit,
          delegates: delegates,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              Icons.auto_awesome_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      }
    }

    Widget fill;
    if (hasImage) {
      fill = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(color: colorA),
      );
    } else if (isGradient) {
      final aligns = kinBackgroundGradientAlignments(angle);
      fill = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: aligns.$1,
            end: aligns.$2,
            colors: [colorA, colorB!],
          ),
        ),
      );
    } else {
      fill = ColoredBox(color: colorA);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        fill,
        if (resolved != null && resolved.hasTexture)
          KinBackgroundTextureLayer(
            textureId: resolved.textureId,
            intensity: resolved.textureIntensity,
          ),
        const ColoredBox(
          color: Color.fromRGBO(0, 0, 0, kKinBackgroundScrimOpacity),
        ),
        lottieChild,
      ],
    );
  }
}

/// Rectangular Kin preview with scene background.
class KinLottiePreview extends StatelessWidget {
  const KinLottiePreview({
    this.lottieUrl,
    this.file,
    this.delegates,
    this.scene,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.height = 220,
    super.key,
  });

  final String? lottieUrl;
  final File? file;
  final LottieDelegates? delegates;
  final KinBackgroundScene? scene;
  final Color? backgroundColor;
  final String? backgroundImageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.sm);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: KinSceneStack(
          lottieUrl: lottieUrl,
          file: file,
          delegates: delegates,
          scene: scene,
          backgroundColor: backgroundColor,
          backgroundImageUrl: backgroundImageUrl,
        ),
      ),
    );
  }
}
