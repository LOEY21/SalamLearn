import 'package:audioplayers/audioplayers.dart';

/// Music and growth sound for the Good Deed Tree.
class GoodDeedTreeAudio {
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _bloom = AudioPlayer();
  bool _enabled = true;
  bool _disposed = false;

  Future<void> startMusic() async {
    if (_disposed || !_enabled) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.18);
      if (_disposed || !_enabled) return;
      await _music.play(
        AssetSource('audio/good_deed_tree/audio_bgm_garden_blooming.mp3'),
      );
    } catch (_) {
      // An unavailable audio device should not interrupt the game.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      await startMusic();
    } else {
      try {
        await Future.wait([_music.stop(), _bloom.stop()]);
      } catch (_) {
        // Players may already be stopped while leaving the game.
      }
    }
  }

  Future<void> playBloom() async {
    if (_disposed || !_enabled) return;
    try {
      await _bloom.stop();
      if (_disposed || !_enabled) return;
      await _bloom.play(
        AssetSource('audio/good_deed_tree/audio_sfx_magic_bloom.mp3'),
      );
    } catch (_) {
      // Visual feedback still works if the effect cannot play.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([_music.dispose(), _bloom.dispose()]);
  }
}
