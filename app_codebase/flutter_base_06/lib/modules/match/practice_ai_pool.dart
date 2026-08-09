import 'dart:math';

/// Offline practice AI pool — embedded in client; no API/DB fetch.
///
/// Ids match `feed_ai_players.py` uuid5(NAMESPACE_URL, "arcori:ai-player:{email}")
/// from a fixed sample of `ai_players_500.json` (seed Random(42) at implement time).
///
/// Pool emails / usernames (for humans reading code):
/// - ai0013@ai.arcori.local (ai_0013)
/// - ai0053@ai.arcori.local (ai_0053)
/// - ai0058@ai.arcori.local (ai_0058)
/// - ai0072@ai.arcori.local (ai_0072)
/// - ai0115@ai.arcori.local (ai_0115)
/// - ai0126@ai.arcori.local (ai_0126)
/// - ai0141@ai.arcori.local (ai_0141)
/// - ai0328@ai.arcori.local (ai_0328)
/// - ai0378@ai.arcori.local (ai_0378)
/// - ai0380@ai.arcori.local (ai_0380)
const List<String> practiceAiPoolUserIds = [
  '798a2f60-ebef-5a4e-ae6c-f49037d1d00a', // ai_0013
  '850f84dc-e55d-5e63-b72f-dec77f736811', // ai_0053
  'b6a11dfc-a749-5421-b6fe-a318076635f3', // ai_0058
  '7a59d595-fbb6-578a-9d92-6379bd8b4b05', // ai_0072
  '59b69ee3-7815-5a5d-84b1-865e1df05be2', // ai_0115
  'cee20841-665c-550b-a566-fe2fef18c7de', // ai_0126
  '3dd9ea4e-5520-571a-9c8d-a6675021d3d4', // ai_0141
  'c992955e-a04e-5b84-888a-a9e5ac22ae4b', // ai_0328
  'eb1be6c7-9424-5222-b16b-b154dfc06ae3', // ai_0378
  'a1150cdf-9dba-566e-87d6-5b2dc1871162', // ai_0380
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
