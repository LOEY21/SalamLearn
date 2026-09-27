import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

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
      Offset(670, 700),
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
        Offset(560, 680),
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
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

  String? _toast;
  bool _toastGood = true;
  int _toastN = 0;
  int _shakeN = 0;
  int _pulseN = 0;
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
          _after(1400, _toCongrats);
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
      _screen = _Screen.play;
    });
    _c.stop();
    _after(500, _sayNow);
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
    final bg = _screen == _Screen.start ? 'bg' : _s.bg;
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
                    animation: _c,
                    builder: (context, _) =>
                        _buildStart(_c.value * 2 * math.pi),
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

  Widget _buildStart(double t) {
    Widget bob(double phase, double amp, Widget c) => Transform.translate(
      offset: Offset(0, amp * math.sin(t + phase)),
      child: c,
    );
    Widget sway(double phase, Widget c) => Transform.rotate(
      angle: .02 * math.sin(t + phase),
      alignment: Alignment.bottomCenter,
      child: c,
    );
    void down(bool v) => setState(() => _playDown = v);

    return Stack(
      children: [
        _at(118, 128, 262, 142, bob(0, 6, _img('label_house'))),
        _at(1430, 96, 232, 112, bob(2, 6, _img('label_head'))),
        _at(1590, 356, 236, 114, bob(4, 6, _img('label_book'))),
        _at(290, 255, 358, 480, sway(0, _img('girl'))),
        _at(1250, 240, 297, 500, sway(math.pi, _img('boy'))),
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
              onTap: () => setState(() => _screen = _Screen.howTo),
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
                      Container(
                        width: 78,
                        height: 78,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF4F8DF5), Color(0xFF2456C8)],
                          ),
                        ),
                        child: const Icon(
                          Icons.replay_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
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
          Transform.scale(
            scale: 1 + .03 * wave,
            child: _ImgBtn(
              key: const ValueKey('lm-go'),
              up: 'btn_blank',
              down: 'btn_blank_down',
              onTap: () {
                _c.stop();
                setState(() => _screen = _Screen.play);
                _after(500, _sayNow);
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
          ),
        ),
        ..._topButtons(),
      ],
    );
  }

  /// Back (top-left) and Music (top-right), shared by every screen.
  List<Widget> _topButtons({bool back = true}) => [
    if (back && widget.onExit != null)
      _at(
        24,
        20,
        _kBtnW,
        _kBtnH,
        _ImgBtn(
          key: const ValueKey('lm-back'),
          up: 'btn_back',
          down: 'btn_back_down',
          onTap: widget.onExit!,
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
                child: _Label(words[i]),
              ),
            ),
          ),
        _at(
          _kBtnW + 44,
          27,
          470,
          62,
          IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.circular(31),
                border: Border.all(color: _kGold, width: 4),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_s.title, style: _fredoka(30, _kNavy)),
              ),
            ),
          ),
        ),
        ..._topButtons(),
        _buildDock(scale),
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

  Widget _buildDock(double scale) {
    final n = _s.words.length;
    final done = _placed.length == n;
    final word = _s.words[_cur];
    final badge = _Badge(word: word);

    return _at(
      24,
      704,
      470,
      120,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: _kGold, width: 5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              key: const ValueKey('lm-replay'),
              onTap: done ? null : _say,
              child: Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF4F8DF5), Color(0xFF2456C8)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0xFF173C8F), offset: Offset(0, 5)),
                  ],
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  color: Colors.white,
                  size: 44,
                ),
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
                          maxSimultaneousDrags: 1,
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          feedback: Material(
                            type: MaterialType.transparency,
                            child: FractionalTranslation(
                              translation: const Offset(-.5, -.5),
                              child: SizedBox(
                                width: _Badge.w * scale * 1.08,
                                height: _Badge.h * scale * 1.08,
                                child: FittedBox(child: badge),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(opacity: .3, child: badge),
                          onDragEnd: (_) {
                            if (_hover != null) setState(() => _hover = null);
                          },
                          child: badge,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_placed.length}/$n',
                  style: _fredoka(34, _kNavy),
                ),
              ),
            ),
          ],
        ),
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

  /// The ending screen: both mascots cheering either side of a board with
  /// every word learned this round, the score, and Play Again / Home.
  Widget _buildSummary(double t) {
    final words = _s.words;
    Widget sway(double phase, Widget c) => Transform.rotate(
      angle: .03 * math.sin(t + phase),
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, -10 * math.sin(t * 2 + phase).abs()),
        child: c,
      ),
    );

    Widget stat(String label, Widget value) => Container(
      width: 290,
      height: 118,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFF3DFA8), width: 4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 56, child: FittedBox(child: value)),
          Text(label, style: _fredoka(24, const Color(0xFF8A7650))),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('$_kA/${_s.bg}.png', fit: BoxFit.fill),
        ),
        Positioned.fill(child: Container(color: const Color(0x990E1A40))),
        Positioned.fill(
          child: CustomPaint(
            painter: _ConfettiPainter(t / (2 * math.pi), sparse: true),
          ),
        ),
        _at(34, 300, 340, 456, sway(0, _img('girl'))),
        _at(1566, 290, 280, 472, sway(math.pi, _img('boy'))),
        _at(
          395,
          40,
          1080,
          650,
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .7, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, v, c) => Transform.scale(scale: v, child: c),
            child: Container(
              padding: const EdgeInsets.fromLTRB(36, 22, 36, 28),
              decoration: BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: _kGold, width: 9),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x77000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text('Words You Learned', style: _fredoka(56, _kNavy)),
                  Text(_s.title, style: _fredoka(26, const Color(0xFFF08A24))),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 5,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.7,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 0; i < words.length; i++)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 500 + 70 * i),
                            curve: Interval(
                              (70 * i) / (500 + 70 * i),
                              1,
                              curve: Curves.easeOutBack,
                            ),
                            builder: (context, v, c) =>
                                Transform.scale(scale: v, child: c),
                            child: _Label(words[i]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      stat(
                        'Stars',
                        Row(
                          children: [
                            for (var i = 0; i < 3; i++)
                              _Star(on: i < _stars, size: 56),
                          ],
                        ),
                      ),
                      stat(
                        'Accuracy',
                        Text('$_accuracy%', style: _fredoka(50, _kNavy)),
                      ),
                      stat(
                        'XP Earned',
                        Text(
                          '+${widget.xp}',
                          style: _fredoka(50, const Color(0xFF2F9A1E)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _at(
          600,
          712,
          300,
          107,
          _ImgBtn(
            key: const ValueKey('lm-again'),
            up: 'play',
            down: 'play_down',
            onTap: _replay,
          ),
        ),
        _at(
          970,
          712,
          300,
          107,
          _ImgBtn(
            key: const ValueKey('lm-home'),
            up: 'btn_home',
            down: 'btn_home_down',
            onTap: _finish,
          ),
        ),
        ..._topButtons(back: false),
      ],
    );
  }
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

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Icon(
        Icons.star_rounded,
        size: size,
        color: on ? const Color(0xFFD98A00) : const Color(0xFFB8AE98),
      ),
      Icon(
        Icons.star_rounded,
        size: size * .8,
        color: on ? const Color(0xFFFFD23F) : const Color(0xFFE6DECB),
      ),
    ],
  );
}

/// Slowly turning light rays behind the congrats title.
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.u);

  final double u;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * .42);
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

/// The draggable speaker badge in the dock.
class _Badge extends StatelessWidget {
  const _Badge({required this.word});

  static const w = 250.0;
  static const h = 88.0;

  final _Word word;

  @override
  Widget build(BuildContext context) => Container(
    width: w,
    height: h,
    padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(h / 2),
      border: Border.all(color: const Color(0xFFF08A24), width: 5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF08A24),
          ),
          child: const Icon(
            Icons.volume_up_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              word.ar,
              textDirection: TextDirection.rtl,
              style: _arabic(44),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kGold, width: 4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(word.ar, textDirection: TextDirection.rtl, style: _arabic(38)),
          Text(word.en, style: _fredoka(20, const Color(0xFF6B5A3A))),
        ],
      ),
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
