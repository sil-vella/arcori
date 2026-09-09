import 'dart:math';

/// Offline practice AI pool — embedded in client; no API/DB fetch.
///
/// Exactly two profiles (practice is always human + these two AI seats).
/// Ids match `feed_ai_players.py` uuid5(NAMESPACE_URL, "arcori:ai-player:{email}").
///
/// - ai0013@ai.arcori.local (ai_0013)
/// - ai0115@ai.arcori.local (ai_0115)
const List<String> practiceAiPoolUserIds = [
  '798a2f60-ebef-5a4e-ae6c-f49037d1d00a', // ai_0013
  '59b69ee3-7815-5a5d-84b1-865e1df05be2', // ai_0115
];

/// Picks [count] distinct userIds from [practiceAiPoolUserIds].
List<String> pickPracticeAiUserIds({
  Random? random,
  int count = 2,
}) {
  if (count < 0 || count > practiceAiPoolUserIds.length) {
    throw ArgumentError.value(
      count,
      'count',
      'must be 0..${practiceAiPoolUserIds.length}',
    );
  }
  final rng = random ?? Random();
  final shuffled = List<String>.from(practiceAiPoolUserIds)..shuffle(rng);
  return shuffled.take(count).toList(growable: false);
}
