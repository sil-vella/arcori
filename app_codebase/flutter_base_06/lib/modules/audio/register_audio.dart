import 'audio_catalog.dart';
import 'audio_errors.dart';

/// Client audio has no routes or WebSocket. Bootstrap checks the cue catalog
/// and that every module code is namespaced `audio/…`.
void registerAudioModule() {
  for (final code in kAudioModuleCodes) {
    if (!code.startsWith('audio/')) {
      throw StateError('Audio code must be namespaced audio/…: $code');
    }
  }
  if (!kAudioCueAssets.containsKey(kAudioCueSlamHit)) {
    throw StateError('Audio catalog missing cue $kAudioCueSlamHit');
  }
}
