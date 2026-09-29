import 'package:audioplayers/audioplayers.dart';

/// Looped forest ambience for Allah's Creation Hunt.
class CreationHuntAudio {
  final AudioPlayer _music = AudioPlayer();
  bool _enabled = true;
  bool _disposed = false;

  Future<void> startMusic() async {
    if (_disposed || !_enabled) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.2);
      if (_disposed || !_enabled) return;
      await _music.play(
        AssetSource('audio/sound_detective/forest_ambient.mp3'),
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
      } catch (_) {
        // The player may already be stopping as the activity closes.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _music.dispose();
  }
}
