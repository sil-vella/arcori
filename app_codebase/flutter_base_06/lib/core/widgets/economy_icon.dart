import 'package:flutter/material.dart';

/// Shared marks for Gold Arcori, fragments, matches, and flips.
enum EconomyMark {
  goldArcori,
  fragment,
  match,
  flip,
}

class EconomyIcon extends StatelessWidget {
  const EconomyIcon(
    this.mark, {
    super.key,
    this.size = 36,
    this.opacity = 1,
  });

  final EconomyMark mark;
  final double size;
  final double opacity;

  static const String _goldArcori = 'assets/images/icons/gold_arcori.webp';
  static const String _fragment = 'assets/images/icons/gold_fragment.webp';
  static const String _match = 'assets/images/icons/matches.webp';
  static const String _flip = 'assets/images/icons/flips.webp';

  String get _asset {
    switch (mark) {
      case EconomyMark.goldArcori:
        return _goldArcori;
      case EconomyMark.fragment:
        return _fragment;
      case EconomyMark.match:
        return _match;
      case EconomyMark.flip:
        return _flip;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    if (opacity >= 1) return image;
    return Opacity(opacity: opacity, child: image);
  }
}
