import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

/// Shared water ambience for Taharah Adventure and Wudhu Master, plus the
/// wudhu narration.
class TaharahWudhuAudio {
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();
  bool _enabled = true;
  bool _disposed = false;

  /// Bumped by every new line, stop and mute, so a running [sayAll] knows
  /// it was cut.
  int _gen = 0;
  Completer<void>? _line;

  /// Ends the [sayAll] line in flight, if any.
  void _cut() {
    _gen++;
    final line = _line;
    if (line != null && !line.isCompleted) line.complete();
  }

  Future<void> start() async {
    if (_disposed || !_enabled) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      // Full volume: the water ambience is recorded ~27 dB quieter than the
      // other games' music (-40 dBFS), so 0.06 left it all but silent. At
      // 1.0 it still sits well under the narration (-20 to -26 dBFS).
      await _music.setVolume(1.0);
      if (_disposed || !_enabled) return;
      await _music.play(
        AssetSource('audio/taharah_wudhu/audio_bgm_water_ambient.mp3'),
      );
    } catch (_) {
      // An unavailable audio device must not block the activity.
    }
  }

  /// The game's title, said on the start screen like every other game.
  static const title = 'taharah_adventure.mp3';

  /// Says one wudhu clip; a newer one cuts off the one still playing.
  Future<void> say(String clip) async {
    if (_disposed || !_enabled) return;
    _cut();
    try {
      await _voice.stop();
      final local = localizedVoice(clip);
      try {
        await _voice.play(AssetSource('audio/taharah_wudhu/$local'));
      } catch (_) {
        // No Tagalog take: the English one rather than silence.
        if (local == clip) rethrow;
        await _voice.play(AssetSource('audio/taharah_wudhu/$clip'));
      }
    } catch (_) {
      // A missing recording just stays silent.
    }
  }

  /// Says [clips] back to back, calling [onLine] as each one starts. A new
  /// line, a stop or mute cuts it. Resolves true only if all were said.
  Future<bool> sayAll(List<String> clips, void Function(int i) onLine) async {
    final gen = ++_gen;
    for (var i = 0; i < clips.length; i++) {
      if (_disposed || !_enabled || gen != _gen) return false;
      onLine(i);
      final done = _line = Completer<void>();
      void end() {
        if (!done.isCompleted) done.complete();
      }

      // A clip that never reports its end must not stall How to Play.
      // Long enough for the ~7.5s Tagalog instructions — at 6s it cut
      // them off mid-sentence.
      final guard = Timer(const Duration(seconds: 15), end);
      final sub = _voice.onPlayerComplete.listen((_) => end());
      unawaited(() async {
        try {
          await _voice.stop();
          if (gen != _gen) return end();
          await _voice.play(
            AssetSource('audio/taharah_wudhu/${localizedVoice(clips[i])}'),
          );
        } catch (_) {
          // A missing recording just moves on to the next one.
          end();
        }
      }());
      await done.future;
      guard.cancel();
      unawaited(sub.cancel());
    }
    return !_disposed && gen == _gen;
  }

  Future<void> stopVoice() async {
    _cut();
    try {
      await _voice.stop();
    } catch (_) {
      // The player may already be disposed as the activity closes.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      await start();
    } else {
      _cut();
      try {
        await _music.stop();
        await _voice.stop();
      } catch (_) {
        // The player may already be stopping while the activity closes.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cut();
    await _music.dispose();
    await _voice.dispose();
  }
}
