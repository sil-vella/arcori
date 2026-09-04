/// Grace-period helper for match `active.graceEndsAt` (UTC ISO-8601).
library;

/// True while the snapshot still carries `graceEndsAt` (server clears it).
///
/// Do not arm slam input from local clock alone — a slightly-early client will
/// commit during server grace, get rejected, and burn the first turn.
bool activeInGracePeriod(Map<String, dynamic>? active) {
  if (active == null) return false;
  final raw = active['graceEndsAt']?.toString();
  return raw != null && raw.isNotEmpty;
}

Duration? graceRemaining(Map<String, dynamic>? active) {
  if (active == null) return null;
  final raw = active['graceEndsAt']?.toString();
  if (raw == null || raw.isEmpty) return null;
  final ends = DateTime.tryParse(raw)?.toUtc();
  if (ends == null) return null;
  final remaining = ends.difference(DateTime.now().toUtc());
  if (remaining.isNegative) return Duration.zero;
  return remaining;
}

Map<String, dynamic> activeWithGrace(
  Duration grace, {
  int seatIndex = 0,
}) {
  return {
    'seatIndex': seatIndex,
    'action': 'slam',
    'graceEndsAt': DateTime.now().toUtc().add(grace).toIso8601String(),
  };
}

Map<String, dynamic> activeWithoutGrace(Map<String, dynamic>? active) {
  if (active == null) return const {'seatIndex': 0, 'action': 'slam'};
  final next = Map<String, dynamic>.from(active)..remove('graceEndsAt');
  return next;
}
