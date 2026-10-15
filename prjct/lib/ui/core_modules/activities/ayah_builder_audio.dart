import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// Each session's recordings, keyed by [AyahBuilderSession.sessionName]:
/// its folder under `assets/audio/ayah_builder/`, one clip per word card in
/// order, and the full recited ayah.
const _ayahAudio = <String, (String, List<String>, String)>{
  'The Basmalah': (
    'basmalah',
    ['bismi', 'allahi', 'ar_rahman', 'ar_rahim'],
    'basmalah_full',
  ),
  'Al-Fatihah Pt 1': (
    'fatihah1',
    ['al_hamdu', 'lillahi', 'rabbi', 'al_alamin'],
    'fatihah_ayah2_full',
  ),
  'Al-Fatihah Pt 2': (
    'fatihah2',
    ['ar_rahman', 'ar_rahim', 'maliki', 'yawmi', 'ad_din'],
    'fatihah_ayah3_4_full',
  ),
  'Al-Ikhlas': (
    'ikhlas',
    ['qul', 'huwa', 'allahu', 'ahad'],
    'ikhlas_ayah1_full',
  ),
  'Al-Falaq': (
    'falaq',
    ['qul', 'audhu', 'birabbi', 'al_falaq'],
    'falaq_ayah1_full',
  ),
  'An-Nas': ('nas', ['qul', 'audhu', 'birabbi', 'an_nas'], 'nas_ayah1_full'),
  'Al-Kawthar': (
    'kawthar',
    ['inna', 'ataynaka', 'al_kawthar'],
    'kawthar_ayah1',
  ),
};

/// Night-sky music, word clips and the full ayah recitation for one
/// Ayah Builder session.
class AyahBuilderAudio {
  AyahBuilderAudio(AyahBuilderSession session)
    : _clips = _ayahAudio[session.sessionName];

  final (String, List<String>, String)? _clips;
  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  bool _on = true;
  bool _disposed = false;
  int _generation = 0;
  Completer<void>? _line;
  Timer? _lineTimer;

  /// Ends the narrator line in flight, so a stop or dispose leaves no timer.
  void _endLine() {
    _lineTimer?.cancel();
    final line = _line;
    if (line != null && !line.isCompleted) line.complete();
  }

  /// Narrator lines in `audio/ayah_builder/`, Tagalog ones in its `fil/`
  /// folder. The title has no Tagalog take, so it always plays as is.
  static const title = 'ayah_builder.mp3';
  static const howTo = [
    'instruction_listen_first.mp3',
    'instruction_tap_word_card.mp3',
    'instruction_drag_correct_order.mp3',
  ];
  static const mashaAllah = 'masha_allah.mp3';

  /// This session's surah introduction, if it has one.
  String? get intro {
    final clips = _clips;
    return clips == null ? null : 'surah_intro_${clips.$1}.mp3';
  }

  /// Plays [lines] back to back; any other word, ayah or stop cuts the
  /// sequence. Resolves true only if it ran (or was muted) to the end.
  Future<bool> say(List<String?> lines) async {
    final generation = ++_generation;
    _endLine();
    for (final line in lines) {
      if (line == null) continue;
      if (_disposed || generation != _generation) return false;
      if (!_on) continue;
      final done = _line = Completer<void>();
      // A player that never gets ready must not stall the how-to screen.
      _lineTimer = Timer(const Duration(seconds: 15), _endLine);
      final sub = _voice.onPlayerComplete.listen((_) => _endLine());
      unawaited(() async {
        try {
          await _voice.stop();
          if (generation != _generation) return _endLine();
          await _voice.play(
            AssetSource(
              'audio/ayah_builder/'
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

  String _asset(String name) => 'audio/ayah_builder/${_clips!.$1}/$name.mp3';

  Future<void> startMusic() async {
    if (!_on || _disposed) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.06);
      if (!_on || _disposed) return;
      await _music.play(AssetSource('audio/ayah_builder/ambient.mp3'));
    } catch (_) {
      // Audio device failures must not block the game.
    }
  }

  /// The sound toggle: off silences music and any word or ayah playing.
  Future<void> setOn(bool on) async {
    _on = on;
    if (_disposed) return;
    if (on) return startMusic();
    try {
      await _music.stop();
      await _voice.stop();
    } catch (_) {
      // Nothing playing / player already released.
    }
  }

  Future<void> playWord(int index) async {
    final clips = _clips;
    if (!_on || _disposed || clips == null || index >= clips.$2.length) return;
    _generation++;
    _endLine();
    try {
      await _voice.stop();
      await _voice.play(AssetSource(_asset(clips.$2[index])));
    } catch (_) {
      // A missing clip just stays silent.
    }
  }

  /// Starts the full recitation and returns how long it runs, or null when
  /// it can't play (sound off, no recording) so the caller keeps its own
  /// timing.
  Future<Duration?> playAyah() async {
    final clips = _clips;
    if (!_on || _disposed || clips == null) return null;
    _generation++;
    _endLine();
    try {
      // A player that never gets ready must not stall the listen screen.
      return await () async {
        await _voice.stop();
        await _voice.setSource(AssetSource(_asset(clips.$3)));
        final length = await _voice.getDuration();
        await _voice.resume();
        return length;
      }().timeout(const Duration(seconds: 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> stopVoice() async {
    if (_disposed) return;
    _generation++;
    _endLine();
    try {
      await _voice.stop();
    } catch (_) {
      // The player may already be released as the game leaves.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _endLine();
    await _voice.dispose();
    await _music.dispose();
  }
}
