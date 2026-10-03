import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../utils/dev_logger.dart';
import 'audio_catalog.dart';
import 'audio_errors.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Result of one [AudioPlayback.play] call. Branch on [code].
class AudioPlayOutcome {
  const AudioPlayOutcome({
    required this.code,
    required this.cue,
    this.message,
  });

  final String code;
  final String cue;
  final String? message;

  bool get played => code == kAudioPlayed;
}

/// Keyed one-shot playback. Match code uses this, not `just_audio`.
abstract class AudioPlayback {
  bool get isMuted;
  void setMuted(bool muted);
  Future<AudioPlayOutcome> play(String cue);
  Future<void> stopAll();
  Future<void> dispose();
}

final audioPlaybackProvider = Provider<AudioPlayback>((ref) {
  final playback = JustAudioPlayback();
  ref.onDispose(() {
    unawaited(playback.dispose());
  });
  return playback;
});

class JustAudioPlayback implements AudioPlayback {
  JustAudioPlayback({AudioPlayer Function()? playerFactory})
      : _playerFactory = playerFactory ?? AudioPlayer.new;

  final AudioPlayer Function() _playerFactory;
  final Set<AudioPlayer> _active = {};
  final Map<AudioPlayer, StreamSubscription<PlayerState>> _subs = {};
  bool _muted = false;
  bool _disposed = false;

  @override
  bool get isMuted => _muted;

  @override
  void setMuted(bool muted) {
    _muted = muted;
  }

  @override
  Future<AudioPlayOutcome> play(String cue) async {
    if (_disposed) {
      return AudioPlayOutcome(
        code: kAudioPlaybackFailed,
        cue: cue,
        message: 'disposed',
      );
    }
    final decision = resolveAudioCue(cue, muted: _muted);
    if (decision is AudioCueSkip) {
      if (LOGGING_SWITCH) {
        if (decision.code == kAudioNoClip) {
          customlog('Audio: $cue no clip');
        } else {
          customlog('Audio: play skip code=${decision.code} cue=$cue');
        }
      }
      return AudioPlayOutcome(code: decision.code, cue: cue);
    }
    final ready = decision as AudioCueReady;
    AudioPlayer? player;
    try {
      player = _playerFactory();
      _active.add(player);
      await player.setAsset(ready.assetPath);
      final captured = player;
      _subs[captured] = captured.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          unawaited(_release(captured, cue));
        }
      });
      if (LOGGING_SWITCH) {
        customlog(
          'Audio: play start code=$kAudioPlayed cue=$cue active=${_active.length}',
        );
      }
      await player.play();
      return AudioPlayOutcome(code: kAudioPlayed, cue: cue);
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('Audio: play fail code=$kAudioPlaybackFailed cue=$cue err=$e');
      }
      if (player != null) {
        await _release(player, cue);
      }
      return AudioPlayOutcome(
        code: kAudioPlaybackFailed,
        cue: cue,
        message: '$e',
      );
    }
  }

  @override
  Future<void> stopAll() async {
    final players = _active.toList();
    for (final player in players) {
      await _release(player, '');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stopAll();
  }

  Future<void> _release(AudioPlayer player, String cue) async {
    final sub = _subs.remove(player);
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (e) {
        if (LOGGING_SWITCH) {
          customlog('Audio: play cancel fail cue=$cue err=$e');
        }
      }
    }
    if (!_active.remove(player)) return;
    try {
      await player.stop();
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('Audio: play stop fail cue=$cue err=$e');
      }
    }
    try {
      await player.dispose();
    } catch (e) {
      if (LOGGING_SWITCH) {
        customlog('Audio: play dispose fail cue=$cue err=$e');
      }
    }
  }
}
