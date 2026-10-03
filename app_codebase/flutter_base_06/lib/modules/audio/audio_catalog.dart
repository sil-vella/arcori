import 'audio_errors.dart';

/// Stack-hit cue. Path stays empty until a clip is chosen.
const String kAudioCueSlamHit = 'slam_hit';

/// Cue key → asset path. Null or empty means the cue is registered with no clip.
const Map<String, String?> kAudioCueAssets = {
  kAudioCueSlamHit: null,
};

sealed class AudioCueDecision {
  const AudioCueDecision({required this.code, required this.cue});

  final String code;
  final String cue;
}

final class AudioCueSkip extends AudioCueDecision {
  const AudioCueSkip({required super.code, required super.cue});
}

final class AudioCueReady extends AudioCueDecision {
  const AudioCueReady({required super.cue, required this.assetPath})
      : super(code: kAudioPlayed);

  final String assetPath;
}

/// Resolve a cue before any player is opened.
AudioCueDecision resolveAudioCue(String cue, {required bool muted}) {
  if (muted) {
    return AudioCueSkip(code: kAudioMuted, cue: cue);
  }
  if (!kAudioCueAssets.containsKey(cue)) {
    return AudioCueSkip(code: kAudioUnknownCue, cue: cue);
  }
  final path = kAudioCueAssets[cue];
  if (path == null || path.isEmpty) {
    return AudioCueSkip(code: kAudioNoClip, cue: cue);
  }
  return AudioCueReady(cue: cue, assetPath: path);
}
