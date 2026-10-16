import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

/// Greeting Match voice lines: the narrated scenario, the tapped response,
/// the How to Play steps and the "Mumtaz!" / "try again" feedback.
/// English recordings live under `assets/audio/greetings/`, Tagalog ones
/// under `assets/audio/greetings/fil/`; a missing file is skipped silently.
class GreetingMatchAudio {
  static const _dir = 'audio/greetings/';
  static const title = '${_dir}greetings_match.mp3';
  static const howTo = [
    '${_dir}instruction_watch_listen.mp3',
    '${_dir}instruction_look_and_listen.mp3',
    '${_dir}instruction_tap_reply.mp3',
    '${_dir}instruction_tap_correct_reply.mp3',
    '${_dir}instruction_earn_stars.mp3',
    '${_dir}instruction_greeting_star_award.mp3',
  ];
  static const letsPlay = '${_dir}lets_play.mp3';
  static const listenCarefully = '${_dir}listen_carefully.mp3';
  static const mumtaz = '${_dir}mumtaz.mp3';
  static const tryAgain = '${_dir}try_again_next_time.mp3';

  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  int _generation = 0;
  bool _disposed = false;
  bool _muted = false;

  bool get muted => _muted;

  Future<void> startMusic() async {
    if (_muted || _disposed) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicVolume);
      if (_muted || _disposed) return;
      await _music.play(
        AssetSource('audio/greetings/audio_bgm_greetings_ambient.mp3'),
      );
    } catch (_) {
      // Missing audio output must not block the game.
    }
  }

  /// The Music button: background music only — narration keeps playing.
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (_disposed) return;
    if (!muted) return startMusic();
    try {
      await _music.stop();
    } catch (_) {
      // Nothing playing / player already released.
    }
  }

  static const _musicVolume = 0.06;

  /// Music level under a voice line. Many voice clips are recorded ~14 dB
  /// quieter than the music file, so it ducks to keep narration on top.
  static const _duckedVolume = 0.015;

  Future<void> _setMusicVolume(double v) async {
    try {
      await _music.setVolume(v);
    } catch (_) {
      // Player already released as the game closes.
    }
  }

  /// Plays [assets] back to back in the learner's language. A newer call
  /// cuts off an older sequence. Music ducks under the voice meanwhile.
  Future<void> play(List<String?> assets) async {
    final generation = ++_generation;
    // Not awaited: the volume change must never hold up the voice line.
    if (!_disposed) unawaited(_setMusicVolume(_duckedVolume));
    try {
      await _playAll(assets, generation);
    } finally {
      // A newer sequence keeps the music ducked for itself.
      if (!_disposed && generation == _generation) {
        unawaited(_setMusicVolume(_musicVolume));
      }
    }
  }

  Future<void> _playAll(List<String?> assets, int generation) async {
    for (final asset in assets) {
      if (asset == null) continue;
      if (_disposed || generation != _generation) return;
      try {
        await _voice.stop();
        final local = asset.startsWith(_dir)
            ? '$_dir${localizedVoice(asset.substring(_dir.length))}'
            : asset;
        try {
          await _voice.play(AssetSource(local));
        } catch (_) {
          // No Tagalog take (e.g. the "Greeting Match" title): the English
          // one, rather than silence.
          if (local == asset) rethrow;
          await _voice.play(AssetSource(asset));
        }
        // Scenario narrations run up to ~14 s.
        await _voice.onPlayerComplete.first.timeout(
          const Duration(seconds: 20),
        );
      } catch (_) {
        // Missing recording or audio output must not block the game.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _voice.dispose();
    await _music.dispose();
  }
}
