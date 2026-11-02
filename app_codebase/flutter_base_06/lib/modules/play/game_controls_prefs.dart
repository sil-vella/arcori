/// Local Game Controls prefs — equipped slammer + exclusive slam input mode.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../match/input/slam_motion_capability.dart';
import '../match/input/slam_resolver.dart' show ensureGen001DesignId;
import '../match/state/match_notifier.dart';

/// Exclusive slam control: phone motion vs touch.
enum SlamControlMode {
  accel,
  touch;

  static SlamControlMode? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in SlamControlMode.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

class GameControlsPrefs {
  GameControlsPrefs({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const equippedSlammerKey = 'arcori_equipped_slammer_id';
  static const equippedHandKey = 'arcori_equipped_hand_id';
  static const slamControlModeKey = 'arcori_slam_control_mode';

  final FlutterSecureStorage _storage;

  Future<String> readEquippedSlammerId() async {
    final v = await _storage.read(key: equippedSlammerKey);
    if (v == null || v.isEmpty) return stubSlammerId;
    final canonical = ensureGen001DesignId(v);
    if (canonical != v) {
      await _storage.write(key: equippedSlammerKey, value: canonical);
    }
    return canonical;
  }

  Future<void> writeEquippedSlammerId(String id) async {
    final trimmed = ensureGen001DesignId(id.trim());
    if (trimmed.isEmpty) return;
    await _storage.write(key: equippedSlammerKey, value: trimmed);
  }

  /// Empty means no hand. A hand is optional; a slammer is not.
  Future<String> readEquippedHandId() async {
    final v = await _storage.read(key: equippedHandKey);
    if (v == null || v.trim().isEmpty) return '';
    final canonical = ensureGen001DesignId(v);
    if (canonical != v) {
      await _storage.write(key: equippedHandKey, value: canonical);
    }
    return canonical;
  }

  Future<void> writeEquippedHandId(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: equippedHandKey);
      return;
    }
    await _storage.write(
      key: equippedHandKey,
      value: ensureGen001DesignId(trimmed),
    );
  }

  Future<SlamControlMode> readSlamControlMode({
    required bool motionAvailable,
  }) async {
    final raw = await _storage.read(key: slamControlModeKey);
    final parsed = SlamControlMode.tryParse(raw);
    if (parsed != null) {
      if (parsed == SlamControlMode.accel && !motionAvailable) {
        return SlamControlMode.touch;
      }
      return parsed;
    }
    return motionAvailable ? SlamControlMode.accel : SlamControlMode.touch;
  }

  Future<void> writeSlamControlMode(SlamControlMode mode) async {
    await _storage.write(key: slamControlModeKey, value: mode.name);
  }
}

final gameControlsPrefsProvider = Provider<GameControlsPrefs>((ref) {
  return GameControlsPrefs();
});

/// Snapshot of equipped loadout for Play / match capture.
class GameControlsState {
  const GameControlsState({
    required this.equippedSlammerId,
    required this.equippedHandId,
    required this.slamControlMode,
    required this.loaded,
  });

  final String equippedSlammerId;

  /// Catalog hand id, or empty when no hand is equipped.
  final String equippedHandId;
  final SlamControlMode slamControlMode;
  final bool loaded;

  static const initial = GameControlsState(
    equippedSlammerId: stubSlammerId,
    equippedHandId: '',
    slamControlMode: SlamControlMode.touch,
    loaded: false,
  );

  GameControlsState copyWith({
    String? equippedSlammerId,
    String? equippedHandId,
    SlamControlMode? slamControlMode,
    bool? loaded,
  }) {
    return GameControlsState(
      equippedSlammerId: equippedSlammerId ?? this.equippedSlammerId,
      equippedHandId: equippedHandId ?? this.equippedHandId,
      slamControlMode: slamControlMode ?? this.slamControlMode,
      loaded: loaded ?? this.loaded,
    );
  }
}

class GameControlsNotifier extends Notifier<GameControlsState> {
  @override
  GameControlsState build() {
    Future.microtask(_load);
    return GameControlsState.initial;
  }

  GameControlsPrefs get _prefs => ref.read(gameControlsPrefsProvider);

  Future<void> _load() async {
    final motion = await probeSlamShakeAvailable();
    final slammer = await _prefs.readEquippedSlammerId();
    final hand = await _prefs.readEquippedHandId();
    final mode = await _prefs.readSlamControlMode(motionAvailable: motion);
    state = GameControlsState(
      equippedSlammerId: slammer,
      equippedHandId: hand,
      slamControlMode: mode,
      loaded: true,
    );
  }

  Future<void> setEquippedHandId(String id) async {
    final trimmed = id.trim();
    final canonical = trimmed.isEmpty ? '' : ensureGen001DesignId(trimmed);
    await _prefs.writeEquippedHandId(canonical);
    state = state.copyWith(equippedHandId: canonical, loaded: true);
  }

  Future<void> setEquippedSlammerId(String id) async {
    final canonical = ensureGen001DesignId(id.trim());
    await _prefs.writeEquippedSlammerId(canonical);
    state = state.copyWith(equippedSlammerId: canonical, loaded: true);
  }

  Future<void> setSlamControlMode(SlamControlMode mode) async {
    final motion = await probeSlamShakeAvailable();
    final effective =
        mode == SlamControlMode.accel && !motion ? SlamControlMode.touch : mode;
    await _prefs.writeSlamControlMode(effective);
    state = state.copyWith(slamControlMode: effective, loaded: true);
  }

  Future<void> reload() => _load();
}

final gameControlsProvider =
    NotifierProvider<GameControlsNotifier, GameControlsState>(
  GameControlsNotifier.new,
);
