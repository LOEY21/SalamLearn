import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

const _kA = 'assets/images/sound_detective';

/// Pronunciations shared with Magic Sand Tracer, keyed by each question name.
const soundDetectiveLetterAudio = <String, String>{
  'Alif': 'assets/audio/sand_tracer/stage1/alif.mp3',
  'Ba': 'assets/audio/sand_tracer/stage1/ba.mp3',
  'Ta': 'assets/audio/sand_tracer/stage1/ta.mp3',
  'Tha': 'assets/audio/sand_tracer/stage1/tha.mp3',
  'Jeem': 'assets/audio/sand_tracer/stage1/jeem.mp3',
  'Ha': 'assets/audio/sand_tracer/stage1/ha.mp3',
  'Kha': 'assets/audio/sand_tracer/stage1/kha.mp3',
  'Dal': 'assets/audio/sand_tracer/stage2/dal.mp3',
  'Dhal': 'assets/audio/sand_tracer/stage2/dhal.mp3',
  'Ra': 'assets/audio/sand_tracer/stage2/ra.mp3',
  'Zay': 'assets/audio/sand_tracer/stage2/zay.mp3',
  'Seen': 'assets/audio/sand_tracer/stage2/seen.mp3',
  'Sheen': 'assets/audio/sand_tracer/stage2/sheen.mp3',
  'Sad': 'assets/audio/sand_tracer/stage2/sad.mp3',
  'Dad': 'assets/audio/sand_tracer/stage3/dad.mp3',
  'Taa': 'assets/audio/sand_tracer/stage3/ta_heavy.mp3',
  'Dhaa': 'assets/audio/sand_tracer/stage3/zha.mp3',
  'Ayn': 'assets/audio/sand_tracer/stage3/ayn.mp3',
  'Ghayn': 'assets/audio/sand_tracer/stage3/ghayn.mp3',
  'Fa': 'assets/audio/sand_tracer/stage3/fa.mp3',
  'Qaf': 'assets/audio/sand_tracer/stage3/qaf.mp3',
  'Kaf': 'assets/audio/sand_tracer/stage4/kaf.mp3',
  'Lam': 'assets/audio/sand_tracer/stage4/lam.mp3',
  'Meem': 'assets/audio/sand_tracer/stage4/meem.mp3',
  'Noon': 'assets/audio/sand_tracer/stage4/noon.mp3',
  'Haa': 'assets/audio/sand_tracer/stage4/ha_soft.mp3',
  'Waw': 'assets/audio/sand_tracer/stage4/waw.mp3',
  'Ya': 'assets/audio/sand_tracer/stage4/ya.mp3',
};

/// Phone-sized stage every screen is laid out in, scaled to fit.
const _kW = 402.0;
const _kH = 874.0;

/// Each animal owns a third of the row; its sprite spills 33% past each side.
const _kSlotW = (_kW - 4) / 3;
const _kSlotBox = _kSlotW * 1.66;

/// Width / height of each board image, so boards keep their shape.
const _kBoardAspect = {
  'board_title': 2.479,
  'board_panel': 1.613,
  'board_howto': 3.01,
  'board_bubble': 2.397,
  'board_star': 2.256,
  'board_q': 2.055,
  'board_ok': 3.265,
  'board_oops': 3.32,
};

const _kBrown = Color(0xFF8A5A2B);

/// Dark drop under white text on the glossy pill buttons.
const _kBtnShadow = [Shadow(color: Color(0x59000000), offset: Offset(0, 2))];
const _kInk = Color(0xFF5B3B1E);
const _kGreen = Color(0xFF3C6F1F);
const _kCardTop = Color(0xFFFBEECD);
const _kCardBottom = Color(0xFFF0DCAF);

class _Q {
  const _Q(this.name, this.letter, this.decoys);
  final String name;
  final String letter;
  final List<String> decoys;
}

class _Session {
  const _Session(this.number, this.range, this.countAr, this.questions);
  final int number;
  final String range;

  /// "All N sounds" in Arabic, for the done card.
  final String countAr;
  final List<_Q> questions;
}

/// Decoys are look-alike letters, so the child has to listen and watch
/// the dots rather than guess by shape.
const _kSessions = {
  SoundDetectiveSession.alifToKha: _Session(1, 'Alif to Kha', 'السبعة', [
    _Q('Alif', 'ا', ['ل', 'د']),
    _Q('Ba', 'ب', ['ت', 'ث']),
    _Q('Ta', 'ت', ['ب', 'ث']),
    _Q('Tha', 'ث', ['ت', 'ش']),
    _Q('Jeem', 'ج', ['ح', 'خ']),
    _Q('Ha', 'ح', ['ج', 'خ']),
    _Q('Kha', 'خ', ['ح', 'غ']),
  ]),
  SoundDetectiveSession.dalToDad: _Session(2, 'Dal to Dad', 'الثمانية', [
    _Q('Dal', 'د', ['ذ', 'ر']),
    _Q('Dhal', 'ذ', ['د', 'ز']),
    _Q('Ra', 'ر', ['ز', 'و']),
    _Q('Zay', 'ز', ['ر', 'ذ']),
    _Q('Seen', 'س', ['ش', 'ص']),
    _Q('Sheen', 'ش', ['س', 'ث']),
    _Q('Sad', 'ص', ['ض', 'س']),
    _Q('Dad', 'ض', ['ص', 'ظ']),
  ]),
  SoundDetectiveSession.taToQaf: _Session(3, 'Ta to Qaf', 'الستة', [
    _Q('Taa', 'ط', ['ظ', 'ت']),
    _Q('Dhaa', 'ظ', ['ط', 'ذ']),
    _Q('Ayn', 'ع', ['غ', 'ح']),
    _Q('Ghayn', 'غ', ['ع', 'خ']),
    _Q('Fa', 'ف', ['ق', 'ث']),
    _Q('Qaf', 'ق', ['ف', 'ك']),
  ]),
  SoundDetectiveSession.kafToYa: _Session(4, 'Kaf to Ya', 'السبعة', [
    _Q('Kaf', 'ك', ['ق', 'ل']),
    _Q('Lam', 'ل', ['ك', 'ا']),
    _Q('Meem', 'م', ['ن', 'ه']),
    _Q('Noon', 'ن', ['ب', 'ت']),
    _Q('Haa', 'ه', ['ح', 'م']),
    _Q('Waw', 'و', ['ر', 'ز']),
    _Q('Ya', 'ي', ['ب', 'ن']),
  ]),
};

/// Where each animal holds its sign, per pose: centre x/y and width as % of
/// the sprite box, plus tilt in degrees. [eyes] are the eye boxes and
/// [sign] the sign's open wooden panel (clear of paws) on the 640px idle
/// art.
class _Cast {
  const _Cast(this.key, this.idle, this.happy, this.sad, this.eyes, this.sign);
  final String key;
  final List<double> idle;
  final List<double> happy;
  final List<double> sad;
  final List<Rect> eyes;
  final Rect sign;
  List<double> at(_Pose p) => switch (p) {
    _Pose.idle => idle,
    _Pose.happy => happy,
    _Pose.sad => sad,
  };
}

const _kCast = [
  _Cast(
    'fox',
    [54.1, 66.6, 44, 0],
    [60.0, 65.0, 43, -2],
    [56.3, 68.7, 46, 0],
    [Rect.fromLTRB(253, 172, 309, 236), Rect.fromLTRB(378, 189, 436, 255)],
    Rect.fromLTRB(206, 378, 486, 485),
  ),
  _Cast(
    'bunny',
    [50.6, 70.2, 47, 0],
    [51.2, 68.2, 45, -2],
    [50.6, 69.3, 47, 0],
    [Rect.fromLTRB(247, 230, 297, 293), Rect.fromLTRB(355, 245, 403, 304)],
    Rect.fromLTRB(178, 406, 468, 509),
  ),
  _Cast(
    'bear',
    [51.6, 57.8, 49, 0],
    [50.2, 55.3, 46, -2],
    [52.5, 57.7, 48, 0],
    [Rect.fromLTRB(244, 145, 295, 207), Rect.fromLTRB(365, 131, 413, 194)],
    Rect.fromLTRB(176, 301, 483, 439),
  ),
];

/// Each letter's inked shape in ScheherazadeNew Bold, per 1em: centre x
/// from the pen origin, centre y from the baseline (down is +), width,
/// height. Measured from the font file, so a letter can be centred on what
/// is actually drawn — dots and hooks included — rather than its line box.
const Map<String, (double, double, double, double)> _kLetterInk = {
  'ا': (0.117, -0.343, 0.234, 0.693),
  'ب': (0.494, -0.102, 0.988, 0.719),
  'ت': (0.494, -0.239, 0.988, 0.530),
  'ث': (0.494, -0.320, 0.988, 0.692),
  'ج': (0.375, 0.083, 0.750, 0.841),
  'ح': (0.375, 0.083, 0.750, 0.841),
  'خ': (0.375, -0.030, 0.750, 1.067),
  'د': (0.217, -0.216, 0.435, 0.443),
  'ذ': (0.217, -0.333, 0.435, 0.676),
  'ر': (0.173, 0.013, 0.491, 0.583),
  'ز': (0.173, -0.107, 0.491, 0.823),
  'س': (0.502, -0.027, 1.005, 0.714),
  'ش': (0.502, -0.210, 1.005, 1.080),
  'ص': (0.579, -0.035, 1.157, 0.751),
  'ض': (0.579, -0.124, 1.157, 0.928),
  'ط': (0.403, -0.367, 0.806, 0.735),
  'ظ': (0.403, -0.367, 0.806, 0.735),
  'ع': (0.372, -0.003, 0.745, 0.999),
  'غ': (0.372, -0.111, 0.745, 1.215),
  'ف': (0.501, -0.427, 1.003, 0.862),
  'ق': (0.362, -0.303, 0.724, 0.868),
  'ك': (0.335, -0.379, 0.669, 0.772),
  'ل': (0.307, -0.304, 0.614, 0.937),
  'م': (0.216, 0.021, 0.433, 0.805),
  'ن': (0.313, -0.141, 0.626, 0.722),
  'ه': (0.190, -0.191, 0.379, 0.395),
  'و': (0.189, -0.016, 0.480, 0.682),
  'ي': (0.401, -0.037, 0.801, 0.865),
};

const _kPraise = [
  ('Mumtaz!', 'ممتاز!'),
  ('Great listening!', 'أحسنت!'),
  ('Well done!', 'رائع!'),
  ('Excellent!', 'ممتاز!'),
];

const _kSpeakerSvg =
    '<svg viewBox="0 0 46 42"><path d="M6 15h8L26 5v32L14 27H6z" fill="#fff"/><path d="M32 13c3.6 3 3.6 13 0 16M38 8c6 6 6 20 0 26" stroke="#fff" stroke-width="3.4" fill="none" stroke-linecap="round"/></svg>';
const _kOkMarkSvg =
    '<svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="17" fill="#3f9d2b" stroke="#2a6d1c" stroke-width="3"/><path d="M11 20.5l6 6 12-13" stroke="#fff" stroke-width="4.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>';
const _kBadMarkSvg =
    '<svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="17" fill="#d63a2f" stroke="#95221a" stroke-width="3"/><path d="M13 13l14 14M27 13L13 27" stroke="#fff" stroke-width="4.6" fill="none" stroke-linecap="round"/></svg>';
const _kOkBarSvg =
    '<svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="18" fill="#fff"/><path d="M11 20.5l6 6 12-13" stroke="#2f8a1f" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>';
const _kBadBarSvg =
    '<svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="18" fill="#fff"/><path d="M13 13l14 14M27 13L13 27" stroke="#c9291f" stroke-width="5" fill="none" stroke-linecap="round"/></svg>';

/// The glossy gold star.
Widget _starArt(double size) =>
    Image.asset('$_kA/star.png', width: size, height: size);

Widget _svg(String s, double w, [double? h]) =>
    SvgPicture.string(s, width: w, height: h ?? w);

FontWeight _fw(double w) => FontWeight.values[(w / 100).round() - 1];

TextStyle _baloo(
  double size,
  double weight,
  Color color, {
  double? height,
  double? ls,
  List<Shadow>? shadows,
}) => TextStyle(
  fontFamily: 'Baloo2Var',
  fontSize: size,
  fontWeight: _fw(weight),
  fontVariations: [ui.FontVariation.weight(weight)],
  color: color,
  height: height,
  letterSpacing: ls,
  shadows: shadows,
);

TextStyle _naskh(double size, Color color, {bool bold = false}) => TextStyle(
  fontFamily: 'ScheherazadeNew',
  fontSize: size,
  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
  color: color,
  height: 1.3,
);

Widget _ar(String s, TextStyle style) =>
    Text(s, textDirection: TextDirection.rtl, style: style);

// ---- CSS-style keyframe helpers ----

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Value at progress [p] through keyframes [(stop, value)], easing each
/// segment with [c] like a CSS animation-timing-function does.
double _kf(double p, List<(double, double)> k, [Curve c = Curves.ease]) {
  p = p.clamp(0.0, 1.0);
  for (var i = 1; i < k.length; i++) {
    if (p <= k[i].$1) {
      final (s0, v0) = k[i - 1];
      final (s1, v1) = k[i];
      final t = s1 == s0 ? 1.0 : (p - s0) / (s1 - s0);
      return _lerp(v0, v1, c.transform(t));
    }
  }
  return k.last.$2;
}

/// Progress of a looping animation of [period] seconds at time [t].
double _loop(double t, double period, [double delay = 0]) =>
    t < delay ? 0 : ((t - delay) % period) / period;

enum _Screen { title, howTo, play, done }

enum _Phase { wait, enter, idle, exit }

enum _Pose { idle, happy, sad }

/// Arabic Sound Detective — hear a letter's sound, tap the forest animal
/// holding that letter. Portrait, one forest scene, 6-8 letters a session.
class SoundDetectiveGame extends StatefulWidget {
  const SoundDetectiveGame({
    super.key,
    required this.session,
    required this.xp,
    required this.onComplete,
    this.onExit,
    this.random,
    this.musicEnabled = true,
  });

  final SoundDetectiveSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  final VoidCallback? onExit;

  /// Sign and animal order source; tests pass a seeded one.
  final math.Random? random;
  final bool musicEnabled;

  @override
  State<SoundDetectiveGame> createState() => _SoundDetectiveGameState();
}

class _SoundDetectiveGameState extends State<SoundDetectiveGame>
    with SingleTickerProviderStateMixin {
  /// One clock (seconds) drives every keyframe animation on screen.
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (e) => _time.value = e.inMicroseconds / 1e6,
  );

  late final math.Random _rng = widget.random ?? math.Random();
  _Session get _s => _kSessions[widget.session]!;
  int get _n => _s.questions.length;
  _Q get _q => _s.questions[_qi];

  _Screen _screen = _Screen.title;
  double _screenAt = 0;
  int _qi = 0;
  int _stars = 0;
  int _errors = 0;
  bool _completed = false;

  /// Questions the child tapped a wrong animal on at least once.
  final Set<int> _missed = {};

  List<String> _order = const ['', '', ''];
  List<int> _cast = const [0, 1, 2];
  _Phase _phase = _Phase.enter;
  double _phaseAt = 0;
  List<_Pose> _pose = List.filled(3, _Pose.idle);

  /// Last reaction per slot, kept while it fades back to idle.
  final List<_Pose> _react = List.filled(3, _Pose.happy);
  double _reactAt = 0;

  /// Feedback: null, true (correct) or false (wrong).
  bool? _fb;
  String _fbEn = '';
  String _fbAr = '';
  double _fbAt = 0;
  int? _flying;
  double _flyAt = 0;
  bool _wave = false;
  bool _locked = false;

  /// How to Play holds Let's Go back until the steps have had time to sink
  /// in.
  bool _goReady = false;
  double _goAt = 0;

  /// Pre-game countdown: 3, 2, 1, then 0 for "Go!"; null once the round is
  /// live. Taps and replays are locked while it runs.
  int? _count;
  double _countAt = 0;

  /// Music button: off silences the game's sounds.
  bool _sound = true;
  AudioPlayer? _music;
  AudioPlayer? _voice;
  int _voiceGeneration = 0;

  final List<Timer> _timers = [];

  /// Scene layers the painters animate: each forest's waterfall texture and
  /// shape, and its two leaf canopies.
  final Map<String, ui.Image> _art = {};

  @override
  void initState() {
    super.initState();
    if (widget.musicEnabled) {
      _music = AudioPlayer();
      _voice = AudioPlayer();
      unawaited(_startMusic());
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ticker.start();
    _loadArt();
  }

  Future<void> _loadArt() async {
    for (final name in [
      for (final c in _kCast) '${c.key}_lids.png',
      for (final scene in ['start', 'game']) ...[
        '${scene}_falls_tile.png',
        '${scene}_falls_mask.png',
        '${scene}_tree_l.png',
        '${scene}_tree_r.png',
      ],
    ]) {
      final data = await rootBundle.load('$_kA/$name');
      final img = await decodeImageFromList(data.buffer.asUint8List());
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() => _art[name] = img);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final n in [
      'bg_forest.jpg',
      'start_bg.jpg',
      'start_logo.png',
      'start_scroll.png',
      'start_boy.png',
      'start_girl.png',
      'play.png',
      'play_down.png',
      'star.png',
      'board_star.png',
      'board_q.png',
      'board_question.png',
      'board_howto.png',
      'board_step.png',
      'board_bubble.png',
      'board_ok.png',
      'board_title.png',
      'board_panel.png',
      for (final c in ['green', 'blue']) ...['btn_$c.png', 'btn_${c}_down.png'],
      for (final k in ['girl', 'boy'])
        for (final pose in ['cheer', 'thumbs']) 'end_${k}_$pose.png',
      'board_oops.png',
      for (final b in ['back', 'home', 'music']) ...[
        'btn_$b.png',
        'btn_${b}_down.png',
      ],
      for (final l in ['ta', 'ba', 'alif', 'kha', 'tha']) 'letter_$l.png',
    ]) {
      precacheImage(AssetImage('$_kA/$n'), context);
    }
    for (final c in _kCast) {
      for (final p in ['idle', 'happy', 'sad']) {
        precacheImage(AssetImage('$_kA/${c.key}_$p.png'), context);
      }
    }
  }

  @override
  void dispose() {
    ++_voiceGeneration;
    if (_voice != null) unawaited(_voice!.dispose());
    if (_music != null) unawaited(_music!.dispose());
    _clear();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    for (final img in _art.values) {
      img.dispose();
    }
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _clear() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _after(int ms, VoidCallback fn) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(fn);
    }),
  );

  double get _now => _time.value;

  // ---- game logic ----

  void _sfx() {
    if (_sound) SystemSound.play(SystemSoundType.click);
  }

  Future<void> _startMusic() async {
    try {
      final player = _music;
      if (player == null) return;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_sound ? 0.18 : 0);
      await player.play(
        AssetSource('audio/sound_detective/forest_ambient.mp3'),
      );
      await player.setVolume(_sound ? 0.18 : 0);
    } catch (_) {
      // The detective game remains playable without an audio device.
    }
  }

  void _toggleSound() {
    setState(() => _sound = !_sound);
    if (_music != null) {
      unawaited(_setMusicVolume());
    }
    if (!_sound) unawaited(_stopLetterAudio());
  }

  Future<void> _playLetterAudio(String asset) async {
    final generation = ++_voiceGeneration;
    try {
      final player = _voice;
      if (player == null) return;
      await player.stop();
      if (generation != _voiceGeneration || !_sound) return;
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
    } catch (_) {
      // The game remains playable if the audio device cannot play a clip.
    }
  }

  Future<void> _stopLetterAudio() async {
    ++_voiceGeneration;
    try {
      await _voice?.stop();
    } catch (_) {
      // The player may already be closing with the game.
    }
  }

  Future<void> _setMusicVolume() async {
    try {
      await _music?.setVolume(_sound ? 0.18 : 0);
    } catch (_) {
      // The mute control still silences the game's click cue.
    }
  }

  /// A leafy wooden game button; [name] picks its art pair.
  Widget _gameBtn(String name, VoidCallback onTap, {bool off = false}) =>
      SizedBox(
        width: 62,
        height: 38,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ImgPressButton(
              key: ValueKey('sd-$name'),
              up: '$_kA/btn_$name.png',
              down: '$_kA/btn_${name}_down.png',
              onTap: onTap,
            ),
            if (off)
              const IgnorePointer(
                child: CustomPaint(painter: _MutedSlashPainter()),
              ),
          ],
        ),
      );

  Widget _musicBtn() => _gameBtn('music', _toggleSound, off: !_sound);

  /// Back steps to the screen before this one; only Home leaves the game.
  Widget _backBtn(VoidCallback to) => _gameBtn('back', () {
    _clear();
    _count = null;
    unawaited(_stopLetterAudio());
    to();
  });

  List<String> _shuffled(int qi) {
    final q = _s.questions[qi];
    return [q.letter, ...q.decoys]..shuffle(_rng);
  }

  void _start() {
    _clear();
    setState(() {
      _screen = _Screen.play;
      _screenAt = _now;
      _qi = 0;
      _stars = 0;
      _errors = 0;
      _missed.clear();
      _fb = null;
      _flying = null;
      _locked = false;
      _pose = List.filled(3, _Pose.idle);
      _order = _shuffled(0);
      _cast = [0, 1, 2]..shuffle(_rng);
      _phase = _Phase.wait;
      _phaseAt = _now;
      _locked = true;
      _count = 3;
      _countAt = _now;
    });
    for (final (i, n) in [(1, 2), (2, 1), (3, 0)]) {
      _after(1000 * i, () {
        _count = n;
        _countAt = _now;
      });
    }
    // Four seconds on, the animals hop in with the first sound.
    _after(4000, () {
      _count = null;
      _locked = false;
      _phase = _Phase.enter;
      _phaseAt = _now;
      _after(1000, () => _phase = _Phase.idle);
      _after(750, _playAudio);
    });
  }

  void _playAudio() {
    if (_sound) {
      final asset = soundDetectiveLetterAudio[_q.name];
      if (asset != null && _voice != null) {
        unawaited(_playLetterAudio(asset));
      } else {
        _sfx();
      }
    }
    _wave = true;
    _after(1000, () => _wave = false);
  }

  void _replay() {
    if (!_locked) setState(_playAudio);
  }

  void _tap(int slot) {
    if (_locked || _screen != _Screen.play) return;
    unawaited(_stopLetterAudio());
    final q = _q;
    final right = _order[slot] == q.letter;
    final praise = _kPraise[_qi % _kPraise.length];
    setState(() {
      _locked = true;
      _pose = List.filled(3, _Pose.idle)
        ..[slot] = right ? _Pose.happy : _Pose.sad;
      _react[slot] = _pose[slot];
      _reactAt = _now;
      _fb = right;
      _fbAt = _now;
      _fbEn = right
          ? '${praise.$1} ${q.name} is ${q.letter}'
          : 'Oops — listen again!';
      _fbAr = right ? praise.$2 : 'حاول مرة أخرى';
      if (right) {
        _flying = slot;
        _flyAt = _now;
      } else {
        _errors++;
        _missed.add(_qi);
      }
    });
    if (right) {
      _sfx();
      HapticFeedback.mediumImpact();
      _after(520, () {
        _sfx();
        _stars++;
        _flying = null;
      });
      _after(3000, () {
        _phase = _Phase.exit;
        _phaseAt = _now;
        _fb = null;
        _pose = List.filled(3, _Pose.idle);
      });
      _after(3620, () {
        final next = _qi + 1;
        if (next >= _n) {
          _sfx();
          _screen = _Screen.done;
          _screenAt = _now;
          _locked = false;
          return;
        }
        _qi = next;
        _order = _shuffled(next);
        _cast = [0, 1, 2]..shuffle(_rng);
        _phase = _Phase.enter;
        _phaseAt = _now;
        _locked = false;
        _after(1000, () => _phase = _Phase.idle);
        _after(700, _playAudio);
      });
    } else {
      HapticFeedback.heavyImpact();
      _after(3000, () {
        _pose = List.filled(3, _Pose.idle);
        _fb = null;
        _locked = false;
        _playAudio();
      });
    }
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    widget.onComplete(widget.xp, _n / (_n + _errors) * 100, _errors);
  }

  // ---- build ----

  /// Rebuilds [fn] every frame with the clock's time in seconds.
  Widget _tick(Widget Function(double t) fn) =>
      AnimatedBuilder(animation: _time, builder: (_, _) => fn(_time.value));

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // First open: the forest fades up from cream and settles from a
            // slight zoom, before the start screen's pieces arrive.
            const ColoredBox(color: Color(0xFFFFF6E3)),
            _tick((t) {
              final p = still ? 1.0 : (t / 1.6).clamp(0.0, 1.0);
              return Opacity(
                opacity: Curves.easeOut.transform((p * 2).clamp(0.0, 1.0)),
                child: Transform.scale(
                  scale: _lerp(1.08, 1, Curves.easeOutCubic.transform(p)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    layoutBuilder: _fillSwitcher,
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: ColoredBox(
                      key: ValueKey(_screen == _Screen.title),
                      color: const Color(0xFF3F6B2A),
                      child: _ForestScene(
                        _screen == _Screen.title ? _kStartForest : _kGameForest,
                        time: _time,
                        still: still,
                        art: _art,
                      ),
                    ),
                  ),
                ),
              );
            }),
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _AmbientPainter(_time, still)),
              ),
            ),
            FittedBox(
              child: SizedBox(
                width: _kW,
                height: _kH,
                // Fade-through: the old screen eases away as the new one
                // fades up and settles in from just below full size.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 520),
                  layoutBuilder: _fillSwitcher,
                  reverseDuration: const Duration(milliseconds: 320),
                  switchInCurve: const Interval(
                    .3,
                    1,
                    curve: Curves.easeOutCubic,
                  ),
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween(begin: .96, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_screen),
                    child: switch (_screen) {
                      _Screen.title => _buildTitle(),
                      _Screen.howTo => _buildHowTo(),
                      _Screen.play => _buildPlay(),
                      _Screen.done => _buildDone(),
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// AnimatedSwitcher layout that keeps the outgoing and incoming screens
  /// filling the whole area; the default loose Stack lets the forest shrink
  /// to its own shape and screens size to their content.
  static Widget _fillSwitcher(Widget? current, List<Widget> previous) =>
      Stack(fit: StackFit.expand, children: [...previous, ?current]);

  /// sd-pop: the cards' springy entrance.
  Widget _pop(double at, double dur, Widget child) => _tick((t) {
    final p = (t - at) / dur;
    final s = _kf(p, [(0, .82), (.65, 1.03), (1, 1)], Curves.easeOutCubic);
    return Opacity(
      opacity: _kf(p, [(0, 0), (.6, 1), (1, 1)], Curves.easeOut),
      child: Transform.scale(scale: s, child: child),
    );
  });

  BoxDecoration _board({
    double border = 7,
    double radius = 26,
    double drop = 12,
    Color bottom = _kCardBottom,
  }) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_kCardTop, bottom],
    ),
    border: Border.all(color: _kBrown, width: border),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: const Color(0x735A3714), offset: Offset(0, drop)),
    ],
  );

  /// Start screen: logo, session plank, the two young detectives and
  /// floating letters over the forest path, laid out on the stage from the
  /// reference art.
  Widget _buildTitle() {
    final at = _screenAt;

    /// Springy entrance [delay]s after the screen opens.
    double enter(double t, double delay, [double dur = .6]) => const Cubic(
      .2,
      .9,
      .25,
      1.06,
    ).transform(((t - at - delay) / dur).clamp(0.0, 1.0));

    Widget img(String name) => Image.asset('$_kA/$name.png');

    Widget letter(String name, double cx, double cy, double w, int i) =>
        Positioned(
          left: cx - w / 2,
          top: cy - w,
          width: w,
          height: w * 2,
          child: IgnorePointer(
            child: _tick((t) {
              final e = enter(t, .95 + i * .08, .55);
              final wave = math.sin((t / 2.6 + i * .23) * 2 * math.pi);
              return Opacity(
                opacity: e.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, wave * 5),
                  child: Transform.rotate(
                    angle: wave * 4 * math.pi / 180,
                    child: Transform.scale(
                      scale: _lerp(.3, 1, e),
                      child: img(name),
                    ),
                  ),
                ),
              );
            }),
          ),
        );

    /// The detectives fade up into place once, then stand still.
    Widget kid(
      String name,
      double left,
      double top,
      double w,
      double h,
      double delay,
    ) => Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: IgnorePointer(
        child: _tick((t) {
          final e = Curves.easeOutCubic.transform(
            ((t - at - delay) / .7).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: e,
            child: Transform.translate(
              offset: Offset(0, 22 * (1 - e)),
              child: img(name),
            ),
          );
        }),
      ),
    );

    Widget sparkle(double cx, double cy, double size, int i) => Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: _tick((t) {
          final p = _loop(t, 1.8 + i % 3 * .5, i * .37);
          final s = _kf(p, [(0, .4), (.5, 1), (1, .4)], Curves.easeInOut);
          return Opacity(
            opacity: s * enter(t, 1.35).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: s,
              child: const CustomPaint(painter: _SparklePainter()),
            ),
          );
        }),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (i, (x, y, s)) in const [
          (214.0, 96.0, 14.0),
          (245.0, 101.0, 11.0),
          (341.0, 129.0, 10.0),
          (360.0, 162.0, 12.0),
          (205.0, 372.0, 12.0),
          (56.0, 391.0, 10.0),
          (348.0, 475.0, 12.0),
          (386.0, 452.0, 9.0),
          (21.0, 464.0, 10.0),
        ].indexed)
          sparkle(x, y, s, i),
        letter('letter_ta', 75, 351, 47, 0),
        letter('letter_ba', 186, 337, 38, 1),
        letter('letter_alif', 360, 351, 22, 2),
        letter('letter_kha', 30, 424, 34, 3),
        letter('letter_tha', 361, 420, 45, 4),
        Positioned.fill(
          child: IgnorePointer(
            child: _tick(
              (t) => Opacity(
                opacity: ((t - at - .8) / .7).clamp(0.0, 1.0),
                child: const CustomPaint(painter: _GroundShadowPainter()),
              ),
            ),
          ),
        ),
        kid('start_girl', 212, 410, 177, 280, .85),
        kid('start_boy', 28, 372, 186, 308, .75),
        Positioned(
          left: 35,
          top: 96,
          width: 332,
          height: 148,
          child: _tick((t) {
            final breathe = _kf(_loop(t, 3.2), [(0, 1), (.5, 1.02), (1, 1)]);
            return Transform.scale(
              scale: breathe,
              child: _pop(
                at + .35,
                .6,
                Stack(
                  fit: StackFit.expand,
                  children: [
                    img('start_logo'),
                    // The logo's own blank plank, between its two bolts.
                    Positioned(
                      left: 332 * .19,
                      right: 332 * .21,
                      top: 148 * .755,
                      bottom: 148 * .07,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              _outlined(
                                'Session ${_s.number}: ',
                                const Color(0xFFFFF6DF),
                              ),
                              _outlined(_s.range, const Color(0xFFFFD43B)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        Positioned(
          left: 201 - 150,
          top: 248,
          width: 300,
          height: 60,
          child: _pop(
            at + .6,
            .5,
            Stack(
              fit: StackFit.expand,
              children: [
                img('start_scroll'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(54, 8, 54, 16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Listen and find the right sound!',
                      style: _baloo(14, 800, const Color(0xFF5A2E0E)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 201 - 142,
          top: 672,
          width: 284,
          height: 110,
          child: _tick((t) {
            final e = enter(t, 1.2, .55);
            final pulse = _kf(_loop(t, 1.6, .75), [
              (0, 1),
              (.5, 1.045),
              (1, 1),
            ]);
            return Opacity(
              opacity: e.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _lerp(.6, 1, e) * pulse,
                child: _ImgPressButton(
                  key: const ValueKey('sd-play'),
                  up: '$_kA/play.png',
                  down: '$_kA/play_down.png',
                  onTap: _toHowTo,
                ),
              ),
            );
          }),
        ),
        for (final (left, btn) in [
          (true, _gameBtn('home', widget.onExit ?? () {})),
          (false, _musicBtn()),
        ])
          Positioned(
            left: left ? 12 : null,
            right: left ? null : 12,
            top: 42,
            child: _tick(
              (t) => Opacity(
                opacity: Curves.easeOut.transform(
                  ((t - at - .5) / .5).clamp(0.0, 1.0),
                ),
                child: btn,
              ),
            ),
          ),
      ],
    );
  }

  /// Chunky plank lettering with a dark brown outline, like the logo's.
  Widget _outlined(String s, Color fill) {
    TextStyle style(Paint? stroke) => TextStyle(
      fontFamily: 'Baloo2Var',
      fontSize: 17,
      fontWeight: FontWeight.w800,
      fontVariations: const [ui.FontVariation.weight(800)],
      color: stroke == null ? fill : null,
      foreground: stroke,
      height: 1.1,
    );
    return Stack(
      children: [
        Text(
          s,
          style: style(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF4A230B),
          ),
        ),
        Text(s, style: style(null)),
      ],
    );
  }

  void _toHowTo() {
    setState(() {
      _screen = _Screen.howTo;
      _screenAt = _now;
      _goReady = false;
    });
    _after(5000, () {
      _goReady = true;
      _goAt = _now;
    });
  }

  void _toTitle() => setState(() {
    _screen = _Screen.title;
    _screenAt = _now;
  });

  /// How to Play: three steps with little looping demos, the young
  /// detective's tip about the dots, then Let's Go into the game.
  Widget _buildHowTo() {
    final at = _screenAt;

    /// Springy entrance [delay]s after the screen opens.
    Widget rise(double delay, Widget child) => _tick((t) {
      final e = const Cubic(
        .2,
        .9,
        .25,
        1.06,
      ).transform(((t - at - delay) / .55).clamp(0.0, 1.0));
      return Opacity(
        opacity: e.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - e)),
          child: Transform.scale(scale: _lerp(.85, 1, e), child: child),
        ),
      );
    });

    /// A step on the leafy step board: its number in the board's green
    /// circle, the demo beside it, then the words.
    Widget step(int n, Widget icon, String en, String ar) {
      const w = 366.0, h = w / 3.782;
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('$_kA/board_step.png', fit: BoxFit.fill),
            ),
            Positioned(
              left: w * .124 - 26,
              top: h * .49 - 26,
              width: 52,
              height: 52,
              child: Center(
                child: Text(
                  '$n',
                  style: _baloo(
                    27,
                    800,
                    Colors.white,
                    height: 1,
                    shadows: const [
                      Shadow(color: Color(0xFF1E4A08), offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: w * .315 - 33,
              top: h * .48 - 33,
              width: 66,
              height: 66,
              child: icon,
            ),
            Positioned(
              left: w * .45,
              right: w * .045,
              top: h * .1,
              bottom: h * .14,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: w * .505,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          en,
                          textAlign: TextAlign.center,
                          style: _baloo(14.5, 800, _kInk, height: 1.15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ar,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: _naskh(13, const Color(0xFF6B4A26)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Step 1: a small speaker that keeps "playing".
    final listen = _tick((t) {
      final p = _loop(t, 1.2);
      return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: _kf(p, [(0, .8), (1, 0)], Curves.easeOut),
            child: Transform.scale(
              scale: _kf(p, [(0, .7), (1, 1.35)], Curves.easeOut),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF7FD0FF), width: 4),
                ),
              ),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-.3, -.44),
                radius: .9,
                colors: [Color(0xFF4FB3F6), Color(0xFF1D78C9)],
              ),
              boxShadow: [
                BoxShadow(color: Color(0xFF14588F), offset: Offset(0, 4)),
              ],
            ),
            child: _svg(_kSpeakerSvg, 26, 24),
          ),
        ],
      );
    });

    // Step 2: a finger taps the fox, who hops with a green check.
    final fox = _kCast[0];
    final tap = _tick((t) {
      final p = _loop(t, 2.2);
      final press = _kf(p, [(0, 0), (.3, 0), (.4, 1), (.5, 0), (1, 0)]);
      final hop = _kf(p, [(0, 0), (.42, 0), (.55, -6), (.7, 0), (1, 0)]);
      final ok = p > .45 && p < .9;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: Offset(0, hop),
            child: SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset('$_kA/${fox.key}_idle.png'),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SignLetterPainter(_q.letter, fox.sign),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ok) Positioned(right: -2, top: -2, child: _svg(_kOkMarkSvg, 20)),
          Positioned(
            right: -6,
            bottom: -8 + press * 6,
            child: Transform.scale(
              scale: 1 - press * .12,
              child: const Icon(
                Icons.touch_app_rounded,
                size: 28,
                color: Colors.white,
                shadows: [Shadow(color: Color(0xCC3A2410), blurRadius: 3)],
              ),
            ),
          ),
        ],
      );
    });

    // Step 3: a star that keeps twinkling.
    final star = _tick((t) {
      final p = _loop(t, 1.6);
      return Center(
        child: Transform.rotate(
          angle: _kf(p, [(0, 0), (.5, 12), (1, 0)]) * math.pi / 180,
          child: Transform.scale(
            scale: _kf(p, [(0, 1), (.5, 1.18), (1, 1)]),
            child: _starArt(48),
          ),
        ),
      );
    });

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 26,
          right: 26,
          top: 92,
          child: _pop(
            at,
            .45,
            _boardText(
              'board_howto',
              350,
              const EdgeInsets.fromLTRB(.1, .17, .1, .23),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How to Play',
                    style: _baloo(30, 800, _kInk, height: 1.1),
                  ),
                  _ar('كيف تلعب', _naskh(18, _kInk, bold: true)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          top: 214,
          child: Column(
            children: [
              rise(
                .2,
                step(1, listen, 'Listen to the sound.', 'استمع إلى الصوت'),
              ),
              const SizedBox(height: 8),
              rise(
                .35,
                step(
                  2,
                  tap,
                  'Tap the animal holding the right letter.',
                  'اضغط على الحيوان الصحيح',
                ),
              ),
              const SizedBox(height: 8),
              rise(.5, step(3, star, 'Get it right, win a star!', 'اربح نجمة')),
            ],
          ),
        ),
        const Positioned(
          left: 18,
          top: 762,
          width: 124,
          height: 18,
          child: IgnorePointer(
            child: CustomPaint(painter: _SoftShadowPainter()),
          ),
        ),
        Positioned(
          left: 4,
          top: 536,
          width: 142,
          height: 236,
          child: rise(.65, Image.asset('$_kA/start_boy.png')),
        ),
        Positioned(
          left: 130,
          top: 552,
          child: rise(
            .8,
            _boardText(
              'board_bubble',
              262,
              const EdgeInsets.fromLTRB(.11, .19, .07, .18),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Look closely at the dots!',
                    textAlign: TextAlign.center,
                    style: _baloo(14, 800, _kInk, height: 1.2),
                  ),
                  _ar(
                    'ب   ت   ث',
                    _naskh(26, _kGreen, bold: true).copyWith(height: 1.25),
                  ),
                  _ar(
                    'انظر إلى النقاط جيداً',
                    _naskh(13, const Color(0xFF6B4A26)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Center(
            child: !_goReady
                ? const SizedBox(height: 64)
                : _pop(
                    _goAt,
                    .5,
                    SizedBox(
                      width: 236,
                      height: 64,
                      child: _ImgPressButton(
                        key: const ValueKey('sd-go'),
                        up: '$_kA/btn_green.png',
                        down: '$_kA/btn_green_down.png',
                        onTap: _start,
                        child: Text(
                          "Let's Go!",
                          style: _baloo(
                            26,
                            800,
                            Colors.white,
                            shadows: _kBtnShadow,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(left: 12, top: 52, child: _backBtn(_toTitle)),
        Positioned(right: 12, top: 52, child: _musicBtn()),
      ],
    );
  }

  Widget _buildPlay() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 62, 12, 44),
          child: Column(
            children: [
              Row(
                children: [
                  _backBtn(_toHowTo),
                  const SizedBox(width: 6),
                  _boardText(
                    'board_star',
                    112,
                    const EdgeInsets.fromLTRB(.40, .22, .08, .14),
                    Text(
                      '$_stars/$_n',
                      style: _baloo(20, 800, _kInk, height: 1.1),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _boardText(
                        'board_q',
                        100,
                        const EdgeInsets.fromLTRB(.08, .27, .11, .14),
                        Text(
                          'Q${_qi + 1} of $_n',
                          style: _baloo(15, 800, _kInk, height: 1.1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _musicBtn(),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_wave)
                      _tick((t) {
                        final p = _loop(t, .9);
                        return Opacity(
                          opacity: _kf(p, [(0, .85), (1, 0)], Curves.easeOut),
                          child: Transform.scale(
                            scale: _kf(p, [(0, .6), (1, 2.1)], Curves.easeOut),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF7FD0FF),
                                  width: 5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    _SpeakerButton(onTap: _replay),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xD1FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'playing: ${_q.name}',
                  style: _baloo(13, 700, const Color(0xFF3D5A1C)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _n; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Container(
                        width: i == _qi ? 16 : 11,
                        height: 11,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0x8C5A3714),
                            width: 2,
                          ),
                          color: i < _qi
                              ? const Color(0xFFFFC41F)
                              : i == _qi
                              ? Colors.white
                              : const Color(0x73FFFFFF),
                          boxShadow: i == _qi
                              ? const [
                                  BoxShadow(
                                    color: Color(0x80FFFFFF),
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _boardText(
                'board_question',
                350,
                const EdgeInsets.fromLTRB(.08, .2, .08, .19),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Which letter makes this sound?',
                      style: _baloo(17, 800, _kInk, height: 1.2),
                    ),
                    _ar(
                      'أيُّ حرفٍ يُصدِر هذا الصوت؟',
                      _naskh(15, const Color(0xFF5B3B1E)),
                    ),
                  ],
                ),
                height: 104,
              ),
              if (_fb != null) ...[
                const SizedBox(height: 12),
                _pop(_fbAt, .3, _feedbackCard(_fb!)),
              ],
            ],
          ),
        ),
        // The reacting animal paints last so its glow sits over neighbours.
        for (final i
            in [0, 1, 2]..sort(
              (a, b) => (_pose[a] == _Pose.idle ? 0 : 1).compareTo(
                _pose[b] == _Pose.idle ? 0 : 1,
              ),
            ))
          Positioned(
            key: ValueKey('sd-slot-$i'),
            left: 2 + i * _kSlotW,
            width: _kSlotW,
            bottom: 178,
            height: _kSlotBox,
            child: _slot(i),
          ),
        if (_fb != null) _feedbackBar(_fb!),
        if (_flying != null) _flyingStar(_flying!),
        if (_count != null) Positioned.fill(child: _countdown(_count!)),
      ],
    );
  }

  /// Wooden board art of [width] with [child] fitted inside its cream
  /// panel; [inset] is the panel's edges as fractions of the board.
  Widget _boardText(
    String art,
    double width,
    EdgeInsets inset,
    Widget child, {
    double? height,
  }) {
    final h = height ?? width / _kBoardAspect[art]!;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('$_kA/$art.png', fit: BoxFit.fill),
          Padding(
            padding: EdgeInsets.fromLTRB(
              inset.left * width,
              inset.top * h,
              inset.right * width,
              inset.bottom * h,
            ),
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ],
      ),
    );
  }

  /// Glossy feedback board: green with outlined white text when right,
  /// yellow with brown text when it's a miss.
  Widget _feedbackCard(bool ok) {
    const brown = Color(0xFF4A2A0E);
    const edge = Color(0xFF1E4A08);
    return _boardText(
      ok ? 'board_ok' : 'board_oops',
      262,
      const EdgeInsets.fromLTRB(.07, .14, .07, .2),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ok
              ? _stroked(
                  _fbEn,
                  _baloo(18, 800, Colors.white, height: 1.15),
                  edge,
                )
              : Text(_fbEn, style: _baloo(18, 800, brown, height: 1.15)),
          ok
              ? _stroked(
                  _fbAr,
                  _naskh(16, Colors.white, bold: true),
                  edge,
                  rtl: true,
                )
              : _ar(_fbAr, _naskh(16, brown, bold: true)),
        ],
      ),
    );
  }

  /// [style] text with a [stroke]-coloured outline behind it.
  Widget _stroked(String s, TextStyle style, Color stroke, {bool rtl = false}) {
    final dir = rtl ? TextDirection.rtl : null;
    return Stack(
      children: [
        Text(
          s,
          textDirection: dir,
          style: style.copyWith(
            color: null,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(s, textDirection: dir, style: style),
      ],
    );
  }

  Widget _feedbackBar(bool ok) => Positioned(
    left: 0,
    right: 0,
    bottom: 62,
    child: Center(
      child: _tick((t) {
        final p = (t - _fbAt) / .28;
        final c = const Cubic(.2, .9, .25, 1.1);
        return Opacity(
          opacity: _kf(p, [(0, 0), (1, 1)], c).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _kf(p, [(0, 14), (1, 0)], c)),
            child: Transform.scale(
              scale: _kf(p, [(0, .86), (1, 1)], c),
              child: Container(
                padding: const EdgeInsets.fromLTRB(38, 15, 38, 17),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: ok
                        ? const [Color(0xFF6DC93A), Color(0xFF3F8F16)]
                        : const [Color(0xFFF0584A), Color(0xFFC0261B)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: ok
                        ? const Color(0xFF2E6D10)
                        : const Color(0xFF8F1A12),
                    width: 4,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x593C230A), offset: Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _svg(ok ? _kOkBarSvg : _kBadBarSvg, 40),
                    const SizedBox(width: 13),
                    Text(
                      ok ? 'Correct!' : 'Try again!',
                      style: _baloo(
                        27,
                        800,
                        Colors.white,
                        ls: .27,
                        shadows: const [
                          Shadow(
                            color: Color(0x38000000),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );

  /// Big 3-2-1-Go! over the clearing, each number popping in and easing
  /// away before the next.
  Widget _countdown(int n) {
    final go = n == 0;
    return IgnorePointer(
      child: _tick((t) {
        final p = ((t - _countAt) / 1.0).clamp(0.0, 1.0);
        final s = _kf(p, [
          (0, .4),
          (.22, 1.12),
          (.35, 1),
          (1, .92),
        ], Curves.easeOut);
        final o = _kf(p, [(0, 0), (.15, 1), (.75, 1), (1, 0)]);
        return Align(
          alignment: const Alignment(0, .28),
          child: Opacity(
            opacity: o,
            child: Transform.scale(
              scale: s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    go ? 'Go!' : '$n',
                    style: TextStyle(
                      fontFamily: 'Baloo2Var',
                      fontSize: go ? 96 : 120,
                      fontWeight: FontWeight.w800,
                      fontVariations: const [ui.FontVariation.weight(800)],
                      height: 1,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 12
                        ..strokeJoin = StrokeJoin.round
                        ..color = const Color(0xFF5B3B1E),
                    ),
                  ),
                  Text(
                    go ? 'Go!' : '$n',
                    style: _baloo(
                      go ? 96 : 120,
                      800,
                      go ? const Color(0xFF7ED957) : const Color(0xFFFFD23F),
                      height: 1,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Star flies from the tapped animal up to the star counter.
  Widget _flyingStar(int slot) {
    final x = 67.0 + slot * 134;
    return Positioned(
      left: x - 26,
      top: 560,
      child: IgnorePointer(
        child: _tick((t) {
          final p = (t - _flyAt) / .7;
          final e = Curves.easeIn.transform(p.clamp(0.0, 1.0));
          return Opacity(
            opacity: _kf(p, [(0, 1), (.7, 1), (1, 0)], Curves.easeIn),
            child: Transform.translate(
              offset: Offset((108 - x) * e, -497 * e),
              child: Transform.scale(
                scale: _lerp(1, .45, e),
                child: _starArt(52),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// One animal slot: the tap target is the slot's own third of the row,
  /// while the sprite spills 33% past each side like the design.
  Widget _slot(int i) {
    const box = _kSlotBox;
    final a = _kCast[_cast[i]];
    final pose = _pose[i];
    final idle = pose == _Pose.idle;
    final mark = a.at(pose);
    final react = _react[i];
    final glow = react == _Pose.happy
        ? const [Color(0xFF96FF8C), Color(0xF23CDC46), Color(0xCC1EB432)]
        : const [Color(0xFFFFA096), Color(0xF2F04637), Color(0xCCC81E19)];

    Widget sprite(String pose) =>
        Image.asset('$_kA/${a.key}_$pose.png', fit: BoxFit.contain);

    Widget tinted(
      String pose,
      Color c,
      double sigma, [
      Offset o = Offset.zero,
    ]) => Transform.translate(
      offset: o,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: Image.asset(
          '$_kA/${a.key}_$pose.png',
          fit: BoxFit.contain,
          color: c,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );

    final body = SizedBox(
      width: box,
      height: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: box * .27,
            right: box * .27,
            bottom: box * .01,
            height: box * .07,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.elliptical(60, 10)),
                  gradient: RadialGradient(
                    colors: [Color(0x6B281A0A), Color(0x00281A0A)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: tinted(
              idle ? 'idle' : react.name,
              const Color(0x59231608),
              2.5,
              const Offset(2, 6),
            ),
          ),
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: idle ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  tinted(react.name, glow[2], 15),
                  tinted(react.name, glow[1], 7),
                  tinted(react.name, glow[0], 2.5),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: idle ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  sprite('idle'),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _BlinkPainter(
                        _time,
                        a.eyes,
                        _cast[i] * 1.9,
                        _art['${a.key}_lids.png'],
                        MediaQuery.of(context).disableAnimations,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: idle ? 0 : 1,
              duration: const Duration(milliseconds: 260),
              child: sprite(react.name),
            ),
          ),
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: idle ? 1 : 0,
              duration: Duration(milliseconds: idle ? 340 : 200),
              curve: idle ? const Interval(.41, 1) : Curves.ease,
              child: AnimatedScale(
                scale: idle ? 1 : .94,
                alignment: Alignment(
                  a.sign.center.dx / 320 - 1,
                  a.sign.center.dy / 320 - 1,
                ),
                duration: const Duration(milliseconds: 200),
                child: Semantics(
                  label: _order[i],
                  child: CustomPaint(
                    painter: _SignLetterPainter(_order[i], a.sign),
                  ),
                ),
              ),
            ),
          ),
          if (!idle)
            Positioned(
              left: box * mark[0] / 100 - 19,
              top: box * mark[1] / 100 - 19,
              child: _tick((t) {
                final p = (t - _reactAt) / .24;
                return Opacity(
                  opacity: _kf(p, [(0, 0), (.6, 1), (1, 1)], Curves.easeOut),
                  child: Transform.scale(
                    scale: _kf(p, [
                      (0, .35),
                      (.6, 1.14),
                      (1, 1),
                    ], Curves.easeOut),
                    child: _svg(
                      pose == _Pose.happy ? _kOkMarkSvg : _kBadMarkSvg,
                      38,
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );

    final cached = RepaintBoundary(child: body);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(i),
      child: OverflowBox(
        maxWidth: box,
        minWidth: box,
        child: _tick((t) => _animate(i, pose, t, cached)),
      ),
    );
  }

  /// Bounce/shake for a reaction, else the enter/exit hop for the phase.
  Widget _animate(int i, _Pose pose, double t, Widget child) {
    var dx = 0.0, dy = 0.0, s = 1.0, rot = 0.0, o = 1.0;
    if (pose == _Pose.happy) {
      final p = ((t - _reactAt) / .42).clamp(0.0, 2.0) % 1.0;
      final done = t - _reactAt >= .84;
      if (!done) {
        dy = _kf(p, [
          (0, 0),
          (.3, -26),
          (.55, 0),
          (.75, -10),
          (1, 0),
        ], Curves.easeOut);
        s = _kf(p, [
          (0, 1),
          (.3, 1.06),
          (.55, .98),
          (.75, 1),
          (1, 1),
        ], Curves.easeOut);
      }
    } else if (pose == _Pose.sad) {
      final p = ((t - _reactAt) / .28).clamp(0.0, 2.0) % 1.0;
      if (t - _reactAt < .56) {
        const stops = [0.0, .2, .4, .6, .8, 1.0];
        dx = _kf(p, [
          for (final (j, v) in [0.0, -7.0, 7.0, -5.0, 5.0, 0.0].indexed)
            (stops[j], v),
        ], Curves.easeInOut);
        rot = _kf(p, [
          for (final (j, v) in [0.0, -3.0, 3.0, -2.0, 2.0, 0.0].indexed)
            (stops[j], v),
        ], Curves.easeInOut);
      }
    } else if (_phase == _Phase.enter) {
      final p = (t - _phaseAt - i * .11) / .62;
      const c = Cubic(.2, .9, .25, 1.06);
      dy = _kf(p, [(0, 46), (1, 0)], c);
      s = _kf(p, [(0, .82), (1, 1)], c);
      o = _kf(p, [(0, 0), (.6, 1), (1, 1)], c).clamp(0.0, 1.0);
    } else if (_phase == _Phase.wait) {
      o = 0;
    } else if (_phase == _Phase.exit) {
      final p = (t - _phaseAt - i * .07) / .5;
      const c = Cubic(.55, 0, .75, 0);
      dy = _kf(p, [(0, 0), (1, 38)], c);
      s = _kf(p, [(0, 1), (1, .8)], c);
      o = _kf(p, [(0, 1), (1, 0)], c);
    }
    return Opacity(
      opacity: o,
      child: Transform(
        alignment: const Alignment(0, .8),
        transform: Matrix4.translationValues(dx, dy, 0)
          ..rotateZ(rot * math.pi / 180)
          ..scaleByDouble(s, s, 1, 1),
        child: child,
      ),
    );
  }

  /// First-try accuracy for the round, 0-100.
  int get _accuracy => (_n / (_n + _errors) * 100).round();

  /// A high score earns the cheering finale; otherwise the detectives
  /// cheer the child on to try again.
  bool get _highScore => _accuracy >= 80;

  /// 3 stars for a clean round, 2 for a high score, 1 for finishing.
  int get _rating => _errors == 0 ? 3 : (_highScore ? 2 : 1);

  /// Ending: a congratulations (or encouragement) banner, a star rating,
  /// the round's summary with every letter learned — the ones that needed
  /// another listen marked — and the two young detectives celebrating or
  /// cheering the child on.
  Widget _buildDone() {
    final at = _screenAt;
    final high = _highScore;
    final missed = [for (final i in _missed.toList()..sort()) _s.questions[i]];

    Widget rise(double delay, Widget child, {double dy = 26}) => _tick((t) {
      final e = const Cubic(
        .2,
        .9,
        .25,
        1.06,
      ).transform(((t - at - delay) / .55).clamp(0.0, 1.0));
      return Opacity(
        opacity: e.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, dy * (1 - e)),
          child: Transform.scale(scale: _lerp(.8, 1, e), child: child),
        ),
      );
    });

    Widget star(int i, double size) {
      final won = i < _rating;
      return _tick((t) {
        final p = (t - at - .45 - i * .22) / .45;
        final s = _kf(p, [(0, 0), (.6, 1.25), (1, 1)], Curves.easeOut);
        final wob = won
            ? _kf(_loop(t, 2, i * .3), [(0, 0), (.5, 8), (1, 0)])
            : 0;
        return Transform.rotate(
          angle: wob * math.pi / 180,
          child: Transform.scale(
            scale: s,
            child: Opacity(
              opacity: won ? 1 : .35,
              child: ColorFiltered(
                colorFilter: won
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : const ColorFilter.matrix([
                        .33, .33, .33, 0, 0, //
                        .33, .33, .33, 0, 0,
                        .33, .33, .33, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                child: _starArt(size),
              ),
            ),
          ),
        );
      });
    }

    Widget stat(Widget icon, String value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x99FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD9B98A), width: 2),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 4),
                  Text(value, style: _baloo(20, 800, _kInk, height: 1.1)),
                ],
              ),
            ),
            FittedBox(
              child: Text(label, style: _baloo(12, 700, _kInk, height: 1.1)),
            ),
          ],
        ),
      ),
    );

    Widget letterChip(int i) {
      final q = _s.questions[i];
      final retry = _missed.contains(i);
      return Container(
        width: 38,
        padding: const EdgeInsets.only(top: 2, bottom: 3),
        decoration: BoxDecoration(
          color: retry ? const Color(0xFFFFE7B8) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: retry ? const Color(0xFFE08A1E) : const Color(0xFF8DBA5E),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Room below the baseline so ج ح خ's hooks clear the name.
            SizedBox(
              height: 34,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  q.letter,
                  textDirection: TextDirection.rtl,
                  style: _naskh(
                    22,
                    const Color(0xFF4A2D12),
                    bold: true,
                  ).copyWith(height: 1.05),
                ),
              ),
            ),
            FittedBox(
              child: Text(q.name, style: _baloo(10, 800, _kInk, height: 1)),
            ),
          ],
        ),
      );
    }

    /// A detective in their cheering or thumbs-up pose; they rise into
    /// place once and then stand still.
    Widget kid(String who, double left, double w, double delay) {
      final art = '$_kA/end_${who}_${high ? 'cheer' : 'thumbs'}.png';
      return Positioned(
        left: left,
        top: 548,
        width: w,
        height: 232,
        child: IgnorePointer(child: rise(delay, Image.asset(art), dy: 40)),
      );
    }

    final bubbleAr = high ? 'أذنان رائعتان!' : 'لنستمع مرة أخرى!';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (high)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _ConfettiPainter(_time, at)),
              ),
            ),
          ),
        Positioned(
          left: 31,
          right: 31,
          top: 92,
          child: _pop(
            at,
            .5,
            _boardText(
              'board_title',
              340,
              const EdgeInsets.fromLTRB(.13, .2, .13, .27),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    high ? 'MUMTAZ!' : 'Good Try!',
                    style: _baloo(
                      34,
                      800,
                      high ? const Color(0xFFB56100) : _kGreen,
                      height: 1.05,
                      ls: .6,
                      shadows: const [
                        Shadow(color: Color(0xCCFFFFFF), offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  _ar(
                    high ? 'ممتاز!' : 'محاولة جيدة!',
                    _naskh(20, const Color(0xFF2F5C17), bold: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 232,
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              star(0, 48),
              const SizedBox(width: 6),
              star(1, 62),
              const SizedBox(width: 6),
              star(2, 48),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 300,
          child: rise(
            .6,
            _boardText(
              'board_panel',
              374,
              const EdgeInsets.fromLTRB(.07, .13, .07, .08),
              SizedBox(
                // The board's inner width, so the stat row can share it out.
                width: 374 * .86,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Session ${_s.number} Complete',
                      style: _baloo(20, 800, _kGreen, height: 1.1),
                    ),
                    Text(
                      'Sound Detective: ${_s.range}',
                      style: _baloo(13, 700, _kInk, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        stat(
                          const Icon(
                            Icons.music_note_rounded,
                            size: 20,
                            color: _kGreen,
                          ),
                          '$_n/$_n',
                          'sounds found',
                        ),
                        const SizedBox(width: 6),
                        stat(_starArt(20), '$_stars', 'stars earned'),
                        const SizedBox(width: 6),
                        stat(
                          const Icon(
                            Icons.bar_chart_rounded,
                            size: 20,
                            color: _kGreen,
                          ),
                          '$_accuracy%',
                          'first try',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.flip(
                            flipX: true,
                            child: const Icon(
                              Icons.eco_rounded,
                              size: 14,
                              color: Color(0xFF5E9A2C),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Letters you learned',
                            style: _baloo(14, 800, _kInk, height: 1.1),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.eco_rounded,
                            size: 14,
                            color: Color(0xFF5E9A2C),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [for (var i = 0; i < _n; i++) letterChip(i)],
                      ),
                    ),
                    if (missed.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_rounded,
                              size: 15,
                              color: Color(0xFFE8731C),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Orange letters needed another listen.',
                              style: _baloo(11, 700, const Color(0xFF9A5A10)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 14,
          top: 764,
          width: 130,
          height: 20,
          child: IgnorePointer(
            child: CustomPaint(painter: _SoftShadowPainter()),
          ),
        ),
        const Positioned(
          left: 258,
          top: 764,
          width: 130,
          height: 20,
          child: IgnorePointer(
            child: CustomPaint(painter: _SoftShadowPainter()),
          ),
        ),
        kid('girl', 6, 142, .85),
        kid('boy', 256, 142, 1.0),
        Positioned(
          left: 130,
          right: 130,
          top: 566,
          child: rise(
            1.15,
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
              decoration: _board(border: 4, radius: 16, drop: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    high ? 'Amazing ears!' : 'Good try!',
                    textAlign: TextAlign.center,
                    style: _baloo(15, 800, _kGreen, height: 1.15),
                  ),
                  Text(
                    high
                        ? 'You found all $_n sounds!'
                        : "Let's practise these:",
                    textAlign: TextAlign.center,
                    style: _baloo(12, 700, _kInk, height: 1.2),
                  ),
                  if (!high)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ar(
                        missed.map((q) => q.letter).join('  '),
                        _naskh(
                          24,
                          const Color(0xFFB5600A),
                          bold: true,
                        ).copyWith(height: 1.35),
                      ),
                    )
                  else
                    const SizedBox(height: 3),
                  _ar(bubbleAr, _naskh(12, const Color(0xFF8A6A42))),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 30,
          child: rise(
            1.3,
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: _ImgPressButton(
                      key: const ValueKey('sd-again'),
                      up: '$_kA/btn_green.png',
                      down: '$_kA/btn_green_down.png',
                      onTap: _start,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Play Again',
                                style: _baloo(
                                  20,
                                  800,
                                  Colors.white,
                                  shadows: _kBtnShadow,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: _ImgPressButton(
                      key: const ValueKey('sd-continue'),
                      up: '$_kA/btn_blue.png',
                      down: '$_kA/btn_blue_down.png',
                      onTap: _finish,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Continue',
                                style: _baloo(
                                  20,
                                  800,
                                  Colors.white,
                                  shadows: _kBtnShadow,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(left: 12, top: 52, child: _backBtn(_start)),
        Positioned(right: 12, top: 52, child: _musicBtn()),
      ],
    );
  }
}

/// Eyelids for an idle animal. Slow, gentle blinks come at irregular
/// 3-10s gaps with the odd double blink, easing shut and drifting open:
/// the upper lid sweeps down, the lower lifts a touch to meet it, and a
/// soft crease fades in only once the eye is shut. The lids are the
/// animal's own face with the eyes painted out in fur, revealed behind a
/// feathered edge, so no hard lines show.
class _BlinkPainter extends CustomPainter {
  _BlinkPainter(this.time, this.eyes, this.seed, this.lids, this.still)
    : super(repaint: time);

  final ValueNotifier<double> time;
  final List<Rect> eyes;

  /// The idle face with its eyes painted out in fur; no blinking until it
  /// has loaded.
  final ui.Image? lids;
  final bool still;

  /// Keeps each animal on its own rhythm.
  final double seed;

  static double _rand(double n) {
    final x = math.sin(n * 12.9898 + 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Lid closure from 0 (open) to 1 (shut) for one blink [dt]s after it
  /// starts: a brisk ~0.3s blink that eases shut, rests closed a beat,
  /// then opens a little slower than it closed.
  static double _shut(double dt) {
    const close = .1, hold = .05, open = .16;
    if (dt < 0 || dt > close + hold + open) return 0;
    if (dt < close) return Curves.easeInOutSine.transform(dt / close);
    if (dt < close + hold) return 1;
    return 1 - Curves.easeInOutCubic.transform((dt - close - hold) / open);
  }

  /// One blink somewhere in every 7s window (so 3-10s apart), now and then
  /// a second one right after, like a sleepy double blink.
  double _closure(double t) {
    const window = 7.0;
    final shifted = t + seed;
    final w = (shifted / window).floorToDouble();
    final local = shifted - w * window;
    final at = .3 + 5 * _rand(w + seed * 31);
    var c = _shut(local - at);
    if (_rand(w * 1.7 + seed) < .15) c = math.max(c, _shut(local - at - .45));
    return c;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lids = this.lids;
    final c = still ? 0.0 : _closure(time.value);
    if (lids == null || c <= 0) return;
    canvas.save();
    canvas.scale(size.width / 640);
    for (final e in eyes) {
      final r = e.inflate(3);
      final w = r.width, h = r.height;
      final cover = e.inflate(9);
      final lidBox = e.inflate(18);
      // The upper lid does nearly all the work; the lower one only lifts
      // enough to hide the eye's bottom rim when shut.
      final meet = r.top + h * .78;
      final upperY = _lerp(cover.top, meet, c);
      final lowerY = _lerp(cover.bottom, meet + 1, c);
      final sag = h * .1 * c;
      final upper = Path()
        ..moveTo(lidBox.left, lidBox.top)
        ..lineTo(lidBox.right, lidBox.top)
        ..lineTo(lidBox.right, upperY)
        ..quadraticBezierTo(r.center.dx, upperY + sag * 2, lidBox.left, upperY)
        ..close();
      final lower = Path()
        ..moveTo(lidBox.left, lidBox.bottom)
        ..lineTo(lidBox.right, lidBox.bottom)
        ..lineTo(lidBox.right, lowerY)
        ..quadraticBezierTo(r.center.dx, lowerY + sag, lidBox.left, lowerY)
        ..close();

      for (final path in [lower, upper]) {
        canvas.saveLayer(lidBox, Paint());
        // The lid art is this face with the eyes painted out in fur, so a
        // lid is simply that fur showing wherever the lid has reached.
        canvas.drawImageRect(
          lids,
          Rect.fromLTWH(0, 0, lids.width.toDouble(), lids.height.toDouble()),
          const Rect.fromLTWH(0, 0, 640, 640),
          Paint()..filterQuality = FilterQuality.medium,
        );
        if (identical(path, upper)) {
          // Faint shade gathering at the lid's rim, no hard line.
          canvas.drawRect(
            lidBox,
            Paint()
              ..blendMode = BlendMode.srcATop
              ..shader = ui.Gradient.linear(
                Offset(0, upperY - h * .3),
                Offset(0, upperY + sag * 2),
                const [Color(0x003A200C), Color(0x243A200C)],
              ),
          );
        }
        // A soft leading edge, so the lid never reads as a drawn line.
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
        canvas.restore();
      }

      // Only once the eye is all but shut does a soft crease fade in where
      // the lids meet, like the art's own closed-eye line.
      if (c > .8) {
        canvas.drawPath(
          Path()
            ..moveTo(r.left + w * .14, upperY + 1)
            ..quadraticBezierTo(
              r.center.dx,
              upperY + sag * 2 + 1,
              r.right - w * .14,
              upperY + 1,
            ),
          Paint()
            ..color = const Color(
              0xFF3A2412,
            ).withValues(alpha: .75 * (c - .8) / .2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.2
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .9),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlinkPainter old) =>
      old.seed != seed ||
      old.still != still ||
      !identical(old.eyes, eyes) ||
      !identical(old.lids, lids);
}

/// Confetti drifting down over the high-score finale, from when the screen
/// opened ([start]) onwards.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.time, this.start) : super(repaint: time);

  final ValueNotifier<double> time;
  final double start;

  static const _colors = [
    Color(0xFFFFC41F),
    Color(0xFF6DC93A),
    Color(0xFF4FB3F6),
    Color(0xFFF0584A),
    Color(0xFFB57BFF),
    Color(0xFFFF9F2E),
  ];

  static double _rand(double n) {
    final x = math.sin(n * 91.345 + 12.9) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value - start;
    if (t < 0) return;
    for (var i = 0; i < 46; i++) {
      final fall = 3.2 + _rand(i + .3) * 2.4;
      final p = _loop(t, fall, _rand(i + .7) * 1.6);
      if (t < _rand(i + .7) * 1.6) continue;
      final x =
          size.width * _rand(i + .1) +
          math.sin((t + i) * (1.3 + _rand(i + .9))) * 14;
      final y = -20 + (size.height * .75) * p;
      final spin = t * (2 + _rand(i + .5) * 4) + i;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin);
      canvas.scale(1, math.cos(spin * 1.7).abs() * .8 + .2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 8, height: 12),
          const Radius.circular(2),
        ),
        Paint()
          ..color = _colors[i % _colors.length].withValues(
            alpha: 1 - Curves.easeIn.transform(p),
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.start != start;
}

/// Paints [letter] on an animal's sign: sized to fill the open panel
/// ([panel], in the 640px art) and centred on its inked shape, so every
/// letter — tall alif, dotted tha, hooked kha — sits dead centre.
class _SignLetterPainter extends CustomPainter {
  const _SignLetterPainter(this.letter, this.panel);

  final String letter;
  final Rect panel;

  @override
  void paint(Canvas canvas, Size size) {
    if (letter.isEmpty) return;
    final k = size.width / 640;
    final r = Rect.fromLTRB(
      panel.left * k,
      panel.top * k,
      panel.right * k,
      panel.bottom * k,
    );
    final (cx, cy, w, h) = _kLetterInk[letter] ?? (.5, -.35, .7, .7);
    // Fill ~3/4 of the panel either way; short letters (ha, ta) stop
    // growing before their strokes get heavier than the rest.
    final fs = math.min(
      math.min(r.width * .76 / w, r.height * .7 / h),
      r.height * 1.45,
    );
    final tp = TextPainter(
      text: painting.TextSpan(
        text: letter,
        style: TextStyle(
          fontFamily: 'ScheherazadeNew',
          fontWeight: FontWeight.w700,
          fontSize: fs,
          color: const Color(0xFF4A2D12),
          shadows: const [
            Shadow(color: Color(0x8CFFFFFF), offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final baseline = tp.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    tp.paint(
      canvas,
      Offset(r.center.dx - cx * fs, r.center.dy - baseline - cy * fs),
    );
    tp.dispose();
  }

  @override
  bool shouldRepaint(_SignLetterPainter old) =>
      old.letter != letter || old.panel != panel;
}

/// A soft oval of shade on the ground.
class _SoftShadowPainter extends CustomPainter {
  const _SoftShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Offset.zero & size,
      Paint()
        ..color = const Color(0x6B2A1A08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(_SoftShadowPainter oldDelegate) => false;
}

class _GroundShadowPainter extends CustomPainter {
  const _GroundShadowPainter();

  static const _shade = [
    // (centre x, centre y, width, height, opacity, blur)
    (128.0, 680.0, 170.0, 28.0, .42, 7.0), // boy
    (76.0, 680.0, 78.0, 16.0, .62, 3.0), // boy's planted boot
    (170.0, 664.0, 54.0, 13.0, .34, 4.0), // boy's stepping boot
    (312.0, 690.0, 176.0, 28.0, .42, 7.0), // girl
    (326.0, 690.0, 78.0, 16.0, .62, 3.0), // girl's planted boot
    (262.0, 676.0, 46.0, 12.0, .32, 4.0), // girl's stepping boot
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, w, h, o, blur) in _shade) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        Paint()
          ..color = const Color(0xFF2A1A08).withValues(alpha: o)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  @override
  bool shouldRepaint(_GroundShadowPainter oldDelegate) => false;
}

/// Red slash over the music button while sound is off.
class _MutedSlashPainter extends CustomPainter {
  const _MutedSlashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(size.width * .36, size.height * .22);
    final b = Offset(size.width * .64, size.height * .78);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF6B1A12)
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFFE5392C)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MutedSlashPainter oldDelegate) => false;
}

/// Image button that swaps to its pressed art while held.
class _ImgPressButton extends StatefulWidget {
  const _ImgPressButton({
    super.key,
    required this.up,
    required this.down,
    required this.onTap,
    this.child,
  });

  final String up;
  final String down;
  final VoidCallback onTap;

  /// Label drawn over the art, e.g. a glossy pill's text.
  final Widget? child;

  @override
  State<_ImgPressButton> createState() => _ImgPressButtonState();
}

class _ImgPressButtonState extends State<_ImgPressButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Image.asset(
              _down ? widget.down : widget.up,
              fit: BoxFit.fill,
              gaplessPlayback: true,
            ),
            if (widget.child != null)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FittedBox(fit: BoxFit.scaleDown, child: widget.child),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Four-point twinkle.
class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final w = r * .09;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFE9A8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => false;
}

/// The big blue replay button.
class _SpeakerButton extends StatefulWidget {
  const _SpeakerButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<_SpeakerButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('sd-speaker'),
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      child: Transform.translate(
        offset: Offset(0, _down ? 3 : 0),
        child: Container(
          width: 96,
          height: 96,
          alignment: Alignment.topCenter,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF14588F),
            boxShadow: [
              BoxShadow(
                color: Color(0x4D000000),
                offset: Offset(0, 10),
                blurRadius: 22,
              ),
            ],
          ),
          child: Container(
            width: 96,
            height: _down ? 92 : 89,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(48, 46)),
              gradient: RadialGradient(
                center: Alignment(-.3, -.44),
                radius: .9,
                colors: [Color(0xFF4FB3F6), Color(0xFF1D78C9)],
              ),
            ),
            child: _svg(_kSpeakerSvg, 46, 42),
          ),
        ),
      ),
    );
  }
}

/// One painted forest and where its moving parts sit, in the art's pixels.
class _Forest {
  const _Forest(this.name, this.bg, this.fall, this.trees);

  /// Layer file prefix: `<name>_falls_tile.png`, `<name>_tree_l.png`...
  final String name;
  final String bg;
  final Rect fall;

  /// (layer suffix, top-left, crown base y, trunk x, phase); drawn in
  /// order, so list the tree whose crown overlaps the other's last.
  final List<(String, Offset, double, double, double)> trees;
}

const _kStartForest = _Forest(
  'start',
  'start_bg.jpg',
  Rect.fromLTWH(656, 688, 94, 124),
  [('r', Offset(440, 0), 340, 800, .37), ('l', Offset(0, 0), 400, 60, 0)],
);

const _kGameForest = _Forest(
  'game',
  'bg_forest.jpg',
  Rect.fromLTWH(668, 636, 84, 114),
  [('r', Offset(440, 0), 320, 800, .37), ('l', Offset(0, 0), 380, 60, 0)],
);

/// A forest backdrop, laid out in the art's own pixels and cover-fitted:
/// the leaf canopies bend in the wind and the waterfall flows.
class _ForestScene extends StatelessWidget {
  const _ForestScene(
    this.forest, {
    required this.time,
    required this.still,
    required this.art,
  });

  final _Forest forest;
  final ValueNotifier<double> time;
  final bool still;

  /// Decoded scene layers, keyed by file name; empty until loaded.
  final Map<String, ui.Image> art;

  static const _w = 853.0;
  static const _h = 1844.0;

  @override
  Widget build(BuildContext context) {
    final n = forest.name;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _w,
        height: _h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('$_kA/${forest.bg}', fit: BoxFit.fill),
            RepaintBoundary(
              child: CustomPaint(
                painter: _FallsPainter(
                  time,
                  still,
                  forest.fall,
                  art['${n}_falls_tile.png'],
                  art['${n}_falls_mask.png'],
                ),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: _CanopyPainter(time, still, [
                  for (final (side, at, baseY, trunkX, phase) in forest.trees)
                    (art['${n}_tree_$side.png'], at, baseY, trunkX, phase),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leaf canopies as bendable meshes: a slow sway plus gusts that roll
/// across the crown, growing towards the outer tips, with a quick rustle
/// on top so neighbouring leaf clumps never move in lockstep.
class _CanopyPainter extends CustomPainter {
  _CanopyPainter(this.time, this.still, this.trees) : super(repaint: time);

  final ValueNotifier<double> time;
  final bool still;

  /// (art, top-left in scene px, crown base y, trunk x in scene px, phase).
  final List<(ui.Image?, Offset, double, double, double)> trees;

  static const _cols = 18;
  static const _rows = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? 0.0 : time.value;
    for (final (img, at, baseY, trunkX, phase) in trees) {
      if (img == null) continue;
      final w = img.width.toDouble(), h = img.height.toDouble();
      final pos = <Offset>[];
      final tex = <Offset>[];
      // Gusts come and go instead of blowing at one steady strength.
      final gust = .65 + .35 * math.sin((t / 9.5 + phase) * 2 * math.pi);
      for (var r = 0; r <= _rows; r++) {
        for (var c = 0; c <= _cols; c++) {
          final lx = w * c / _cols, ly = h * r / _rows;
          final x = at.dx + lx, y = at.dy + ly;
          final lift = ((baseY - y) / baseY).clamp(0.0, 1.0);
          final reach = ((x - trunkX).abs() / 420).clamp(0.0, 1.0);
          final bend = math.pow(lift, 1.6) * (.45 + .55 * reach);
          final wave =
              .65 * math.sin((t / 5.3 + phase) * 2 * math.pi - x * .004) +
              .35 *
                  math.sin(
                    (t / 2.1 + phase * 1.7) * 2 * math.pi - x * .009 + 1.3,
                  );
          final rustle = math.sin(t * 7.1 + x * .083 + y * .117);
          final rustle2 = math.cos(t * 6.3 + x * .101 - y * .071);
          // Edge vertices stay put where the layer is cut off.
          final pin =
              (c == 0 && at.dx == 0) || (c == _cols && at.dx + w >= 853);
          final dx = pin ? 0.0 : bend * (7 * wave * gust + 1.1 * rustle);
          final dy = bend * (1.6 * wave.abs() * gust + .9 * rustle2);
          pos.add(Offset(x + dx, y + dy));
          tex.add(Offset(lx, ly));
        }
      }
      final idx = <int>[];
      for (var r = 0; r < _rows; r++) {
        for (var c = 0; c < _cols; c++) {
          final i = r * (_cols + 1) + c;
          idx.addAll([
            i,
            i + 1,
            i + _cols + 1,
            i + 1,
            i + _cols + 2,
            i + _cols + 1,
          ]);
        }
      }
      canvas.drawVertices(
        ui.Vertices(
          VertexMode.triangles,
          pos,
          textureCoordinates: tex,
          indices: idx,
        ),
        BlendMode.srcOver,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..shader = ImageShader(
            img,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_CanopyPainter old) =>
      old.still != still ||
      old.trees.indexed.any((e) => !identical(e.$2.$1, trees[e.$1].$1));
}

/// A forest's waterfall. Its own water texture falls under gravity
/// inside the fall's shape — slow at the lip, speeding up and stretching
/// towards the pool — in two sheets for depth, with racing highlights,
/// spray, churning foam, rising mist and ripples. Scene pixel coordinates.
class _FallsPainter extends CustomPainter {
  _FallsPainter(this.time, this.still, this.fall, this.tile, this.mask)
    : super(repaint: time);

  final ValueNotifier<double> time;
  final bool still;

  /// The fall's box in the art: lip at the top, splash at the bottom.
  final Rect fall;
  final ui.Image? tile;
  final ui.Image? mask;

  /// Water leaves the lip at [_v0] and accelerates at [_g] (scene px).
  static const _v0 = 45.0;
  static const _g = 620.0;

  /// Time for water to fall [s] px from the lip.
  static double _tau(double s) =>
      (math.sqrt(_v0 * _v0 + 2 * _g * s) - _v0) / _g;

  void _sheet(
    Canvas canvas,
    ui.Image tile,
    double t,
    double rate,
    double shift,
  ) {
    const cols = 8, rows = 18;
    final pos = <Offset>[];
    final tex = <Offset>[];
    for (var r = 0; r <= rows; r++) {
      final s = fall.height * r / rows;
      final v = (_tau(s) - t * rate) * 118;
      for (var c = 0; c <= cols; c++) {
        final x = fall.left + fall.width * c / cols;
        final wobble = math.sin(t * 2.3 + r * .6 + c * 1.1) * .8;
        pos.add(Offset(x, fall.top + s));
        tex.add(Offset(x - fall.left + shift + wobble, v));
      }
    }
    final idx = <int>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * (cols + 1) + c;
        idx.addAll([i, i + 1, i + cols + 1, i + 1, i + cols + 2, i + cols + 1]);
      }
    }
    canvas.drawVertices(
      ui.Vertices(
        VertexMode.triangles,
        pos,
        textureCoordinates: tex,
        indices: idx,
      ),
      BlendMode.srcOver,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..shader = ImageShader(
          tile,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
        ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? 0.0 : time.value;
    final tile = this.tile, mask = this.mask;

    if (tile != null && mask != null) {
      canvas.saveLayer(fall, Paint());
      _sheet(canvas, tile, t, 1, 0);
      // A thinner, faster sheet over the top gives the water depth.
      canvas.saveLayer(fall, Paint()..color = const Color(0x6B000000));
      _sheet(canvas, tile, t, 1.5, 31);
      canvas.restore();
      // Bright threads of water, each accelerating as it drops.
      for (var i = 0; i < 18; i++) {
        final x = fall.left + 8 + (i * 37 % 78) + math.sin(i * 2.3) * 2;
        final tMax = _tau(fall.height) * 1.15;
        final tau = _loop(t * (.8 + (i * 7 % 5) * .1), tMax, i * .11) * tMax;
        final s = _v0 * tau + .5 * _g * tau * tau;
        final len = 5 + (_v0 + _g * tau) * .055;
        final y = fall.top + s - len;
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + len),
          Paint()
            ..strokeWidth = 1 + (i % 3) * .55
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.linear(
              Offset(x, y),
              Offset(x, y + len),
              const [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
              const [0, .6, 1],
            ),
        );
      }
      canvas.drawImage(
        mask,
        fall.topLeft,
        Paint()..blendMode = BlendMode.dstIn,
      );
      canvas.restore();
    }

    // Ripples spreading from where the water lands.
    for (var i = 0; i < 5; i++) {
      final p = _loop(t, 2.8, i * .56);
      final c = Offset(
        fall.center.dx + (i - 2) * 11,
        fall.bottom + 2 + (i % 2) * 7,
      );
      final w = 16 + p * 80;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w, height: w * .2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = Colors.white.withValues(alpha: .42 * (1 - p) * (1 - p)),
      );
    }

    // Churning foam along the base of the fall.
    final foam = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    for (var i = 0; i < 10; i++) {
      final c = Offset(
        fall.left + 8 + i * (fall.width - 16) / 9 + math.sin(t * 3.1 + i) * 2.2,
        fall.bottom - 12 + math.sin(t * 5.3 + i * 1.7) * 2.2,
      );
      final r = 3.4 + 2 * (.5 + .5 * math.sin(t * 4.2 + i * 2.1));
      canvas.drawCircle(c, r, foam..color = const Color(0xB3FFFFFF));
    }

    // Spray thrown up off the splash, falling back under gravity.
    final drop = Paint()..color = const Color(0xE6FFFFFF);
    for (var i = 0; i < 16; i++) {
      final period = .8 + (i * 5 % 7) * .09;
      final p = _loop(t, period, i * .19);
      final tau = p * period;
      final vx = ((i * 37 % 13) - 6) * 6.0;
      final vy = -55.0 - (i * 23 % 9) * 7;
      final x =
          fall.left + 12 + (i * 29 % 72) / 72 * (fall.width - 22) + vx * tau;
      final y = fall.bottom - 11 + vy * tau + .5 * 260 * tau * tau;
      if (y > fall.bottom - 6) continue;
      canvas.drawCircle(
        Offset(x, y),
        .9 + (i % 3) * .35,
        drop..color = Colors.white.withValues(alpha: .85 * (1 - p)),
      );
    }

    // Mist drifting up off the splash.
    final mist = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (var i = 0; i < 6; i++) {
      final p = _loop(t, 3.4, i * .57);
      final c = Offset(
        fall.left + 12 + i * (fall.width - 24) / 5 + math.sin(t * .9 + i) * 5,
        fall.bottom - 9 - p * 34,
      );
      canvas.drawCircle(
        c,
        6 + p * 11,
        mist
          ..color = Colors.white.withValues(alpha: .28 * math.sin(p * math.pi)),
      );
    }
  }

  @override
  bool shouldRepaint(_FallsPainter old) =>
      old.tile != tile ||
      old.mask != mask ||
      old.still != still ||
      old.fall != fall;
}

/// Sun rays and falling leaves.
class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.time, this.still) : super(repaint: time);

  final ValueNotifier<double> time;
  final bool still;

  static const _leaves = [
    (.14, 13.0, Color(0xFF8FD24A), 34.0, 13.0, 0.0),
    (.52, 11.0, Color(0xFFF3C73F), -46.0, 17.0, 4.0),
    (.78, 14.0, Color(0xFF6FB83A), 28.0, 15.0, 9.0),
    (.33, 9.0, Color(0xFFC8E36A), -24.0, 19.0, 12.0),
  ];

  void _ray(
    Canvas canvas,
    Size size,
    double t,
    double l,
    double w,
    double h,
    Color color,
    double period,
    double delay,
  ) {
    final s = _kf(_loop(t, period, delay), [(0, 0), (.5, 1), (1, 0)]);
    final rw = size.width * w;
    final rh = size.height * h;
    canvas.save();
    canvas.translate(
      size.width * l + rw / 2 + rw * _lerp(-.05, .05, s),
      -size.height * .1,
    );
    canvas.rotate(_lerp(-10, -6, s) * math.pi / 180);
    final r = Rect.fromLTWH(-rw / 2, 0, rw, rh);
    canvas.drawRect(
      r,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
          color.withValues(alpha: color.a * _lerp(.16, .42, s)),
          color.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? 0.0 : time.value;
    _ray(canvas, size, t, .08, .44, .7, const Color(0xD9FFF9D6), 9, 0);
    _ray(canvas, size, t, .44, .26, .6, const Color(0xB3FFFFE6), 12, 1.6);
    if (still) return;
    for (final (l, sz, color, lx, period, delay) in _leaves) {
      if (t < delay) continue;
      final p = _loop(t, period, delay);
      final o = _kf(p, [(0, 0), (.12, .85), (1, 0)], Curves.linear);
      canvas.save();
      canvas.translate(
        size.width * l + lx * p + sz / 2,
        _lerp(-.1 * sz, size.height * 1.15, p) + sz / 2,
      );
      canvas.rotate(340 * p * math.pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(center: Offset.zero, width: sz, height: sz),
          topRight: Radius.circular(sz * .6),
          bottomLeft: Radius.circular(sz * .6),
        ),
        Paint()..color = color.withValues(alpha: o),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) => oldDelegate.still != still;
}
