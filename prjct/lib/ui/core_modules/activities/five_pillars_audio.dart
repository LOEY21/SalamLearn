import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

const _dir = 'audio/five_pillars/';

/// Narration for The Five Pillars (title, how-to steps, questions and
/// pillar names) over a looped background track.
class FivePillarsAudio {
  FivePillarsAudio() {
    // The track is ~10-18 dB hotter than the narration, so it plays low and
    // ducks further under every voice line.
    _ducking = _voice.onPlayerStateChanged.listen((state) {
      _setMusicVolume(
        state == PlayerState.playing ? _duckedVolume : _musicVolume,
      );
    });
  }

  static const _musicVolume = 0.035;
  static const _duckedVolume = 0.012;

  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  late final StreamSubscription<PlayerState> _ducking;
  bool _disposed = false;
  int _generation = 0;
  Completer<void> _cut = Completer();

  /// Says [clips] back to back; a newer call cuts off whatever is playing.
  /// Completes when the last clip ends or the narration is cut off.
  Future<void> say(List<String> clips) async {
    if (_disposed) return;
    _interrupt();
    final generation = _generation;
    final cut = _cut.future;
    for (final clip in clips) {
      if (_disposed || generation != _generation) return;
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

  /// The title and pillar names have no Tagalog take, so those fall back
  /// to the English clip.
  Future<void> _play(String clip) async {
    final local = localizedVoice(clip);
    try {
      await _voice.play(AssetSource('$_dir$local'));
    } catch (_) {
      if (local == clip) rethrow;
      await _voice.play(AssetSource('$_dir$clip'));
    }
  }

  void _setMusicVolume(double v) {
    if (_disposed) return;
    unawaited(_music.setVolume(v).catchError((Object _) {}));
  }

  Future<void> startMusic() async {
    if (_disposed) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicVolume);
      await _music.play(AssetSource('${_dir}bgm_kids_joys.mp3'));
    } catch (_) {
      // No audio output: the game still runs, silently.
    }
  }

  void _interrupt() {
    ++_generation;
    _cut.complete();
    _cut = Completer();
  }

  Future<void> stop() async {
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
    await _ducking.cancel();
    await _voice.dispose();
    await _music.dispose();
  }
}
