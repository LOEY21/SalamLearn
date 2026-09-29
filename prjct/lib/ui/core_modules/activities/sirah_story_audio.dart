import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// The supplied recordings, in the order of each session's two pages.
typedef SirahPageAudio = ({
  String narration,
  String question,
  String correct,
  String decoy,
});

const sirahPageAudio = <List<SirahPageAudio>>[
  [
    (
      narration: 'birth/born_in_makkah.mp3',
      question: 'birth/q_where_born.mp3',
      correct: 'birth/makkah.mp3',
      decoy: 'birth/forest.mp3',
    ),
    (
      narration: 'birth/parents_names.mp3',
      question: 'birth/q_mother_name.mp3',
      correct: 'birth/aminah.mp3',
      decoy: 'birth/fatimah.mp3',
    ),
  ],
  [
    (
      narration: 'halimah/sent_to_desert.mp3',
      question: 'halimah/q_where_grow.mp3',
      correct: 'halimah/desert.mp3',
      decoy: 'halimah/castle.mp3',
    ),
    (
      narration: 'halimah/nurse_halimah.mp3',
      question: 'halimah/q_nurse_name.mp3',
      correct: 'halimah/halimah.mp3',
      decoy: 'halimah/khadijah.mp3',
    ),
  ],
  [
    (
      narration: 'family/grandfather_care.mp3',
      question: 'family/q_who_cared_first.mp3',
      correct: 'family/grandfather.mp3',
      decoy: 'family/king.mp3',
    ),
    (
      narration: 'family/uncle_care.mp3',
      question: 'family/q_uncle_name.mp3',
      correct: 'family/uncle.mp3',
      decoy: 'family/neighbor.mp3',
    ),
  ],
  [
    (
      narration: 'al_amin/shepherd_job.mp3',
      question: 'al_amin/q_what_job.mp3',
      correct: 'al_amin/shepherd.mp3',
      decoy: 'al_amin/soldier.mp3',
    ),
    (
      narration: 'al_amin/al_amin.mp3',
      question: 'al_amin/q_what_al_amin.mp3',
      correct: 'al_amin/trustworthy.mp3',
      decoy: 'al_amin/runner.mp3',
    ),
  ],
];

abstract interface class SirahAudioPlayback {
  Future<void> startMusic();
  Future<void> play(
    String asset, {
    void Function()? onComplete,
    void Function()? onError,
  });
  Future<void> stopVoice();
  Future<void> dispose();
}

class SirahStoryAudio implements SirahAudioPlayback {
  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  StreamSubscription<void>? _complete;
  int _generation = 0;

  @override
  Future<void> startMusic() async {
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.18);
      await _music.play(AssetSource('audio/sirah_story/ambient.mp3'));
    } catch (_) {
      // Sound must never prevent a child from playing the story.
    }
  }

  @override
  Future<void> play(
    String asset, {
    void Function()? onComplete,
    void Function()? onError,
  }) async {
    final generation = ++_generation;
    await _complete?.cancel();
    if (generation != _generation) return;
    _complete = null;
    try {
      await _voice.stop();
      if (generation != _generation) return;
      _complete = _voice.onPlayerComplete.listen((_) {
        if (generation == _generation) onComplete?.call();
      });
      await _voice.play(AssetSource('audio/sirah_story/$asset'));
    } catch (_) {
      if (generation == _generation) onError?.call();
    }
  }

  @override
  Future<void> stopVoice() async {
    final generation = ++_generation;
    await _complete?.cancel();
    if (generation != _generation) return;
    _complete = null;
    await _voice.stop();
  }

  @override
  Future<void> dispose() async {
    ++_generation;
    await _complete?.cancel();
    await _voice.dispose();
    await _music.dispose();
  }
}
