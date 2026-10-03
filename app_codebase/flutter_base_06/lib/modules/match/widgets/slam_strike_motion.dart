import 'package:flutter/animation.dart';

/// Peak scale at the halfway beat (closer to the camera).
const double kSlamStrikeScalePeak = 1.45;

/// Fraction of seat-to-stack distance covered in the first half.
const double kSlamStrikeMidTravel = 0.30;

/// Travel along home → impact for a raw clock [t] in 0..1.
///
/// First half eases out and only covers [kSlamStrikeMidTravel]. Second half
/// eases in through the rest of the distance.
double slamStrikeTravel(double t) {
  final u = t.clamp(0.0, 1.0);
  if (u <= 0.5) {
    final local = Curves.easeOut.transform(u / 0.5);
    return kSlamStrikeMidTravel * local;
  }
  final local = Curves.easeIn.transform((u - 0.5) / 0.5);
  return kSlamStrikeMidTravel + (1.0 - kSlamStrikeMidTravel) * local;
}

/// Disc scale for a raw clock [t] in 0..1. Peaks at halfway, then returns to 1.
double slamStrikeScale(double t) {
  final u = t.clamp(0.0, 1.0);
  if (u <= 0.5) {
    final local = Curves.easeOut.transform(u / 0.5);
    return 1.0 + (kSlamStrikeScalePeak - 1.0) * local;
  }
  final local = Curves.easeIn.transform((u - 0.5) / 0.5);
  return kSlamStrikeScalePeak + (1.0 - kSlamStrikeScalePeak) * local;
}
