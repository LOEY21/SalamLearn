import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

/// Looped room music and spoken vocab words for the Label Maker sessions.
class LabelMakerAudio {
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();
  bool _enabled = true;
  bool _disposed = false;
  int _generation = 0;
  Completer<void>? _line;
  Timer? _lineTimer;

  /// Narrator lines in `audio/label_maker/`, Tagalog ones in its `fil/`
  /// folder. The title has no Tagalog take, so it always plays as is.
  /// Per-word `feedback_<word>.mp3` lines sit alongside them.
  static const title = 'arabic_label_maker.mp3';
  static const howTo = [
    'tutorial_tap_speaker_word.mp3',
    'tutorial_drag_speaker_object.mp3',
    'tutorial_becomes_label.mp3',
  ];
  static const letsGo = 'lets_go.mp3';

  /// Ends the narrator line in flight, so a stop or dispose leaves no timer.
  void _endLine() {
    _lineTimer?.cancel();
    final line = _line;
    if (line != null && !line.isCompleted) line.complete();
  }

  /// Plays [lines] back to back; a word, mute or newer sequence cuts it.
  /// Resolves true only if it ran (or was muted) to the end.
  Future<bool> say(List<String> lines) async {
    final generation = ++_generation;
    _endLine();
    for (final line in lines) {
      if (_disposed || generation != _generation) return false;
      if (!_enabled) continue;
      final done = _line = Completer<void>();
      // A player that never gets ready must not stall How to Play.
      _lineTimer = Timer(const Duration(seconds: 15), _endLine);
      final sub = _voice.onPlayerComplete.listen((_) => _endLine());
      unawaited(() async {
        try {
          await _voice.stop();
          if (generation != _generation) return _endLine();
          await _voice.play(
            AssetSource(
              'audio/label_maker/'
              '${line == title ? line : localizedVoice(line)}',
            ),
          );
        } catch (_) {
          // A missing recording or audio device must not block the game.
          if (done == _line) _endLine();
        }
      }());
      await done.future;
      unawaited(sub.cancel());
    }
    return !_disposed && generation == _generation;
  }

  /// Says one vocab word; a newer word cuts off the one still playing.
  Future<void> playWord(String asset) async {
    if (_disposed || !_enabled) return;
    _generation++;
    _endLine();
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
      await _music.setVolume(0.06);
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
      _generation++;
      _endLine();
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
    _endLine();
    await _music.dispose();
    await _voice.dispose();
  }
}
