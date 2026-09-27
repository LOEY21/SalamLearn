import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import 'bend_sprite.dart';

const _kA = 'assets/images/label_maker';

/// Stage size every screen is laid out in (the painted rooms' pixel size),
/// scaled to fit the landscape screen.
const _kW = 1870.0;
const _kH = 841.0;

/// A drop this close (stage px) to the right object always counts, so
/// small targets (nose, key, eraser) stay fair for small fingers.
const _kTolerance = 26.0;

/// Drops further than this from every object snap back without a penalty.
const _kReach = 60.0;

/// How long the How to Play steps stay up before Let's Go appears.
const _kHowToWaitMs = 5000;

/// The all-found finale: every object lights up in the order it was
/// labelled, then they pulse together until the congrats screen.
const _kFinaleMs = 3200;

const _kNavy = Color(0xFF1B2A6B);
const _kCream = Color(0xFFFFF8E6);
const _kGold = Color(0xFFF5B400);

class _Word {
  const _Word(this.ar, this.en, this.audio, this.point, this.label, this.rects);

  final String ar;
  final String en;

  /// AUDIO PLUG POINT: spoken prompt from the Label Maker spec. The app has
  /// no audio package or vocab recordings yet, so prompts are shown as text
  /// on the badge and Replay only pulses it.
  final String audio;

  /// Where the placed label's pin touches the object.
  final Offset point;

  /// Centre of the placed label.
  final Offset label;

  /// Hitboxes on the painted room, in stage px.
  final List<Rect> rects;
}

class _Session {
  const _Session(this.title, this.bg, this.words);

  final String title;
  final String bg;
  final List<_Word> words;
}

const _kSessions = {
  LabelMakerSession.home: _Session('Label Maker: My Home', 'room_home', [
    _Word(
      'بَابٌ',
      'Door',
      'audio/vocab/bab.mp3',
      Offset(290, 470),
      Offset(290, 330),
      [Rect.fromLTWH(240, 370, 100, 295)],
    ),
    _Word(
      'سَرِيرٌ',
      'Bed',
      'audio/vocab/sarir.mp3',
      Offset(670, 160),
      Offset(670, 282),
      [Rect.fromLTWH(505, 80, 330, 150)],
    ),
    _Word(
      'شُبَّاكٌ',
      'Window',
      'audio/vocab/shubbak.mp3',
      Offset(1150, 110),
      Offset(1150, 205),
      [Rect.fromLTWH(1030, 25, 240, 165)],
    ),
    _Word(
      'بَيْتٌ',
      'House',
      'audio/vocab/bayt.mp3',
      Offset(1288, 480),
      Offset(1270, 345),
      [Rect.fromLTWH(1240, 440, 95, 80)],
    ),
    _Word(
      'طَاوِلَةٌ',
      'Table',
      'audio/vocab/tawila.mp3',
      Offset(758, 640),
      Offset(758, 725),
      [Rect.fromLTWH(630, 615, 258, 60)],
    ),
    _Word(
      'تِلْفَازٌ',
      'TV',
      'audio/vocab/tilfaz.mp3',
      Offset(637, 457),
      Offset(637, 355),
      [Rect.fromLTWH(540, 400, 195, 115)],
    ),
    _Word(
      'مِصْبَاحٌ',
      'Lamp',
      'audio/vocab/misbah.mp3',
      Offset(1115, 440),
      Offset(1100, 345),
      [Rect.fromLTWH(1072, 412, 88, 205)],
    ),
    _Word(
      'مَطْبَخٌ',
      'Kitchen',
      'audio/vocab/matbakh.mp3',
      Offset(1620, 450),
      Offset(1640, 262),
      [Rect.fromLTWH(1360, 300, 500, 300)],
    ),
    _Word(
      'كُوبٌ',
      'Cup',
      'audio/vocab/kub.mp3',
      Offset(1558, 700),
      Offset(1450, 600),
      [Rect.fromLTWH(1515, 665, 90, 72)],
    ),
    _Word(
      'مِفْتَاحٌ',
      'Key',
      'audio/vocab/miftah.mp3',
      Offset(1628, 758),
      Offset(1785, 785),
      [Rect.fromLTWH(1570, 728, 120, 60)],
    ),
  ]),
  LabelMakerSession.body: _Session('Label Maker: Body Parts', 'room_body', [
    _Word(
      'رَأْسٌ',
      'Head',
      'audio/vocab/rasun.mp3',
      Offset(924, 205),
      Offset(670, 190),
      [Rect.fromLTWH(830, 185, 185, 52)],
    ),
    _Word(
      'عَيْنٌ',
      'Eye',
      'audio/vocab/aynun.mp3',
      Offset(889, 310),
      Offset(670, 334),
      [Rect.fromLTWH(866, 288, 46, 44), Rect.fromLTWH(934, 288, 46, 44)],
    ),
    _Word(
      'أَنْفٌ',
      'Nose',
      'audio/vocab/anfun.mp3',
      Offset(923, 322),
      Offset(670, 406),
      [Rect.fromLTWH(910, 308, 26, 30)],
    ),
    _Word(
      'فَمٌ',
      'Mouth',
      'audio/vocab/famun.mp3',
      Offset(924, 350),
      Offset(1180, 406),
      [Rect.fromLTWH(898, 338, 52, 30)],
    ),
    _Word(
      'يَدٌ',
      'Hand',
      'audio/vocab/yadun.mp3',
      Offset(1050, 500),
      Offset(1180, 520),
      [Rect.fromLTWH(755, 470, 80, 65), Rect.fromLTWH(1010, 470, 80, 65)],
    ),
    _Word(
      'شَعْرٌ',
      'Hair',
      'audio/vocab/sharun.mp3',
      Offset(870, 255),
      Offset(670, 262),
      [Rect.fromLTWH(822, 237, 200, 38)],
    ),
    _Word(
      'أُذُنٌ',
      'Ear',
      'audio/vocab/udhun.mp3',
      Offset(1004, 328),
      Offset(1180, 262),
      [Rect.fromLTWH(826, 300, 32, 56), Rect.fromLTWH(988, 300, 32, 56)],
    ),
    _Word(
      'قَدَمٌ',
      'Foot',
      'audio/vocab/qadam.mp3',
      Offset(870, 712),
      Offset(705, 700),
      [Rect.fromLTWH(818, 680, 95, 58), Rect.fromLTWH(930, 680, 100, 58)],
    ),
    _Word(
      'رِجْلٌ',
      'Leg',
      'audio/vocab/rijl.mp3',
      Offset(960, 620),
      Offset(1180, 640),
      [Rect.fromLTWH(845, 565, 160, 112)],
    ),
    _Word(
      'وَجْهٌ',
      'Face',
      'audio/vocab/wajh.mp3',
      Offset(955, 352),
      Offset(1180, 334),
      [Rect.fromLTWH(842, 262, 165, 110)],
    ),
  ]),
  LabelMakerSession.classroom: _Session(
    'Label Maker: Classroom',
    'room_classroom',
    [
      _Word(
        'كِتَابٌ',
        'Book',
        'audio/vocab/kitab.mp3',
        Offset(535, 290),
        Offset(535, 122),
        [Rect.fromLTWH(440, 145, 190, 300)],
      ),
      _Word(
        'قَلَمٌ',
        'Pen',
        'audio/vocab/qalam.mp3',
        Offset(1000, 768),
        Offset(1200, 760),
        [Rect.fromLTWH(895, 742, 220, 56)],
      ),
      _Word(
        'سَبُّورَةٌ',
        'Blackboard',
        'audio/vocab/sabburah.mp3',
        Offset(975, 230),
        Offset(975, 230),
        [Rect.fromLTWH(695, 120, 565, 230)],
      ),
      _Word(
        'كُرْسِيٌّ',
        'Chair',
        'audio/vocab/kursi.mp3',
        Offset(895, 505),
        Offset(895, 440),
        [
          Rect.fromLTWH(812, 470, 165, 72),
          Rect.fromLTWH(1305, 470, 165, 72),
          Rect.fromLTWH(790, 580, 235, 105),
          Rect.fromLTWH(1560, 580, 245, 105),
        ],
      ),
      _Word(
        'مَكْتَبٌ',
        'Desk',
        'audio/vocab/maktab.mp3',
        Offset(885, 420),
        Offset(1200, 400),
        [
          Rect.fromLTWH(672, 380, 430, 78),
          Rect.fromLTWH(650, 545, 495, 40),
          Rect.fromLTWH(1280, 545, 575, 45),
        ],
      ),
      _Word(
        'حَقِيبَةٌ',
        'Bag',
        'audio/vocab/haqiba.mp3',
        Offset(300, 510),
        Offset(300, 410),
        [Rect.fromLTWH(215, 435, 175, 155)],
      ),
      _Word(
        'وَرَقَةٌ',
        'Paper',
        'audio/vocab/waraqa.mp3',
        Offset(748, 758),
        Offset(560, 610),
        [Rect.fromLTWH(612, 698, 272, 122)],
      ),
      _Word(
        'مِمْحَاةٌ',
        'Eraser',
        'audio/vocab/mimha.mp3',
        Offset(1518, 740),
        Offset(1440, 650),
        [Rect.fromLTWH(1470, 712, 98, 56)],
      ),
      _Word(
        'مِسْطَرَةٌ',
        'Ruler',
        'audio/vocab/mistara.mp3',
        Offset(1650, 772),
        Offset(1760, 690),
        [Rect.fromLTWH(1525, 730, 245, 85)],
      ),
      // The spec's list stops at nine; the window is the tenth object painted
      // in the room.
      _Word(
        'نَافِذَةٌ',
        'Window',
        'audio/vocab/nafidha.mp3',
        Offset(170, 200),
        Offset(170, 440),
        [Rect.fromLTWH(60, 15, 225, 390)],
      ),
    ],
  ),
};

TextStyle _fredoka(double size, Color color) => TextStyle(
  fontFamily: 'Fredoka',
  fontWeight: FontWeight.w700,
  fontSize: size,
  color: color,
  height: 1.1,
);

TextStyle _arabic(double size) => TextStyle(
  fontFamily: 'ScheherazadeNew',
  fontWeight: FontWeight.w700,
  fontSize: size,
  color: _kNavy,
  height: 1.25,
);

/// Label Maker — hear an Arabic word, drag the speaker badge onto the
/// object it names. Landscape, one painted room per session.
class LabelMakerGame extends StatefulWidget {
  const LabelMakerGame({
    super.key,
    required this.session,
    required this.xp,
    required this.onComplete,
    this.onExit,
    this.random,
  });

  final LabelMakerSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  final VoidCallback? onExit;

  /// Word order source; tests pass a seeded one.
  final math.Random? random;

  @override
  State<LabelMakerGame> createState() => _LabelMakerGameState();
}

enum _Screen { start, howTo, play, congrats, summary }

class _LabelMakerGameState extends State<LabelMakerGame>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  /// The start screen's indoor breeze: one 12s loop, and every wave in it
  /// divides 12s evenly, so the plants never visibly restart.
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  _Session get _s => _kSessions[widget.session]!;

  _Screen _screen = _Screen.start;
  bool _playDown = false;

  /// Music button state: off silences the game's sounds.
  bool _sound = true;

  late final List<int> _order = List.generate(_s.words.length, (i) => i)
    ..shuffle(widget.random ?? math.Random());
  int _pos = 0;
  final List<int> _placed = [];
  int _errors = 0;
  int? _hover;
  bool _finished = false;

  /// Bumped on Play Again so a stale congrats timer can't skip ahead.
  int _round = 0;

  /// How to Play holds its Let's Go button back until the child has had
  /// time to read the steps.
  bool _howReady = false;

  /// Bumped on every visit to How to Play, so a wait timer from an earlier
  /// visit can't reveal Let's Go early.
  int _howN = 0;

  /// Pre-game countdown step: 0-2 show 3, 2, 1; 3 shows Go!; null once the
  /// round is live. Dragging is locked while it runs.
  int? _count;

  String? _toast;
  bool _toastGood = true;
  int _toastN = 0;
  int _shakeN = 0;
  int _pulseN = 0;
  bool _badgeDown = false;

  /// Word-wall word last tapped on the summary, and a counter that replays
  /// its hop on every tap.
  int? _heardI;
  int _heardN = 0;
  final List<Timer> _timers = [];

  final _stageKey = GlobalKey();

  int get _cur => _order[_pos];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final n in [
      'bg',
      'logo',
      'girl',
      'boy',
      'label_house',
      'label_head',
      'label_book',
      'play',
      'play_down',
      'btn_back',
      'btn_back_down',
      'btn_music',
      'btn_music_down',
      'btn_home',
      'btn_home_down',
      'btn_blank',
      'btn_blank_down',
      'board_title',
      'board_dock',
      'board_label',
      'btn_replay',
      'btn_replay_down',
      'btn_speaker',
      'btn_speaker_down',
      'star',
      'bg_plate',
      for (final pl in _kPlants) pl.asset,
      'girl_cheer',
      'boy_cheer',
      'girl_encourage',
      'boy_encourage',
      _s.bg,
    ]) {
      precacheImage(AssetImage('$_kA/$n.png'), context);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _c.dispose();
    _light.dispose();
    super.dispose();
  }

  void _after(int ms, VoidCallback fn) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(fn);
    }),
  );

  // ---- game logic ----

  void _say() => setState(_sayNow);

  void _sayNow() {
    // AUDIO PLUG POINT: play _s.words[_cur].audio here.
    _click();
    _pulseN++;
  }

  void _click() {
    // AUDIO PLUG POINT: background music would follow _sound too.
    if (_sound) SystemSound.play(SystemSoundType.click);
  }

  void _setBadgeDown(bool v) {
    if (_badgeDown != v) setState(() => _badgeDown = v);
  }

  void _showToast(String text, bool good) {
    final n = ++_toastN;
    _toast = text;
    _toastGood = good;
    _after(1100, () {
      if (_toastN == n) _toast = null;
    });
  }

  static double _dist(Rect r, Offset p) {
    final dx = math.max(0.0, math.max(r.left - p.dx, p.dx - r.right));
    final dy = math.max(0.0, math.max(r.top - p.dy, p.dy - r.bottom));
    return math.sqrt(dx * dx + dy * dy);
  }

  double _distTo(int i, Offset p) =>
      _s.words[i].rects.map((r) => _dist(r, p)).reduce(math.min);

  /// The unlabelled object under [p]: the smallest box it sits inside, else
  /// the nearest box within reach.
  int? _hitAt(Offset p) {
    int? best;
    var bestD = _kReach;
    var bestA = double.infinity;
    for (var i = 0; i < _s.words.length; i++) {
      if (_placed.contains(i)) continue;
      for (final r in _s.words[i].rects) {
        final d = _dist(r, p);
        final a = r.width * r.height;
        if (d < bestD || (d == 0 && bestD == 0 && a < bestA)) {
          best = i;
          bestD = d;
          bestA = a;
        }
      }
    }
    return best;
  }

  Offset _local(Offset global) =>
      (_stageKey.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);

  void _drop(Offset p) {
    final hit = _hitAt(p);
    setState(() {
      _hover = null;
      if (hit == _cur || _distTo(_cur, p) <= _kTolerance) {
        _placed.add(_cur);
        _click();
        HapticFeedback.mediumImpact();
        _showToast('Mumtaz!', true);
        if (_placed.length == _s.words.length) {
          _finished = true;
          _after(_kFinaleMs + 400, _toCongrats);
        } else {
          _pos++;
          _after(450, _sayNow);
        }
      } else if (hit != null) {
        _errors++;
        _shakeN++;
        HapticFeedback.heavyImpact();
        _showToast('Try again!', false);
      }
    });
  }

  void _toCongrats() {
    _screen = _Screen.congrats;
    _c.repeat();
    final round = _round;
    _timers.add(
      Timer(const Duration(milliseconds: 4200), () {
        if (mounted && _round == round) _toSummary();
      }),
    );
  }

  /// How to Play's Back: return to the start screen (not out of the lesson).
  void _toStart() {
    setState(() {
      _howN++;
      _howReady = false;
      _screen = _Screen.start;
    });
    _light.repeat();
  }

  void _toSummary() {
    if (_screen == _Screen.congrats) setState(() => _screen = _Screen.summary);
  }

  /// Play Again: same room, fresh shuffle, straight back into the game.
  void _replay() {
    setState(() {
      _round++;
      _order.shuffle(widget.random ?? math.Random());
      _pos = 0;
      _placed.clear();
      _errors = 0;
      _hover = null;
      _toast = null;
      _finished = false;
    });
    _c.stop();
    _startPlay();
  }

  /// Into the room behind a 3-2-1-Go! countdown, then the first word.
  void _startPlay() {
    final round = _round;
    setState(() {
      _screen = _Screen.play;
      _count = 0;
    });
    for (var i = 1; i <= 3; i++) {
      _after(1000 * i, () {
        if (_round == round) _count = i;
      });
    }
    _after(4000, () {
      if (_round != round) return;
      _count = null;
      _sayNow();
    });
  }

  int get _stars => _errors == 0 ? 3 : (_errors <= 3 ? 2 : 1);

  int get _accuracy =>
      (_s.words.length / (_s.words.length + _errors) * 100).round();

  void _finish() {
    if (_screen != _Screen.summary || _finished == false) return;
    _finished = false;
    final n = _s.words.length;
    widget.onComplete(widget.xp, n / (n + _errors) * 100, _errors);
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final bg = _screen == _Screen.start ? 'bg_plate' : _s.bg;
    return LayoutBuilder(
      builder: (context, box) {
        final scale = math.min(box.maxWidth / _kW, box.maxHeight / _kH);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('$_kA/$bg.png', fit: BoxFit.cover),
            FittedBox(
              child: SizedBox(
                key: _stageKey,
                width: _kW,
                height: _kH,
                child: switch (_screen) {
                  _Screen.start => AnimatedBuilder(
                    animation: Listenable.merge([_c, _light]),
                    builder: (context, _) => _buildStart(
                      _c.value * 2 * math.pi,
                      MediaQuery.of(context).disableAnimations
                          ? .2
                          : _light.value,
                    ),
                  ),
                  _Screen.howTo => AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => _buildHowTo(_c.value),
                  ),
                  _Screen.play => _buildPlay(scale),
                  _Screen.congrats => AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => _buildCongrats(_c.value),
                  ),
                  _Screen.summary => AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) =>
                        _buildSummary(_c.value * 2 * math.pi),
                  ),
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _at(double l, double t, double w, double h, Widget c) =>
      Positioned(left: l, top: t, width: w, height: h, child: c);

  Widget _img(String n) => Image.asset('$_kA/$n.png', fit: BoxFit.fill);

  /// One potted plant in the start room, bending in a slow indoor draught
  /// with the odd stronger breath; tips move most, leaves flutter out of
  /// step. [light] runs 0..1 over the 12s loop.
  Widget _plant(_Plant pl, double light) {
    final t = light * 12;
    double wave(double period, double ph) =>
        math.sin(2 * math.pi * t / period + ph);
    final gust = math.pow(.5 + .5 * wave(12, pl.phase * 2), 3).toDouble();
    final sway = .6 * wave(6, pl.phase) + .3 * wave(2.4, pl.phase * 1.7);
    return _at(
      pl.rect.left,
      pl.rect.top,
      pl.rect.width,
      pl.rect.height,
      IgnorePointer(
        child: BendSprite(
          asset: '$_kA/${pl.asset}.png',
          bend: (sway * (1 + gust) + .7 * gust) * pl.dir * pl.amount,
          flutter: .012 * (.4 + gust),
          t: t + pl.phase,
          hang: pl.hang,
        ),
      ),
    );
  }

  /// Grounds a standing mascot on the rug: its own silhouette laid flat and
  /// thrown down-right (away from the window sun), plus a dark contact
  /// shadow right under the feet.
  List<Widget> _groundShadow(
    double l,
    double t,
    double w,
    double h,
    String img,
  ) => [
    _at(
      l,
      t,
      w,
      h,
      IgnorePointer(
        child: Transform(
          alignment: Alignment.bottomCenter,
          // Flip and flatten onto the floor, then lean it with the light.
          transform: Matrix4.identity()
            ..setEntry(0, 1, 1.15)
            ..multiply(Matrix4.diagonal3Values(1, -.22, 1)),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 5),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x780B1230),
                BlendMode.srcIn,
              ),
              child: _img(img),
            ),
          ),
        ),
      ),
    ),
    // Contact shadow: a soft pool, then a darker core right under the feet.
    Positioned(
      left: l + w * .14,
      top: t + h - 22,
      width: w * .72,
      height: 36,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x8C0B1230),
              borderRadius: BorderRadius.all(Radius.elliptical(w * .36, 18)),
            ),
          ),
        ),
      ),
    ),
    Positioned(
      left: l + w * .24,
      top: t + h - 14,
      width: w * .52,
      height: 20,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 2.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xA60B1230),
              borderRadius: BorderRadius.all(Radius.elliptical(w * .26, 10)),
            ),
          ),
        ),
      ),
    ),
  ];

  Widget _buildStart(double t, double light) {
    Widget bob(double phase, double amp, Widget c) => Transform.translate(
      offset: Offset(0, amp * math.sin(t + phase)),
      child: c,
    );
    void down(bool v) => setState(() => _playDown = v);

    return Stack(
      children: [
        // The room with its plants painted out; the plants are drawn back
        // on top as sprites that sway. Inside the stage so they line up.
        Positioned.fill(child: _img('bg_plate')),
        for (final pl in _kPlants.where((p) => !p.front)) _plant(pl, light),
        _at(118, 128, 262, 142, bob(0, 6, _img('label_house'))),
        _at(1430, 96, 232, 112, bob(2, 6, _img('label_head'))),
        _at(1590, 356, 236, 114, bob(4, 6, _img('label_book'))),
        ..._groundShadow(290, 255, 358, 480, 'girl'),
        ..._groundShadow(1250, 240, 297, 500, 'boy'),
        _at(290, 255, 358, 480, _img('girl')),
        _at(1250, 240, 297, 500, _img('boy')),
        for (final pl in _kPlants.where((p) => p.front)) _plant(pl, light),
        _at(
          615,
          88,
          640,
          454,
          Stack(
            fit: StackFit.expand,
            children: [
              _img('logo'),
              Positioned(
                left: 80,
                right: 80,
                top: 385,
                bottom: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Learn Arabic Words',
                    style: _fredoka(38, _kNavy),
                  ),
                ),
              ),
            ],
          ),
        ),
        _at(
          705,
          585,
          460,
          163,
          Transform.scale(
            scale: _playDown ? .97 : 1 + .025 * math.sin(t * 2),
            child: GestureDetector(
              key: const ValueKey('lm-play'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => down(true),
              onTapUp: (_) => down(false),
              onTapCancel: () => down(false),
              onTap: () {
                _light.stop();
                setState(() {
                  _screen = _Screen.howTo;
                  _howReady = false;
                });
                final n = ++_howN;
                _after(_kHowToWaitMs, () {
                  if (_howN == n) _howReady = true;
                });
              },
              child: _img(_playDown ? 'play_down' : 'play'),
            ),
          ),
        ),
        ..._topButtons(),
      ],
    );
  }

  /// Three illustrated steps over the session's own room, then Let's Go.
  /// [u] runs 0..1 every loop and drives the drag demo.
  Widget _buildHowTo(double u) {
    final word = _s.words.first;
    final wave = math.sin(u * 2 * math.pi);

    // Step 2: the badge glides in from the corner onto the object, then rests.
    final e = Curves.easeInOut.transform((u / .6).clamp(0.0, 1.0));
    final at = Offset.lerp(
      const Offset(70, 205),
      const Offset(_kPeekW / 2, _kPeekH / 2),
      e,
    )!;

    Widget small(Widget c, double w, double h) => SizedBox(
      width: w,
      height: h,
      child: FittedBox(child: c),
    );

    Widget card(int n, String caption, Widget art) => Container(
      width: 500,
      height: 470,
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 22),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: _kGold, width: 8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(width: _kPeekW, height: _kPeekH, child: art),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF08A24),
                ),
                child: Text('$n', style: _fredoka(34, Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 100,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(caption, style: _fredoka(32, _kNavy)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('$_kA/${_s.bg}.png', fit: BoxFit.fill),
        ),
        Positioned.fill(child: Container(color: const Color(0xB30E1A40))),
        _at(
          655,
          34,
          560,
          104,
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.circular(52),
              border: Border.all(color: _kGold, width: 7),
            ),
            child: Text('How to Play', style: _fredoka(60, _kNavy)),
          ),
        ),
        _at(
          125,
          170,
          1620,
          470,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              card(
                1,
                'Tap Replay to\nhear the Arabic word',
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('$_kA/btn_replay.png', width: 84, height: 84),
                      const SizedBox(width: 14),
                      Transform.scale(
                        scale: 1 + .06 * wave.abs(),
                        child: small(_Badge(word: word), 250, 88),
                      ),
                    ],
                  ),
                ),
              ),
              card(
                2,
                'Drag the speaker onto\nthe right object',
                _RoomPeek(
                  bg: _s.bg,
                  centre: word.point,
                  children: [
                    Positioned(
                      left: at.dx - 90,
                      top: at.dy - 32,
                      child: small(_Badge(word: word), 180, 64),
                    ),
                    Positioned(
                      left: at.dx + 10,
                      top: at.dy + 6,
                      child: const Icon(
                        Icons.touch_app_rounded,
                        size: 64,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
              ),
              card(
                3,
                'Get it right and it\nbecomes a label!',
                _RoomPeek(
                  bg: _s.bg,
                  centre: word.point,
                  children: [
                    Positioned(
                      left: _kPeekW / 2 - 9,
                      top: _kPeekH / 2 - 9,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _kGold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _kPeekW / 2 - 80,
                      top: 18,
                      width: 160,
                      height: 76,
                      child: Transform.scale(
                        scale: 1 + .05 * wave,
                        child: _Label(word),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _at(
          735,
          668,
          400,
          138,
          _howReady
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutQuart,
                  builder: (context, v, c) => Opacity(
                    opacity: v,
                    child: Transform.scale(
                      scale: (.7 + .3 * v) * (1 + .03 * wave),
                      child: c,
                    ),
                  ),
                  child: _ImgBtn(
                    key: const ValueKey('lm-go'),
                    up: 'btn_blank',
                    down: 'btn_blank_down',
                    onTap: () {
                      _c.stop();
                      _startPlay();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 8),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _outlined(
                            "Let's Go!",
                            _fredoka(60, Colors.white),
                            const Color(0xFF0E4A10),
                            10,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: SizedBox(
                    width: 380,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Get ready...', style: _fredoka(30, Colors.white)),
                        const SizedBox(height: 12),
                        Container(
                          height: 22,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _kCream,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: _kGold, width: 3),
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(
                              milliseconds: _kHowToWaitMs,
                            ),
                            builder: (context, v, _) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: v,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CB82A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        ..._topButtons(onBack: _toStart),
      ],
    );
  }

  /// Back (top-left) and Music (top-right), shared by every screen.
  List<Widget> _topButtons({bool back = true, VoidCallback? onBack}) => [
    if (back && (onBack != null || widget.onExit != null))
      _at(
        24,
        20,
        _kBtnW,
        _kBtnH,
        _ImgBtn(
          key: const ValueKey('lm-back'),
          up: 'btn_back',
          down: 'btn_back_down',
          onTap: onBack ?? widget.onExit!,
        ),
      ),
    _at(
      _kW - 24 - _kBtnW,
      20,
      _kBtnW,
      _kBtnH,
      _ImgBtn(
        key: const ValueKey('lm-music'),
        up: 'btn_music',
        down: 'btn_music_down',
        off: !_sound,
        onTap: () => setState(() => _sound = !_sound),
      ),
    ),
  ];

  Widget _buildPlay(double scale) {
    final words = _s.words;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('$_kA/${_s.bg}.png', fit: BoxFit.fill),
        ),
        // One drop zone over the whole room: the drop point decides which
        // object was meant (see _hitAt), so tiny parts stay reachable.
        Positioned.fill(
          child: DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onMove: (d) {
              final h = _hitAt(_local(d.offset));
              if (h != _hover) setState(() => _hover = h);
            },
            onLeave: (_) => setState(() => _hover = null),
            onAcceptWithDetails: (d) => _drop(_local(d.offset)),
            builder: (context, _, _) => const SizedBox.expand(),
          ),
        ),
        if (_finished)
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('finale$_round'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: _kFinaleMs),
                builder: (context, v, _) {
                  final ms = v * _kFinaleMs;
                  return Stack(
                    children: [
                      for (var k = 0; k < _placed.length; k++)
                        for (final r in words[_placed[k]].rects)
                          ..._glow(r, ms - 250 - 160.0 * k, ms),
                    ],
                  );
                },
              ),
            ),
          ),
        if (_hover != null)
          for (final r in words[_hover!].rects)
            Positioned.fromRect(
              rect: r.inflate(6),
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99FFE27A), blurRadius: 18),
                    ],
                  ),
                ),
              ),
            ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PinPainter([
                for (final i in _placed) (words[i].point, words[i].label),
              ]),
            ),
          ),
        ),
        for (final i in _placed)
          Positioned(
            left: words[i].label.dx - 90,
            top: words[i].label.dy - 42,
            width: 180,
            height: 84,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                builder: (context, v, c) => Transform.scale(scale: v, child: c),
                child: Center(child: _Label(words[i])),
              ),
            ),
          ),
        _at(
          _kBtnW + 40,
          10,
          480,
          96,
          IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _img('board_title'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 12, 40, 16),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_s.title, style: _fredoka(36, _kNavy)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ..._topButtons(),
        _buildDock(scale),
        if (_count != null) _buildCountdown(),
        if (_toast != null)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_toastN),
                  tween: Tween(begin: .4, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  builder: (context, v, c) =>
                      Transform.scale(scale: v, child: c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _toastGood
                          ? const Color(0xFF2FA84F)
                          : const Color(0xFFF08A24),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white, width: 5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(_toast!, style: _fredoka(48, Colors.white)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// One object's finale light: a warm halo that fades up [since] ms
  /// after its turn, then breathes with the others, plus a star sparkle.
  List<Widget> _glow(Rect r, double since, double ms) {
    if (since <= 0) return const [];
    final appear = Curves.easeOutQuart.transform((since / 350).clamp(0.0, 1.0));
    final pulse = .72 + .28 * math.sin(ms / 1000 * 2 * math.pi * 1.2);
    return [
      Positioned.fromRect(
        rect: r.inflate(8 + 8 * appear),
        child: Opacity(
          opacity: appear * pulse,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x33FFF3B0),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFFFF3B0), width: 5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xDDFFD23F),
                  blurRadius: 34,
                  spreadRadius: 8,
                ),
                BoxShadow(color: Color(0x99FFFFFF), blurRadius: 12),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        left: r.right - 26,
        top: r.top - 30,
        width: 52,
        height: 52,
        child: Transform.rotate(
          angle: .4 * (1 - appear) + .12 * math.sin(ms / 400),
          child: Transform.scale(
            scale: appear,
            child: Image.asset('$_kA/star.png', fit: BoxFit.contain),
          ),
        ),
      ),
    ];
  }

  /// 3, 2, 1, Go! over the dimmed room before the first word.
  Widget _buildCountdown() {
    final go = _count == 3;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: const Color(0x800E1A40),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: go ? 0 : 1,
                child: _outlined(
                  'Get Ready!',
                  _fredoka(64, Colors.white),
                  _kNavy,
                  12,
                ),
              ),
              TweenAnimationBuilder<double>(
                key: ValueKey('count$_count'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutQuart,
                builder: (context, v, c) => Opacity(
                  opacity: v,
                  child: Transform.scale(scale: 1.7 - .7 * v, child: c),
                ),
                child: _outlined(
                  const ['3', '2', '1', 'Go!'][_count!],
                  _fredoka(
                    230,
                    go ? const Color(0xFF7BE04A) : const Color(0xFFFFD23F),
                  ),
                  go ? const Color(0xFF0E4A10) : const Color(0xFF8A3B00),
                  22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDock(double scale) {
    final n = _s.words.length;
    final done = _placed.length == n;
    final word = _s.words[_cur];
    final badge = _Badge(word: word, down: _badgeDown);

    return _at(
      20,
      690,
      590,
      145,
      Stack(
        fit: StackFit.expand,
        children: [
          _img('board_dock'),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 16, 26, 22),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: _ImgBtn(
                    key: const ValueKey('lm-replay'),
                    up: 'btn_replay',
                    down: 'btn_replay_down',
                    onTap: done || _count != null ? () {} : _say,
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: _Badge.w,
                  height: _Badge.h,
                  child: done
                      ? null
                      : _Shake(
                          key: ValueKey('shake$_shakeN'),
                          child: _Pulse(
                            key: ValueKey('pulse$_pulseN'),
                            child: Draggable<int>(
                              key: ValueKey('lm-badge-${word.en}'),
                              data: _cur,
                              maxSimultaneousDrags: _count == null ? 1 : 0,
                              dragAnchorStrategy: pointerDragAnchorStrategy,
                              feedback: Material(
                                type: MaterialType.transparency,
                                child: FractionalTranslation(
                                  translation: const Offset(-.5, -.5),
                                  child: SizedBox(
                                    width: _Badge.w * scale * 1.08,
                                    height: _Badge.h * scale * 1.08,
                                    child: FittedBox(
                                      child: _Badge(word: word, down: true),
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: .3,
                                child: badge,
                              ),
                              onDragEnd: (_) {
                                if (_hover != null) {
                                  setState(() => _hover = null);
                                }
                              },
                              child: Listener(
                                onPointerDown: (_) => _setBadgeDown(true),
                                onPointerUp: (_) => _setBadgeDown(false),
                                onPointerCancel: (_) => _setBadgeDown(false),
                                child: badge,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 4,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3D27A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${math.min(_placed.length + 1, n)}/$n',
                      style: _fredoka(40, _kNavy),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Big "Mumtaz!" burst over the finished room: rays, confetti and the
  /// earned stars popping in one by one. Tap (or wait) for the summary.
  Widget _buildCongrats(double u) {
    final n = _s.words.length;
    return GestureDetector(
      key: const ValueKey('lm-congrats'),
      behavior: HitTestBehavior.opaque,
      onTap: _toSummary,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_kA/${_s.bg}.png', fit: BoxFit.fill),
          ),
          Positioned.fill(child: Container(color: const Color(0xA60E1A40))),
          Positioned.fill(child: CustomPaint(painter: _RaysPainter(u))),
          Positioned.fill(child: CustomPaint(painter: _ConfettiPainter(u))),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 2200),
              builder: (context, t, _) {
                double stage(double a, double b, Curve c) =>
                    c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
                final title = stage(0, .35, Curves.elasticOut);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: title,
                      child: _outlined(
                        'Mumtaz!',
                        _fredoka(170, const Color(0xFFFFD23F)),
                        const Color(0xFF8A3B00),
                        18,
                      ),
                    ),
                    Opacity(
                      opacity: stage(.2, .4, Curves.easeOut),
                      child: _outlined(
                        'You labelled all $n words!',
                        _fredoka(58, Colors.white),
                        _kNavy,
                        10,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Transform.translate(
                            offset: Offset(0, i == 1 ? -26 : 0),
                            child: Transform.scale(
                              scale: stage(
                                .4 + .15 * i,
                                .7 + .15 * i,
                                Curves.elasticOut,
                              ),
                              child: _Star(on: i < _stars, size: 150),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Opacity(
                      opacity:
                          stage(.85, 1, Curves.easeOut) *
                          (.6 + .4 * math.sin(u * 4 * math.pi).abs()),
                      child: Text(
                        'Tap to continue',
                        style: _fredoka(34, Colors.white),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          ..._topButtons(back: false),
        ],
      ),
    );
  }

  String get _topic => switch (widget.session) {
    LabelMakerSession.home => 'home',
    LabelMakerSession.body => 'body',
    LabelMakerSession.classroom => 'classroom',
  };

  /// What the girl says, from how the round went.
  String get _cheer => switch (_stars) {
    3 => 'Perfect!\nNot a single mistake!',
    2 => 'Great job!\nOnly $_errors little ${_errors == 1 ? 'slip' : 'slips'}.',
    _ => 'Good try!\nPlay again for more stars!',
  };

  void _hear(int i) {
    // AUDIO PLUG POINT: play _s.words[i].audio here.
    _click();
    setState(() {
      _heardI = i;
      _heardN++;
    });
  }

  /// The ending screen: a star arc over the session's title plaque, the
  /// round's words pinned to a word wall (tap one to hear it again), the
  /// girl cheering the result from a speech bubble, the boy waving, and
  /// Play Again / Home.
  Widget _buildSummary(double t) {
    final words = _s.words;
    final still = MediaQuery.of(context).disableAnimations;
    if (still) t = 0;

    // Mascots cheer a good round (2-3 stars) and encourage a hard one.
    final high = _stars >= 2;
    final mood = high ? 'cheer' : 'encourage';
    const mh = 460.0;
    final gw = mh * (high ? .644 : .504);
    final bw = mh * (high ? .628 : .514);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: still ? 0 : 1900),
      builder: (context, e, _) {
        // Entrance stages, each easing out on its own slice of the timeline.
        double at(double a, double b) =>
            Curves.easeOutQuart.transform(((e - a) / (b - a)).clamp(0.0, 1.0));
        Widget rise(double a, double b, Widget c, {double dy = 40}) {
          final v = at(a, b);
          return Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, dy * (1 - v)),
              child: c,
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('$_kA/${_s.bg}.png', fit: BoxFit.fill),
            ),
            // Vignette: the room stays readable at the edges, darkest behind
            // the wall so the labels carry the screen.
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.1),
                    radius: 1.1,
                    colors: [Color(0xCC0E1A40), Color(0x990E1A40)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: .6,
                child: CustomPaint(
                  painter: _RaysPainter(t / (2 * math.pi), centre: .12),
                ),
              ),
            ),
            if (!still)
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConfettiPainter(t / (2 * math.pi), sparse: true),
                ),
              ),

            // Mascots, stepping in from the sides.
            _at(
              high ? 60 : 90,
              320,
              gw,
              mh,
              Opacity(opacity: at(.15, .45), child: _img('girl_$mood')),
            ),
            _at(
              (high ? 1810 : 1780) - bw,
              320,
              bw,
              mh,
              Opacity(opacity: at(.2, .5), child: _img('boy_$mood')),
            ),

            // The girl's speech bubble.
            _at(
              28,
              118,
              404,
              176,
              Opacity(
                opacity: at(.45, .65),
                child: Transform.scale(
                  scale: .85 + .15 * at(.45, .65),
                  alignment: const Alignment(-.3, 1),
                  child: CustomPaint(
                    painter: _BubblePainter(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 16, 26, 46),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _cheer,
                            textAlign: TextAlign.center,
                            style: _fredoka(34, _kNavy),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Star arc: centre star raised and bigger.
            for (var i = 0; i < 3; i++)
              _at(
                i == 1 ? 865 : (i == 0 ? 735 : 1025),
                i == 1 ? 8 : 40,
                i == 1 ? 140 : 110,
                i == 1 ? 140 : 110,
                Transform.rotate(
                  angle:
                      (i - 1) * .22 +
                      (i < _stars ? .05 * math.sin(t * 2 + i) : 0),
                  child: Transform.scale(
                    scale: at(.3 + .1 * i, .55 + .1 * i),
                    child: _Star(on: i < _stars, size: i == 1 ? 140 : 110),
                  ),
                ),
              ),

            // Title plaque.
            _at(
              655,
              146,
              560,
              112,
              rise(
                .2,
                .45,
                Stack(
                  fit: StackFit.expand,
                  children: [
                    _img('board_title'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(44, 14, 44, 20),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'You learned ${words.length} $_topic words!',
                            style: _fredoka(40, _kNavy),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Word wall.
            _at(
              440,
              272,
              990,
              350,
              rise(
                .3,
                .6,
                Container(
                  padding: const EdgeInsets.fromLTRB(30, 18, 30, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6DE),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: _kGold, width: 8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 26,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Words You Learned',
                              style: _fredoka(36, const Color(0xFF8A4B08)),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.touch_app_rounded,
                              color: Color(0xFFB07A2A),
                              size: 30,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to hear',
                              style: _fredoka(24, const Color(0xFF9A6A1E)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          runAlignment: WrapAlignment.center,
                          spacing: 18,
                          runSpacing: 20,
                          children: [
                            for (var i = 0; i < words.length; i++)
                              _pinned(
                                i,
                                words[i],
                                at(.45 + .04 * i, .7 + .04 * i),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Score strip: one line, three facts.
            _at(
              585,
              636,
              700,
              64,
              rise(
                .55,
                .8,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xE60E1A40),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: const Color(0x66FFD23F),
                      width: 3,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _fact(
                          Icons.sell_rounded,
                          const Color(0xFFFFB35C),
                          '${words.length}',
                          'words',
                        ),
                        _factDivider(),
                        _fact(
                          Icons.check_circle_rounded,
                          const Color(0xFF6BD23A),
                          '$_accuracy%',
                          'correct',
                        ),
                        _factDivider(),
                        _fact(
                          Icons.bolt_rounded,
                          const Color(0xFFFFD23F),
                          '+${widget.xp}',
                          'XP',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Play Again / Home.
            _at(
              580,
              712,
              340,
              116,
              rise(
                .65,
                .9,
                _ImgBtn(
                  key: const ValueKey('lm-again'),
                  up: 'btn_blank',
                  down: 'btn_blank_down',
                  onTap: _replay,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(34, 0, 34, 8),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _outlined(
                          'Play Again',
                          _fredoka(56, Colors.white),
                          const Color(0xFF0E4A10),
                          10,
                        ),
                      ),
                    ),
                  ),
                ),
                dy: 24,
              ),
            ),
            _at(
              950,
              712,
              340,
              116,
              rise(
                .7,
                .95,
                _ImgBtn(
                  key: const ValueKey('lm-home'),
                  up: 'btn_home',
                  down: 'btn_home_down',
                  onTap: _finish,
                ),
                dy: 24,
              ),
            ),
            ..._topButtons(back: false),
          ],
        );
      },
    );
  }

  /// One word on the wall: tilted a little either way like a pinned sticker,
  /// with a pin on top. Tapping it says the word and gives it a hop.
  Widget _pinned(int i, _Word w, double v) {
    final tilt = (i.isEven ? -1 : 1) * (.025 + .015 * (i % 3));
    return Opacity(
      opacity: v,
      child: Transform.scale(
        scale: .7 + .3 * v,
        child: GestureDetector(
          key: ValueKey('lm-wall-$i'),
          onTap: () => _hear(i),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_heardI == i ? 'heard$_heardN' : 'rest$i'),
            tween: Tween(begin: _heardI == i ? 0 : 1, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutQuart,
            builder: (context, h, c) => Transform.translate(
              offset: Offset(0, -16 * math.sin(h * math.pi)),
              child: c,
            ),
            child: Transform.rotate(
              angle: tilt,
              child: SizedBox(
                width: 164,
                height: 90,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 78,
                      child: _Label(w),
                    ),
                    Positioned(
                      left: 72,
                      top: 0,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-.3, -.4),
                            colors: [Color(0xFFFF8A7A), Color(0xFFC62E24)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fact(IconData icon, Color color, String value, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 36),
      const SizedBox(width: 10),
      Text(value, style: _fredoka(36, Colors.white)),
      const SizedBox(width: 8),
      Text(label, style: _fredoka(26, const Color(0xFFD6DDF5))),
    ],
  );

  Widget _factDivider() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 28),
    width: 3,
    height: 34,
    decoration: BoxDecoration(
      color: const Color(0x55FFFFFF),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// Text with a thick rounded outline, the game-title look.
Widget _outlined(String text, TextStyle style, Color stroke, double width) =>
    Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: style.fontFamily,
            fontWeight: style.fontWeight,
            fontSize: style.fontSize,
            height: style.height,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(text, style: style),
      ],
    );

/// A gold star with a darker rim, or a pale empty slot.
class _Star extends StatelessWidget {
  const _Star({required this.on, required this.size});

  final bool on;
  final double size;

  /// Greyscale, for a star not earned.
  static const _grey = ColorFilter.matrix([
    .2126, .7152, .0722, 0, 0, //
    .2126, .7152, .0722, 0, 0,
    .2126, .7152, .0722, 0, 0,
    0, 0, 0, .45, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final star = Image.asset(
      '$_kA/star.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    return on ? star : ColorFiltered(colorFilter: _grey, child: star);
  }
}

/// A plant cut out of the start room (see `bg_plate.png`).
class _Plant {
  const _Plant(
    this.asset,
    this.rect,
    this.phase, {
    this.amount = .035,
    this.dir = 1,
    this.hang = false,
    this.front = false,
  });

  final String asset;

  /// Where the sprite sits in the 1870x841 stage.
  final Rect rect;
  final double phase;

  /// Lean at the tips, as a share of the sprite's height.
  final double amount;

  /// Which way the draught pushes it (+1 right, -1 left).
  final double dir;
  final bool hang;

  /// Nearest the viewer: drawn over the mascots.
  final bool front;
}

const _kPlants = [
  _Plant('plant_table', Rect.fromLTWH(176, 338, 116, 90), 0, amount: .05),
  _Plant('plant_floor', Rect.fromLTWH(1360, 334, 184, 166), 1.1, dir: -1),
  _Plant('plant_top', Rect.fromLTWH(1535, 6, 134, 96), 2.3, amount: .045),
  _Plant(
    'plant_vine',
    Rect.fromLTWH(1464, 58, 84, 186),
    .6,
    amount: .06,
    hang: true,
  ),
  _Plant('plant_shelf', Rect.fromLTWH(1583, 106, 88, 54), 3.4, amount: .05),
  _Plant('plant_cabinet', Rect.fromLTWH(1740, 206, 130, 118), 4.2, dir: -1),
  _Plant('plant_corner', Rect.fromLTWH(1726, 418, 144, 120), 5.1, dir: -1),
  _Plant(
    'plant_front',
    Rect.fromLTWH(0, 550, 298, 291),
    2.8,
    amount: .03,
    front: true,
  ),
];

/// Slowly turning light rays behind the congrats title.
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.u, {this.centre = .42});

  final double u;

  /// Vertical centre of the burst, as a fraction of the height.
  final double centre;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * centre);
    final r = size.width * .7;
    final paint = Paint()..color = const Color(0x22FFE27A);
    const n = 18;
    for (var i = 0; i < n; i++) {
      final a = u * 2 * math.pi / 6 + i * 2 * math.pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a), c.dy + r * math.sin(a))
        ..lineTo(
          c.dx + r * math.cos(a + math.pi / n),
          c.dy + r * math.sin(a + math.pi / n),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(
      c,
      260,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x66FFE27A), Color(0x00FFE27A)],
        ).createShader(Rect.fromCircle(center: c, radius: 260)),
    );
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.u != u;
}

/// White speech bubble with its tail pointing down-left at the girl.
class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tail = 34.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - tail),
      const Radius.circular(40),
    );
    final path = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      Path()
        ..moveTo(size.width * .30, size.height - tail - 20)
        ..lineTo(size.width * .22, size.height)
        ..lineTo(size.width * .46, size.height - tail - 20)
        ..close(),
    );
    canvas.drawShadow(path, const Color(0xFF000000), 10, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..color = _kGold,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => false;
}

/// Falling paper confetti; [u] runs 0..1 per loop.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.u, {this.sparse = false});

  final double u;
  final bool sparse;

  static const _colors = [
    Color(0xFFFFD23F),
    Color(0xFFF08A24),
    Color(0xFF2FA84F),
    Color(0xFF4F8DF5),
    Color(0xFFE0453A),
    Color(0xFFFF7EB6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final count = sparse ? 36 : 90;
    for (var i = 0; i < count; i++) {
      final x0 = rng.nextDouble() * size.width;
      final speed = 1 + rng.nextInt(2);
      final phase = rng.nextDouble();
      final w = 12 + rng.nextDouble() * 12;
      final y = ((u * speed + phase) % 1) * (size.height + 60) - 30;
      final x = x0 + 26 * math.sin((u * speed + phase) * 2 * math.pi * 2);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate((u * speed + phase) * 2 * math.pi * 3);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * .55),
        Paint()..color = _colors[i % _colors.length],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.u != u;
}

const _kBtnW = 210.0;
const _kBtnH = 75.0;

/// A painted button that swaps to its pressed art while held. [off] greys
/// it out and marks it muted (the Music toggle).
class _ImgBtn extends StatefulWidget {
  const _ImgBtn({
    super.key,
    required this.up,
    required this.down,
    required this.onTap,
    this.off = false,
    this.child,
  });

  final String up;
  final String down;
  final VoidCallback onTap;
  final bool off;

  /// Drawn over the art, for blank buttons that carry their own label.
  final Widget? child;

  @override
  State<_ImgBtn> createState() => _ImgBtnState();
}

class _ImgBtnState extends State<_ImgBtn> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap,
    child: Transform.scale(
      scale: _down ? .96 : 1,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: widget.off ? .55 : 1,
            child: Image.asset(
              '$_kA/${_down ? widget.down : widget.up}.png',
              fit: BoxFit.fill,
            ),
          ),
          ?widget.child,
          if (widget.off)
            Positioned(
              right: -8,
              top: -10,
              width: 42,
              height: 42,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE0453A),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The draggable speaker badge in the dock: the orange speaker and the
/// word it says, dragged together.
class _Badge extends StatelessWidget {
  const _Badge({required this.word, this.down = false});

  static const w = 300.0;
  static const h = 88.0;

  final _Word word;

  /// Shows the speaker's pressed art (held or mid-drag).
  final bool down;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: w,
    height: h,
    child: Row(
      children: [
        Image.asset(
          '$_kA/${down ? 'btn_speaker_down' : 'btn_speaker'}.png',
          width: 84,
          height: 84,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _kGold, width: 5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                word.ar,
                textDirection: TextDirection.rtl,
                style: _arabic(46),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

const _kPeekW = 420.0;
const _kPeekH = 250.0;

/// A rounded window onto the session's room, centred on [centre] (stage
/// px), with [children] laid over it in the window's own coordinates.
class _RoomPeek extends StatelessWidget {
  const _RoomPeek({
    required this.bg,
    required this.centre,
    required this.children,
  });

  final String bg;
  final Offset centre;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Stack(
      children: [
        Positioned(
          left: _kPeekW / 2 - centre.dx,
          top: _kPeekH / 2 - centre.dy,
          width: _kW,
          height: _kH,
          child: Image.asset('$_kA/$bg.png', fit: BoxFit.fill),
        ),
        ...children,
      ],
    ),
  );
}

/// The clean white label a correct drop turns the badge into.
class _Label extends StatelessWidget {
  const _Label(this.word);

  final _Word word;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 2.12,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/board_label.png', fit: BoxFit.fill),
        FractionallySizedBox(
          widthFactor: .8,
          heightFactor: .74,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  word.ar,
                  textDirection: TextDirection.rtl,
                  style: _arabic(40),
                ),
                Text(word.en, style: _fredoka(22, const Color(0xFF5E4630))),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Pin lines from each placed label to its object.
class _PinPainter extends CustomPainter {
  _PinPainter(this.pins);

  final List<(Offset, Offset)> pins;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = _kGold;
    final ring = Paint()..color = Colors.white;
    for (final (point, label) in pins) {
      canvas.drawLine(label, point, line);
      canvas.drawCircle(point, 11, ring);
      canvas.drawCircle(point, 7, dot);
    }
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.pins.length != pins.length;
}

/// Horizontal wobble once, played when a drop lands on the wrong object.
class _Shake extends StatelessWidget {
  const _Shake({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 500),
    builder: (context, t, c) => Transform.translate(
      offset: Offset(14 * math.sin(t * 4 * math.pi) * (1 - t), 0),
      child: c,
    ),
    child: child,
  );
}

/// A quick grow-and-settle, played each time the word is "said".
class _Pulse extends StatelessWidget {
  const _Pulse({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 600),
    builder: (context, t, c) =>
        Transform.scale(scale: 1 + .12 * math.sin(t * math.pi), child: c),
    child: child,
  );
}
