import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

/// Separate players keep the sand ambience underneath each spoken letter.
class TraceAudio {
  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  int _voiceGeneration = 0;
  bool _musicEnabled = true;

  Future<void> startMusic() async {
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicEnabled ? 0.06 : 0);
      await _music.play(AssetSource('audio/sand_tracer/ambient.mp3'));
      await _music.setVolume(_musicEnabled ? 0.06 : 0);
    } catch (_) {
      // Tracing remains available when the device has no audio output.
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    try {
      await _music.setVolume(enabled ? 0.06 : 0);
    } catch (_) {
      // The button state still reflects the learner's preference.
    }
  }

  Future<void> playLetter(String asset) async {
    final generation = ++_voiceGeneration;
    try {
      await _voice.stop();
      if (generation != _voiceGeneration) return;
      await _voice.play(AssetSource(asset.replaceFirst('assets/', '')));
    } catch (_) {
      // A missing audio device must not interrupt tracing.
    }
  }

  /// Narrator lines under `audio/sand_tracer/voice/`, Tagalog ones in its
  /// `fil/` folder. The title has no Tagalog take, so it always plays as is.
  static const title = 'magic_sand_tracer.mp3';
  static const howTo = [
    'tutorial_listen_sound.mp3',
    'tutorial_tap_speaker.mp3',
    'tutorial_follow_letter.mp3',
    'tutorial_fill_check.mp3',
    'tutorial_get_ready.mp3',
  ];
  static const letsGo = 'lets_go.mp3';
  static const praise = 'praise_great_tracing.mp3';
  static const complete = 'completion_all_letters.mp3';

  /// Plays [lines] back to back; a newer line or letter cuts the sequence.
  /// Resolves true only if the whole sequence ran without being cut.
  Future<bool> say(List<String> lines) async {
    final generation = ++_voiceGeneration;
    for (final line in lines) {
      if (generation != _voiceGeneration) return false;
      try {
        await _voice.stop();
        if (generation != _voiceGeneration) return false;
        await _voice.play(
          AssetSource(
            'audio/sand_tracer/voice/'
            '${line == title ? line : localizedVoice(line)}',
          ),
        );
        await _voice.onPlayerComplete.first.timeout(
          const Duration(seconds: 15),
        );
      } catch (_) {
        // A missing recording or audio device must not interrupt tracing.
      }
    }
    return generation == _voiceGeneration;
  }

  Future<void> stopLetter() async {
    ++_voiceGeneration;
    try {
      await _voice.stop();
    } catch (_) {
      // The player may already be closing with the lesson.
    }
  }

  Future<void> dispose() async {
    ++_voiceGeneration;
    await _voice.dispose();
    await _music.dispose();
  }
}
