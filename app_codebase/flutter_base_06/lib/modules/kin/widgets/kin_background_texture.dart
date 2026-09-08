import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../kin_backgrounds.dart';

/// Procedural texture overlay for solid / gradient Kin backgrounds.
class KinBackgroundTexturePainter extends CustomPainter {
  KinBackgroundTexturePainter({
    required this.textureId,
    required this.intensity,
  });

  final String textureId;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (textureId == kKinBgTextureNone || intensity <= 0.01) return;
    final a = intensity.clamp(0.0, 1.0);
    switch (textureId) {
      case kKinBgTextureGrain:
        _paintGrain(canvas, size, a);
        break;
      case kKinBgTextureNoise:
        _paintNoise(canvas, size, a);
        break;
      case kKinBgTextureLines:
        _paintLines(canvas, size, a);
        break;
      case kKinBgTextureDots:
        _paintDots(canvas, size, a);
        break;
      case kKinBgTextureWeave:
        _paintWeave(canvas, size, a);
        break;
    }
  }

  void _paintGrain(Canvas canvas, Size size, double a) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(42);
    final count = (size.width * size.height / 28).round().clamp(80, 2200);
    for (var i = 0; i < count; i++) {
      final light = rng.nextBool();
      paint.color = (light ? Colors.white : Colors.black).withValues(
        alpha: a * (light ? 0.22 : 0.18),
      );
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.4 + 0.4,
        paint,
      );
    }
  }

  void _paintNoise(Canvas canvas, Size size, double a) {
    final paint = Paint()..style = PaintingStyle.fill;
    const step = 4.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        final n = _hash01(x.toInt(), y.toInt());
        paint.color = Colors.white.withValues(alpha: a * n * 0.28);
        canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
      }
    }
  }

  void _paintLines(Canvas canvas, Size size, double a) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.black.withValues(alpha: a * 0.28);
    const spacing = 8.0;
    final extent = size.longestSide * 1.5;
    for (var i = -extent; i < extent; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  void _paintDots(Canvas canvas, Size size, double a) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: a * 0.32);
    const step = 10.0;
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  void _paintWeave(Canvas canvas, Size size, double a) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: a * 0.22);
    const spacing = 7.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    paint.color = Colors.black.withValues(alpha: a * 0.18);
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  double _hash01(int x, int y) {
    var n = x * 374761393 + y * 668265263;
    n = (n ^ (n >> 13)) * 1274126177;
    n ^= n >> 16;
    return (n & 0x7fffffff) / 0x7fffffff;
  }

  @override
  bool shouldRepaint(covariant KinBackgroundTexturePainter oldDelegate) {
    return oldDelegate.textureId != textureId ||
        oldDelegate.intensity != intensity;
  }
}

class KinBackgroundTextureLayer extends StatelessWidget {
  const KinBackgroundTextureLayer({
    required this.textureId,
    required this.intensity,
    super.key,
  });

  final String textureId;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (textureId == kKinBgTextureNone || intensity <= 0.01) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: KinBackgroundTexturePainter(
        textureId: textureId,
        intensity: intensity,
      ),
      child: const SizedBox.expand(),
    );
  }
}
