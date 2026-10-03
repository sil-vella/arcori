import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/http/media_url.dart';
import '../../../core/theme/theme.dart';
import '../kin_backgrounds.dart';
import 'kin_background_texture.dart';

/// 30% black scrim over Kin scene backgrounds (preview + disc face).
const double kKinBackgroundScrimOpacity = 0.30;

/// Background + optional texture + scrim + Kin Lottie.
///
/// Composed JSON bytes are cached: slider tint rebuilds must **not**
/// re-`utf8.encode` / re-parse the Lottie (that OOMs while dragging levels).
class KinSceneStack extends StatefulWidget {
  const KinSceneStack({
    this.lottieUrl,
    this.file,
    this.composedLottieJson,
    this.delegates,
    this.scene,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.fit = BoxFit.contain,
    this.animate = true,
    super.key,
  });

  final String? lottieUrl;
  final File? file;

  /// When set, preferred over [lottieUrl] / [file] (embed compose only).
  final String? composedLottieJson;
  final LottieDelegates? delegates;

  /// Preferred: solid / gradient / image (+ texture) scene.
  final KinBackgroundScene? scene;

  /// Legacy solid fill when [scene] is null.
  final Color? backgroundColor;
  final String? backgroundImageUrl;
  final BoxFit fit;

  /// When false, freezes the current frame (tint sliders stay cheap).
  final bool animate;

  @override
  State<KinSceneStack> createState() => _KinSceneStackState();
}

class _KinSceneStackState extends State<KinSceneStack> {
  String? _cachedJson;
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _syncBytes(widget.composedLottieJson);
  }

  @override
  void didUpdateWidget(covariant KinSceneStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBytes(widget.composedLottieJson);
  }

  void _syncBytes(String? json) {
    if (json == null || json.isEmpty) {
      _cachedJson = null;
      _cachedBytes = null;
      return;
    }
    // Same content → keep the same [Uint8List] so [Lottie.memory] does not reload.
    if (json == _cachedJson && _cachedBytes != null) return;
    _cachedJson = json;
    _cachedBytes = Uint8List.fromList(utf8.encode(json));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.appColorScheme;
    final resolved = widget.scene;
    final imageUrl = resolveMediaUrl(
      resolved?.imageUrl ?? widget.backgroundImageUrl,
    );
    final hasImage = imageUrl.isNotEmpty;
    final hasOverlay = resolved != null ||
        widget.backgroundColor != null ||
        hasImage;

    Widget lottieChild;
    final bytes = _cachedBytes;
    final local = widget.file;
    if (bytes != null && bytes.isNotEmpty) {
      lottieChild = Lottie.memory(
        bytes,
        fit: widget.fit,
        delegates: widget.delegates,
        animate: widget.animate,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (local != null) {
      lottieChild = Lottie.file(
        local,
        fit: widget.fit,
        delegates: widget.delegates,
        animate: widget.animate,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      final lottieResolved = resolveMediaUrl(widget.lottieUrl);
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
          fit: widget.fit,
          delegates: widget.delegates,
          animate: widget.animate,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              Icons.auto_awesome_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      }
    }

    // Claimed / saved Kin Lotties own their background — no Flutter fill.
    if (!hasOverlay) {
      return RepaintBoundary(child: lottieChild);
    }

    final colorA = resolved?.adjustedColorA ??
        widget.backgroundColor ??
        scheme.surfaceContainerHighest;
    final colorB = resolved?.adjustedColorB;
    final isGradient = resolved?.isGradient == true && colorB != null;
    final angle = resolved?.angleDegrees ?? kKinBgAngleDefault;

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
            colors: [colorA, colorB],
          ),
        ),
      );
    } else {
      fill = ColoredBox(color: colorA);
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          fill,
          if (resolved != null && resolved.hasTexture)
            KinBackgroundTextureLayer(
              textureId: resolved.textureId,
              intensity: resolved.textureIntensity,
            ),
          // Scrim only for live customize overlay — baked Lottie BGs already include art.
          if (resolved != null)
            const ColoredBox(
              color: Color.fromRGBO(0, 0, 0, kKinBackgroundScrimOpacity),
            ),
          lottieChild,
        ],
      ),
    );
  }
}

/// Rectangular Kin preview with scene background.
class KinLottiePreview extends StatelessWidget {
  const KinLottiePreview({
    this.lottieUrl,
    this.file,
    this.composedLottieJson,
    this.delegates,
    this.scene,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.height = 220,
    this.animate = true,
    super.key,
  });

  final String? lottieUrl;
  final File? file;
  final String? composedLottieJson;
  final LottieDelegates? delegates;
  final KinBackgroundScene? scene;
  final Color? backgroundColor;
  final String? backgroundImageUrl;
  final double height;
  final bool animate;

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
          composedLottieJson: composedLottieJson,
          delegates: delegates,
          scene: scene,
          backgroundColor: backgroundColor,
          backgroundImageUrl: backgroundImageUrl,
          animate: animate,
        ),
      ),
    );
  }
}
