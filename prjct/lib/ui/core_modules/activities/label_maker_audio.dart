import 'package:audioplayers/audioplayers.dart';

/// Looped room music and spoken vocab words for the Label Maker sessions.
class LabelMakerAudio {
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();
  bool _enabled = true;
  bool _disposed = false;

  /// Says one vocab word; a newer word cuts off the one still playing.
  Future<void> playWord(String asset) async {
    if (_disposed || !_enabled) return;
    try {
      await _voice.stop();
      await _voice.play(AssetSource(asset));
    } catch (_) {
      // A missing recording (e.g. the window) just stays silent.
    }
  }

  Future<void> startMusic() async {
    if (_disposed || !_enabled) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.18);
      if (_disposed || !_enabled) return;
      await _music.play(
        AssetSource('audio/label_maker/audio_bgm_label_maker_room.mp3'),
      );
    } catch (_) {
      // Missing audio output should not interrupt the activity.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      await startMusic();
    } else {
      try {
        await _music.stop();
        await _voice.stop();
      } catch (_) {
        // The player may already be stopping as the activity closes.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _music.dispose();
    await _voice.dispose();
  }
}
