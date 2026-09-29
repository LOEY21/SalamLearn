import 'package:audioplayers/audioplayers.dart';

abstract interface class GameUiAudioPlayback {
  void tap();
  void levelComplete();
  void starAward();
}

/// Shared effects used by every game hosted in the lesson player.
class GameUiAudio implements GameUiAudioPlayback {
  GameUiAudio._();

  static final GameUiAudio instance = GameUiAudio._();

  final AudioPlayer _tap = AudioPlayer();
  final AudioPlayer _level = AudioPlayer();
  final AudioPlayer _star = AudioPlayer();
  int _tapIndex = 0;
  int _starIndex = 0;
  int _tapGeneration = 0;

  static const _root = 'audio/game_ui/';

  /// Effects mix in rather than taking Android audio focus: with the default
  /// focus, every tap sound paused a game's narration for good, so its
  /// completion never fired and the game waited forever.
  late final Future<void> _ready = () async {
    try {
      await Future.wait([
        for (final p in [_tap, _level, _star])
          p.setAudioContext(
            AudioContextConfig(
              focus: AudioContextConfigFocus.mixWithOthers,
            ).build(),
          ),
      ]);
    } catch (_) {
      // Unsupported here: play with the default context.
    }
  }();

  Future<void> _play(AudioPlayer player, String name) async {
    try {
      await _ready;
      await player.stop();
      await player.play(AssetSource('$_root$name'));
    } catch (_) {
      // Audio output must not block a game interaction.
    }
  }

  @override
  void tap() {
    final generation = ++_tapGeneration;
    final name = _tapIndex++ % 2 == 0
        ? 'audio_sfx_button_tap.mp3'
        : 'audio_sfx_button_tap(1).mp3';
    () async {
      try {
        await _ready;
        await _tap.stop();
        if (generation == _tapGeneration) {
          await _tap.play(AssetSource('$_root$name'));
        }
      } catch (_) {
        // Ignore an unavailable audio device.
      }
    }();
  }

  @override
  void levelComplete() => _play(_level, 'audio_sfx_level_complete.mp3');

  @override
  void starAward() {
    final name = _starIndex++ % 2 == 0
        ? 'audio_sfx_star_award.mp3'
        : 'audio_sfx_star_award(1).mp3';
    _play(_star, name);
  }
}
