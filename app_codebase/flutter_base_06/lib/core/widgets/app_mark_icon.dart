import 'package:flutter/material.dart';

/// Painted marks for destinations and catalog sections.
abstract final class AppMarks {
  static const avari = 'assets/images/icons/avari_profile.webp';
  static const trove = 'assets/images/icons/trove.webp';
  static const market = 'assets/images/icons/market.webp';
  static const museum = 'assets/images/icons/museum.webp';
  static const arcori = 'assets/images/icons/arcori.webp';
  static const slammers = 'assets/images/icons/slammers.webp';
  static const velora = 'assets/images/icons/velora_world.webp';
  static const arena = 'assets/images/icons/matches.webp';
}

class AppMarkIcon extends StatelessWidget {
  const AppMarkIcon(
    this.asset, {
    super.key,
    this.size = 22,
  });

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
