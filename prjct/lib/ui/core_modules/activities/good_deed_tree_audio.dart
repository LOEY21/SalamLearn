import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

const _dir = 'audio/good_deed_tree/';

/// Music, growth sound and narration for the Good Deed Tree.
class GoodDeedTreeAudio {
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _bloom = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();
  bool _enabled = true;
  bool _disposed = false;
  int _generation = 0;
  Completer<void> _cut = Completer();

  Future<void> startMusic() async {
    if (_disposed || !_enabled) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.06);
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
        _interrupt();
        await Future.wait([_music.stop(), _bloom.stop(), _voice.stop()]);
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

  /// Says [clips] back to back; a newer call cuts off whatever is playing.
  /// Completes when the last clip ends or the narration is cut off.
  Future<void> say(List<String> clips) async {
    if (_disposed || !_enabled) return;
    _interrupt();
    final generation = _generation;
    final cut = _cut.future;
    for (final clip in clips) {
      if (_disposed || !_enabled || generation != _generation) return;
      try {
        await _voice.stop();
        final done = _voice.onPlayerComplete.first;
        await _play(clip);
        await Future.any([done, cut]);
      } catch (_) {
        // A missing recording just stays silent.
      }
    }
  }

  /// The title has no Tagalog take, so it falls back to the English clip.
  Future<void> _play(String clip) async {
    final local = localizedVoice(clip);
    try {
      await _voice.play(AssetSource('$_dir$local'));
    } catch (_) {
      if (local == clip) rethrow;
      await _voice.play(AssetSource('$_dir$clip'));
    }
  }

  void _interrupt() {
    ++_generation;
    _cut.complete();
    _cut = Completer();
  }

  Future<void> stopVoice() async {
    _interrupt();
    try {
      await _voice.stop();
    } catch (_) {
      // The player may already be disposed as the game leaves.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _interrupt();
    await Future.wait([_music.dispose(), _bloom.dispose(), _voice.dispose()]);
  }
}
