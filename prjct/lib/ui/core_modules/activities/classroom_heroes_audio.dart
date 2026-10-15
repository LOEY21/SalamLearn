import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

typedef ClassroomQuestionAudio = ({
  String prompt,
  String correct,
  String decoy,
});

/// The recordings in each session's question order, indexed by session
/// number: the four manners sessions, then the colors and shapes ones.
const classroomAudio = <List<ClassroomQuestionAudio>>[
  [
    (
      prompt: 'respect/amina_enters.mp3',
      correct: 'respect/greet_politely.mp3',
      decoy: 'respect/ignore_teacher.mp3',
    ),
    (
      prompt: 'respect/teacher_explaining.mp3',
      correct: 'respect/listen_carefully.mp3',
      decoy: 'respect/talk_loudly.mp3',
    ),
    (
      prompt: 'respect/ahmad_needs_leave.mp3',
      correct: 'respect/ask_permission.mp3',
      decoy: 'respect/leave_without_telling.mp3',
    ),
  ],
  [
    (
      prompt: 'kindness/dropped_books.mp3',
      correct: 'kindness/help_pick_up.mp3',
      decoy: 'kindness/laugh.mp3',
    ),
    (
      prompt: 'kindness/forgot_pencil.mp3',
      correct: 'kindness/share_pencil.mp3',
      decoy: 'kindness/hide_pencils.mp3',
    ),
    (
      prompt: 'kindness/sad_friend.mp3',
      correct: 'kindness/comfort_friend.mp3',
      decoy: 'kindness/make_fun.mp3',
    ),
  ],
  [
    (
      prompt: 'responsibility/paper_on_floor.mp3',
      correct: 'responsibility/throw_in_bin.mp3',
      decoy: 'responsibility/leave_it.mp3',
    ),
    (
      prompt: 'responsibility/finished_book.mp3',
      correct: 'responsibility/return_neatly.mp3',
      decoy: 'responsibility/throw_on_floor.mp3',
    ),
    (
      prompt: 'responsibility/teacher_homework.mp3',
      correct: 'responsibility/submit_on_time.mp3',
      decoy: 'responsibility/ignore_homework.mp3',
    ),
  ],
  [
    (
      prompt: 'teamwork/group_activity.mp3',
      correct: 'teamwork/share_ideas.mp3',
      decoy: 'teamwork/argue.mp3',
    ),
    (
      prompt: 'teamwork/many_wants_to_answer.mp3',
      correct: 'teamwork/wait_patiently.mp3',
      decoy: 'teamwork/shout_answer.mp3',
    ),
    (
      prompt: 'teamwork/new_student.mp3',
      correct: 'teamwork/welcome_them.mp3',
      decoy: 'teamwork/make_feel_left_out.mp3',
    ),
  ],
  [
    (
      prompt: 'vocab/story_red.mp3',
      correct: 'vocab/ahmar.mp3',
      decoy: 'vocab/azraq.mp3',
    ),
    (
      prompt: 'vocab/story_blue.mp3',
      correct: 'vocab/azraq.mp3',
      decoy: 'vocab/asfar.mp3',
    ),
    (
      prompt: 'vocab/story_yellow.mp3',
      correct: 'vocab/asfar.mp3',
      decoy: 'vocab/akhdar.mp3',
    ),
    (
      prompt: 'vocab/story_green.mp3',
      correct: 'vocab/akhdar.mp3',
      decoy: 'vocab/ahmar.mp3',
    ),
    (
      prompt: 'vocab/story_orange.mp3',
      correct: 'vocab/burtuqali.mp3',
      decoy: 'vocab/bunni.mp3',
    ),
  ],
  [
    (
      prompt: 'vocab/story_purple.mp3',
      correct: 'vocab/banafsaji.mp3',
      decoy: 'vocab/aswad.mp3',
    ),
    (
      prompt: 'vocab/story_black.mp3',
      correct: 'vocab/aswad.mp3',
      decoy: 'vocab/abyad.mp3',
    ),
    (
      prompt: 'vocab/story_white.mp3',
      correct: 'vocab/abyad.mp3',
      decoy: 'vocab/aswad.mp3',
    ),
    (
      prompt: 'vocab/story_brown.mp3',
      correct: 'vocab/bunni.mp3',
      decoy: 'vocab/banafsaji.mp3',
    ),
  ],
  [
    (
      prompt: 'vocab/story_circle.mp3',
      correct: 'vocab/dairah.mp3',
      decoy: 'vocab/murabba.mp3',
    ),
    (
      prompt: 'vocab/story_square.mp3',
      correct: 'vocab/murabba.mp3',
      decoy: 'vocab/muthallath.mp3',
    ),
    (
      prompt: 'vocab/story_triangle.mp3',
      correct: 'vocab/muthallath.mp3',
      decoy: 'vocab/dairah.mp3',
    ),
    (
      prompt: 'vocab/story_rectangle.mp3',
      correct: 'vocab/mustatil.mp3',
      decoy: 'vocab/najmah.mp3',
    ),
    (
      prompt: 'vocab/story_star.mp3',
      correct: 'vocab/najmah.mp3',
      decoy: 'vocab/hilal.mp3',
    ),
  ],
  [
    (
      prompt: 'vocab/story_heart.mp3',
      correct: 'vocab/qalb.mp3',
      decoy: 'vocab/muayyan.mp3',
    ),
    (
      prompt: 'vocab/story_diamond.mp3',
      correct: 'vocab/muayyan.mp3',
      decoy: 'vocab/baydawi.mp3',
    ),
    (
      prompt: 'vocab/story_crescent.mp3',
      correct: 'vocab/hilal.mp3',
      decoy: 'vocab/qalb.mp3',
    ),
    (
      prompt: 'vocab/story_oval.mp3',
      correct: 'vocab/baydawi.mp3',
      decoy: 'vocab/mustatil.mp3',
    ),
  ],
];

abstract interface class ClassroomAudioPlayback {
  Future<void> startMusic();
  Future<void> play(
    String asset, {
    void Function()? onComplete,
    void Function()? onError,
    void Function(Duration)? onDuration,
    bool localized = true,
  });
  Future<void> stopVoice();
  Future<void> dispose();
}

class ClassroomHeroesAudio implements ClassroomAudioPlayback {
  /// The title has no Tagalog take, so it plays with `localized: false`.
  static const title = 'classroom_heroes.mp3';
  static const mumtaz = 'mumtaz.mp3';

  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  StreamSubscription<void>? _complete;
  StreamSubscription<Duration>? _duration;
  int _generation = 0;

  @override
  Future<void> startMusic() async {
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.06);
      await _music.play(AssetSource('audio/classroom_heroes/ambient.mp3'));
    } catch (_) {
      // Audio device failures must not block the game.
    }
  }

  @override
  Future<void> play(
    String asset, {
    void Function()? onComplete,
    void Function()? onError,
    void Function(Duration)? onDuration,
    bool localized = true,
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
      await _voice.play(
        AssetSource(
          'audio/classroom_heroes/${localized ? localizedVoice(asset) : asset}',
        ),
      );
    } catch (_) {
      if (generation == _generation) onError?.call();
    }
  }

  @override
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
      // The player may already be disposed as the game leaves.
    }
  }

  @override
  Future<void> dispose() async {
    ++_generation;
    await _complete?.cancel();
    await _duration?.cancel();
    await _voice.dispose();
    await _music.dispose();
  }
}
