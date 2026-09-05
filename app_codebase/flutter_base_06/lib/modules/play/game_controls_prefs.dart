/// Local Game Controls prefs — equipped slammer + exclusive slam input mode.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../match/input/slam_motion_capability.dart';
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
  static const slamControlModeKey = 'arcori_slam_control_mode';

  final FlutterSecureStorage _storage;

  Future<String> readEquippedSlammerId() async {
    final v = await _storage.read(key: equippedSlammerKey);
    if (v == null || v.isEmpty) return stubSlammerId;
    return v;
  }

  Future<void> writeEquippedSlammerId(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: equippedSlammerKey, value: trimmed);
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
    required this.slamControlMode,
    required this.loaded,
  });

  final String equippedSlammerId;
  final SlamControlMode slamControlMode;
  final bool loaded;

  static const initial = GameControlsState(
    equippedSlammerId: stubSlammerId,
    slamControlMode: SlamControlMode.touch,
    loaded: false,
  );

  GameControlsState copyWith({
    String? equippedSlammerId,
    SlamControlMode? slamControlMode,
    bool? loaded,
  }) {
    return GameControlsState(
      equippedSlammerId: equippedSlammerId ?? this.equippedSlammerId,
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
    final mode = await _prefs.readSlamControlMode(motionAvailable: motion);
    state = GameControlsState(
      equippedSlammerId: slammer,
      slamControlMode: mode,
      loaded: true,
    );
  }

  Future<void> setEquippedSlammerId(String id) async {
    await _prefs.writeEquippedSlammerId(id);
    state = state.copyWith(equippedSlammerId: id.trim(), loaded: true);
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
