import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Separate players keep the sand ambience underneath each spoken letter.
class TraceAudio {
  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  int _voiceGeneration = 0;
  bool _musicEnabled = true;

  Future<void> startMusic() async {
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicEnabled ? 0.18 : 0);
      await _music.play(AssetSource('audio/sand_tracer/ambient.mp3'));
      await _music.setVolume(_musicEnabled ? 0.18 : 0);
    } catch (_) {
      // Tracing remains available when the device has no audio output.
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    try {
      await _music.setVolume(enabled ? 0.18 : 0);
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
