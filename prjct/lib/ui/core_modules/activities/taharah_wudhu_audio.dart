import 'package:audioplayers/audioplayers.dart';

/// Shared water ambience for Taharah Adventure and Wudhu Master.
class TaharahWudhuAudio {
  final AudioPlayer _music = AudioPlayer();
  bool _enabled = true;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed || !_enabled) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.18);
      if (_disposed || !_enabled) return;
      await _music.play(
        AssetSource('audio/taharah_wudhu/audio_bgm_water_ambient.mp3'),
      );
    } catch (_) {
      // An unavailable audio device must not block the activity.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      await start();
    } else {
      try {
        await _music.stop();
      } catch (_) {
        // The player may already be stopping while the activity closes.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _music.dispose();
  }
}
