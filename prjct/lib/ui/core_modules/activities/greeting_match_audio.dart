import 'package:audioplayers/audioplayers.dart';

/// Greeting Match voice lines: the prompt greeting, the tapped response,
/// and the "Mumtaz!" / "try again" feedback. Recordings live under
/// `assets/audio/greetings/`; a missing file is skipped silently.
class GreetingMatchAudio {
  static const mumtaz = 'audio/greetings/mumtaz.mp3';
  static const tryAgain = 'audio/greetings/try_again.mp3';

  final AudioPlayer _voice = AudioPlayer();
  int _generation = 0;
  bool _disposed = false;
  bool _muted = false;

  bool get muted => _muted;

  /// Sound on/off (the Music button). Muting cuts off whatever is playing.
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (!muted || _disposed) return;
    _generation++;
    try {
      await _voice.stop();
    } catch (_) {
      // Nothing playing / player already released.
    }
  }

  /// Plays [assets] back to back. A newer call cuts off an older sequence.
  Future<void> play(List<String?> assets) async {
    if (_muted) return;
    final generation = ++_generation;
    for (final asset in assets) {
      if (asset == null) continue;
      if (_disposed || generation != _generation) return;
      try {
        await _voice.stop();
        await _voice.play(AssetSource(asset));
        await _voice.onPlayerComplete.first.timeout(const Duration(seconds: 4));
      } catch (_) {
        // Missing recording or audio output must not block the game.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _voice.dispose();
  }
}
