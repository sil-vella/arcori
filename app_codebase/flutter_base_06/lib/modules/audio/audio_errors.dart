/// Client playback codes. Shape is `{module}/{reason}`.
///
/// These never cross HTTP. Callers branch on [code] and keep going; a missing
/// clip must not interrupt a slam.
const String kAudioPlayed = 'audio/played';
const String kAudioMuted = 'audio/muted';
const String kAudioNoClip = 'audio/no_clip';
const String kAudioUnknownCue = 'audio/unknown_cue';
const String kAudioPlaybackFailed = 'audio/playback_failed';

const Set<String> kAudioModuleCodes = {
  kAudioPlayed,
  kAudioMuted,
  kAudioNoClip,
  kAudioUnknownCue,
  kAudioPlaybackFailed,
};
