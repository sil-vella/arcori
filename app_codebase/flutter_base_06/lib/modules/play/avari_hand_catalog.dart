/// First three Avari hands. Art pose: fingers left, palm center, wrist right.
library;

import '../match/input/slam_resolver.dart';

class AvariHandOption {
  const AvariHandOption({
    required this.id,
    required this.label,
    required this.imageUrl,
    required this.aspectWidthOverHeight,
  });

  final String id;
  final String label;
  final String imageUrl;

  /// Source image width / height. The play chrome sizes the slot from this.
  final double aspectWidthOverHeight;
}

/// Catalog ids match `series/avari_hands/hands.json`.
const List<AvariHandOption> kAvariHands = [
  AvariHandOption(
    id: 'ARC-HND-CLG-SER008-GEN001-0001',
    label: 'Celestial Gold Hand',
    imageUrl: '/catalog-media/008_avari_hands/hands/HND-CLG-SER008-0001.webp',
    aspectWidthOverHeight: 768 / 512,
  ),
  AvariHandOption(
    id: 'ARC-HND-CPR-SER008-GEN001-0002',
    label: 'Copper Arcane Hand',
    imageUrl: '/catalog-media/008_avari_hands/hands/HND-CPR-SER008-0002.webp',
    aspectWidthOverHeight: 1,
  ),
  AvariHandOption(
    id: 'ARC-HND-LCY-SER008-GEN001-0003',
    label: 'Luminous Cybernetic Hand',
    imageUrl: '/catalog-media/008_avari_hands/hands/HND-LCY-SER008-0003.webp',
    aspectWidthOverHeight: 768 / 512,
  ),
];

/// Same rule as `modules/avari/ai_hands.py`: two of three user ids own one
/// shop hand. UUID bytes are read big-endian so Dart and Python agree.
String? assignedAiHandId(String userId) {
  final ids = [for (final hand in kAvariHands) hand.id];
  final raw = userId.trim();
  if (raw.isEmpty || ids.isEmpty) return null;
  final n = _stableUserInt(raw);
  if (n % BigInt.from(3) == BigInt.zero) return null;
  final index = (n ~/ BigInt.from(3)) % BigInt.from(ids.length);
  return ids[index.toInt()];
}

BigInt _stableUserInt(String userId) {
  final hex = userId.replaceAll('-', '');
  final looksUuid = hex.length == 32 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
  if (looksUuid) return BigInt.parse(hex, radix: 16);
  var n = BigInt.zero;
  final mask = (BigInt.one << 128) - BigInt.one;
  for (final code in userId.codeUnits) {
    n = (n * BigInt.from(131) + BigInt.from(code)) & mask;
  }
  return n;
}

AvariHandOption? avariHandFor(String? id) {
  final canonical = ensureGen001DesignId((id ?? '').trim());
  if (canonical.isEmpty) return null;
  for (final hand in kAvariHands) {
    if (hand.id == canonical) return hand;
  }
  return null;
}
