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

/// True while [active] carries `inputLockedUntil` (cleared after post-slam anim).
///
/// Next seat is already in `active.seatIndex`, but UI/input stay locked until
/// the server (or practice runner) clears this after [animHoldMs].
bool activeInputLocked(Map<String, dynamic>? active) {
  if (active == null) return false;
  final raw = active['inputLockedUntil']?.toString();
  return raw != null && raw.isNotEmpty;
}

Map<String, dynamic> activeWithAnimLock(
  Map<String, dynamic> active,
  Duration hold,
) {
  final next = Map<String, dynamic>.from(active);
  if (hold <= Duration.zero) {
    next.remove('inputLockedUntil');
    return next;
  }
  next['inputLockedUntil'] =
      DateTime.now().toUtc().add(hold).toIso8601String();
  return next;
}

Map<String, dynamic> activeWithoutAnimLock(Map<String, dynamic>? active) {
  if (active == null) return const {'seatIndex': 0, 'action': 'slam'};
  final next = Map<String, dynamic>.from(active)..remove('inputLockedUntil');
  return next;
}
