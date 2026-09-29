import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

typedef EtiquetteQuestionAudio = ({
  String prompt,
  String correct,
  String decoy,
});

/// One prompt and two spoken choices for every question, in session order.
const etiquetteAudio = <List<EtiquetteQuestionAudio>>[
  [
    (
      prompt: 'masjid/imam_reciting.mp3',
      correct: 'masjid/sit_quietly.mp3',
      decoy: 'masjid/run_around.mp3',
    ),
    (
      prompt: 'masjid/friend_chatting.mp3',
      correct: 'masjid/continue_listening.mp3',
      decoy: 'masjid/talk_loudly.mp3',
    ),
    (
      prompt: 'masjid/before_reading.mp3',
      correct: 'masjid/make_wudhu.mp3',
      decoy: 'masjid/eat_candy.mp3',
    ),
    (
      prompt: 'masjid/finished_reading.mp3',
      correct: 'masjid/clean_shelf.mp3',
      decoy: 'masjid/leave_under_toys.mp3',
    ),
    (
      prompt: 'masjid/finished_recitation.mp3',
      correct: 'masjid/sadaqallah.mp3',
      decoy: 'masjid/start_shouting.mp3',
    ),
  ],
  [
    (
      prompt: 'home/playing_blocks.mp3',
      correct: 'home/stop_and_listen.mp3',
      decoy: 'home/keep_playing.mp3',
    ),
    (
      prompt: 'home/quran_on_phone.mp3',
      correct: 'home/put_phone_down.mp3',
      decoy: 'home/watch_cartoons.mp3',
    ),
    (
      prompt: 'home/noisy_brother.mp3',
      correct: 'home/ask_kindly.mp3',
      decoy: 'home/yell_at_him.mp3',
    ),
    (
      prompt: 'home/loud_play.mp3',
      correct: 'home/no.mp3',
      decoy: 'home/yes.mp3',
    ),
    (
      prompt: 'home/quran_reciting_general.mp3',
      correct: 'home/sit_quietly.mp3',
      decoy: 'home/cover_ears.mp3',
    ),
  ],
];

class QuranEtiquetteAudio {
  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  StreamSubscription<void>? _complete;
  StreamSubscription<Duration>? _duration;
  int _generation = 0;

  Future<void> startMusic() async {
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.18);
      await _music.play(AssetSource('audio/quran_etiquette/ambient.mp3'));
    } catch (_) {
      // Audio device failures must not block the lesson.
    }
  }

  Future<void> play(
    String asset, {
    void Function()? onComplete,
    void Function()? onError,
    void Function(Duration)? onDuration,
  }) async {
    final generation = ++_generation;
    await _complete?.cancel();
    await _duration?.cancel();
    if (generation != _generation) return;
    _complete = null;
    _duration = null;
    try {
      await _voice.stop();
      if (generation != _generation) return;
      _complete = _voice.onPlayerComplete.listen((_) {
        if (generation == _generation) onComplete?.call();
      });
      _duration = _voice.onDurationChanged.listen((duration) {
        if (generation == _generation) onDuration?.call(duration);
      });
      await _voice.play(AssetSource('audio/quran_etiquette/$asset'));
    } catch (_) {
      if (generation == _generation) onError?.call();
    }
  }

  Future<void> stopVoice() async {
    final generation = ++_generation;
    await _complete?.cancel();
    await _duration?.cancel();
    if (generation != _generation) return;
    _complete = null;
    _duration = null;
    try {
      await _voice.stop();
    } catch (_) {
      // The player may already be disposed when the lesson is leaving.
    }
  }

  Future<void> dispose() async {
    ++_generation;
    await _complete?.cancel();
    await _duration?.cancel();
    await _voice.dispose();
    await _music.dispose();
  }
}
