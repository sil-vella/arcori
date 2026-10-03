import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/modules/audio/audio_catalog.dart';
import 'package:arcori/modules/audio/audio_errors.dart';
import 'package:arcori/modules/audio/audio_playback.dart';
import 'package:arcori/modules/audio/register_audio.dart';

void main() {
  group('resolveAudioCue', () {
    test('muted skips with audio/muted', () {
      final decision = resolveAudioCue(kAudioCueSlamHit, muted: true);
      expect(decision, isA<AudioCueSkip>());
      expect(decision.code, kAudioMuted);
    });

    test('slam_hit with empty path is audio/no_clip', () {
      final decision = resolveAudioCue(kAudioCueSlamHit, muted: false);
      expect(decision, isA<AudioCueSkip>());
      expect(decision.code, kAudioNoClip);
    });

    test('unknown cue is audio/unknown_cue', () {
      final decision = resolveAudioCue('missing_cue', muted: false);
      expect(decision, isA<AudioCueSkip>());
      expect(decision.code, kAudioUnknownCue);
    });
  });

  group('JustAudioPlayback', () {
    test('play slam_hit without clip does not throw', () async {
      final playback = JustAudioPlayback();
      final outcome = await playback.play(kAudioCueSlamHit);
      expect(outcome.code, kAudioNoClip);
      expect(outcome.played, isFalse);
      await playback.dispose();
    });

    test('mute skips before opening a player', () async {
      final playback = JustAudioPlayback();
      playback.setMuted(true);
      final outcome = await playback.play(kAudioCueSlamHit);
      expect(outcome.code, kAudioMuted);
      await playback.dispose();
    });

    test('unknown cue does not throw', () async {
      final playback = JustAudioPlayback();
      final outcome = await playback.play('no_such_cue');
      expect(outcome.code, kAudioUnknownCue);
      await playback.dispose();
    });
  });

  test('registerAudioModule accepts catalog', () {
    expect(registerAudioModule, returnsNormally);
  });
}
