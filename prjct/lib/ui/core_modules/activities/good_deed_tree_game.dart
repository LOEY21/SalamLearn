import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// The Good Deed Tree — sort daily actions: good deeds to the tree, wrong
/// actions to the bin. Ported 1:1 from the supplied "Good Deed Tree"
/// (Session 1, Roots & Branches) and "Good Deed Tree Session 2" (Flowers &
/// Fruits) prototypes: start board, how-to-play card, the living garden
/// (sunbeam, rays, clouds, birds), the Good Deed Meter, the
/// card tray, the tree's light-up growth, Mumtaz! over the grown tree,
/// What you learned and the session summary.
///
/// The prototypes are authored against a fixed 368x822 phone screen, so the
/// scene is built inside that virtual stage and scaled to fit; the garden
/// backdrop runs on past the stage to the screen edges.
class GoodDeedTreeGame extends StatefulWidget {
  const GoodDeedTreeGame({
    super.key,
    required this.session,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final GoodDeedTreeSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Leaves the lesson from the start screen's home button.
  final VoidCallback? onExit;

  @override
  State<GoodDeedTreeGame> createState() => _GoodDeedTreeGameState();
}

// ---------------------------------------------------------------------------
// Stage, assets, data — all lifted from the prototypes.
// ---------------------------------------------------------------------------

const double _kW = 368;
const double _kH = 822;
const String _kA = 'assets/images/good_deed_tree';
const String _kBg = '$_kA/bg_garden_v5.png';
const String _kBin = '$_kA/bin.png';

/// Start screen: the painted garden with its bare tree, and the pieces laid
/// over it at their places in the reference (px in the 851x1847 art).
const String _kStartBg = '$_kA/start_bg.png';
const Size _kStartBgSize = Size(851, 1847);
const String _kStartLogo = '$_kA/start_logo.png';
const Rect _kStartLogoAt = Rect.fromLTWH(56, 94, 731, 548);
const String _kStartGirl = '$_kA/start_girl.png';
const Rect _kStartGirlAt = Rect.fromLTWH(6, 925, 325, 500);
const String _kStartBoy = '$_kA/start_boy.png';
const Rect _kStartBoyAt = Rect.fromLTWH(515, 925, 330, 500);
const String _kStartBgUnder = '$_kA/start_bg_under.png';
const String _kStartBgSway = '$_kA/start_bg_sway.png';
const String _kStartBgShader = 'shaders/good_deed_start_bg.frag';
const String _kBtnStart = '$_kA/btn_start.png';

/// Session Summary: wooden title board, gold stars, result tiles, the XP
/// pill and the Remember card.
const String _kSumTitle = '$_kA/sum_title.png';
const double _kSumTitleRatio = 900 / 333;
const String _kSumStar = '$_kA/sum_star.png';
const double _kSumStarRatio = 300 / 272;
const String _kSumTile = '$_kA/sum_tile.png';
const double _kSumTileRatio = 600 / 217;
const String _kSumCard = '$_kA/sum_card_wide.png';
const double _kSumCardRatio = 900 / 245;
const String _kSumXp = '$_kA/sum_xp.png';
const double _kSumXpRatio = 600 / 213;

/// Finish: the glossy brown sign and the leafy green button.
const String _kDoneBoard = '$_kA/done_board.png';
const double _kDoneBoardRatio = 900 / 294;
const String _kBtnGreen = '$_kA/btn_green.png';
const String _kBtnGreenDown = '$_kA/btn_green_down.png';
const double _kBtnGreenRatio = 800 / 204;
const String _kBtnBlue = '$_kA/btn_blue.png';
const String _kBtnBlueDown = '$_kA/btn_blue_down.png';
const double _kBtnBlueRatio = 800 / 203;
const String _kMeterFrame = '$_kA/meter_frame.png';
const double _kMeterRatio = 800 / 157;

/// What you learned: title sign, the good and not-good panels and the
/// footer plank.
const String _kWylTitle = '$_kA/wyl_title.png';
const String _kWylGood = '$_kA/wyl_good_panel.png';
const String _kWylBad = '$_kA/wyl_bad_panel.png';
const String _kWylPlank = '$_kA/wyl_plank.png';

/// The game's hint plank and its green "Mumtaz!" banner.
const String _kHintPlank = '$_kA/hint_plank.png';
const double _kHintPlankRatio = 1000 / 186;
const String _kFbGood = '$_kA/fb_good.png';
const double _kFbGoodRatio = 1000 / 200;

/// How to play: the wooden board, laid on the start art (px in the
/// 851x1847 art) with the kids and the Start button below it.
const String _kHowPanel = '$_kA/howto_panel.png';
const Rect _kHowPanelAt = Rect.fromLTWH(18, 118, 815, 1156);

/// On How to play the start screen's kids keep their side and size and
/// come down this far (art px), to stand in front of the board.
const double _kHowKidDrop = 300;
const Rect _kHowStartAt = Rect.fromLTWH(165, 1545, 520, 173);

/// Into the game: the camera eases into the painted tree in the start art
/// (its centre, art px), then comes back out of the game's own tree.
const Offset _kStartTreeAt = Offset(438, 950);
const String _kBtnStartDown = '$_kA/btn_start_down.png';
const Rect _kStartBtnAt = Rect.fromLTWH(88, 1429, 673, 224);
const String _kBtnHome = '$_kA/btn_home.png';
const String _kBtnBack = '$_kA/btn_back.png';
const String _kBtnSound = '$_kA/btn_sound.png';
const String _kBtnHomeDown = '$_kA/btn_home_down.png';
const String _kBtnBackDown = '$_kA/btn_back_down.png';
const String _kBtnSoundDown = '$_kA/btn_sound_down.png';

const double _kTreeW = 292;
const double _kTreeH = _kTreeW * 1448 / 1086;
const Rect _kTreeRect = Rect.fromLTWH(
  (_kW - _kTreeW) / 2,
  _kH - 276 - _kTreeH,
  _kTreeW,
  _kTreeH,
);
const double _kBinH = 96 + 4 + 18.5;
const Rect _kBinRect = Rect.fromLTWH(11, _kH - 239 - _kBinH, 96, _kBinH);

/// The bin's open rim (stage px), where bad deeds drop in.
final Offset _kBinMouth = _kBinRect.topLeft + const Offset(44, 4);

const List<double> _kHomeX = [9, 80, 151, 222, 293];
const double _kHomeY = 684;
const double _kCardW = 66;
const double _kTrayTop = 670;

const Color _ink = Color(0xFF23401A);
const Color _green = Color(0xFF4B9A20);
const Color _greenDark = Color(0xFF2F6D12);
const Color _brownText = Color(0xFF5B3A1A);
const Color _gold = Color(0xFFFFE873);
const Color _red = Color(0xFFE5533D);
const Color _redText = Color(0xFFB03626);

class _Card {
  const _Card(this.id, this.image, this.text, this.good, this.ok);
  final String id;
  final String image;
  final String text;
  final bool good;
  final String ok;
}

class _Session {
  const _Session({
    required this.tag,
    required this.goal,
    required this.howTree,
    required this.howGrow,
    required this.howChip,
    required this.cards,
    required this.trees,
    required this.doneTree,
    required this.doneTitle,
    required this.doneSub,
    required this.footer,
    required this.fixedText,
    required this.remember,
    required this.insects,
  });

  final String tag;
  final String goal;
  final String howTree;
  final String howGrow;
  final String howChip;
  final List<_Card> cards;
  final List<String> trees;
  final String doneTree;
  final String doneTitle;
  final String doneSub;
  final String footer;

  /// Session 2's longer labels sit in a fixed 36px box at 9.5px.
  final bool fixedText;

  /// The session's lesson in one line, for the summary screen.
  final String remember;

  /// Butterflies and bees around each tree stage: none on a bare tree,
  /// more as the crown fills out.
  final List<(int, int)> insects;
}

const _Session _kRoots = _Session(
  tag: 'Session 1 · Roots & Branches',
  goal:
      'Learn about Love for Allah and Kindness to Others by sorting daily actions.',
  howTree: '$_kA/tree_3.png',
  howGrow: 'Each correct good deed helps the tree grow',
  howChip: 'Sort the good deeds and help the tree grow!',
  cards: [
    _Card(
      'praying',
      '$_kA/card_praying.png',
      'Praying to Allah',
      true,
      'Mumtaz! Praying to Allah is a good deed.',
    ),
    _Card(
      'helping',
      '$_kA/card_helping_parents.png',
      'Helping parents',
      true,
      'Mumtaz! Helping parents shows kindness.',
    ),
    _Card(
      'fighting',
      '$_kA/card_fighting.png',
      'Fighting friends',
      false,
      'Good try! Fighting is not a good deed.',
    ),
    _Card(
      'sharing',
      '$_kA/card_sharing_food.png',
      'Sharing food',
      true,
      'Mumtaz! Sharing food is kind and caring.',
    ),
    _Card(
      'laughing',
      '$_kA/card_laughing.png',
      'Laughing at others',
      false,
      'That can hurt feelings. It belongs in the bin.',
    ),
  ],
  trees: [
    '$_kA/tree_1.png',
    '$_kA/tree_2.png',
    '$_kA/tree_3.png',
    '$_kA/tree_4.png',
  ],
  doneTree: '$_kA/tree_4.png',
  doneTitle: 'Roots & Branches Complete!',
  doneSub: 'Small deeds create a brighter tomorrow.',
  footer: 'Good deeds make our hearts and world beautiful.',
  fixedText: false,
  remember:
      'Loving Allah and being kind to others makes our good deed tree grow strong.',
  insects: [(0, 0), (1, 0), (2, 1), (4, 2)],
);

const _Session _kFlowers = _Session(
  tag: 'Session 2 · Flowers & Fruits',
  goal:
      'Care for the environment and respect the community by sorting good deeds and harmful actions.',
  howTree: '$_kA/s2_tree_2.png',
  howGrow: 'Each correct good deed helps the tree bloom',
  howChip: 'Sort the good deeds and help the tree bloom!',
  cards: [
    _Card(
      'trash',
      '$_kA/s2_card_trash_bin.png',
      'Throwing trash properly',
      true,
      'Mumtaz! Throwing trash properly keeps places clean.',
    ),
    _Card(
      'anthem',
      '$_kA/s2_card_anthem.png',
      'Standing properly for the Anthem',
      true,
      'Mumtaz! Respecting the Anthem shows love for the community.',
    ),
    _Card(
      'branches',
      '$_kA/s2_card_breaking_plants.png',
      'Breaking plant branches',
      false,
      'Good try! Breaking plants is not a good deed.',
    ),
    _Card(
      'planting',
      '$_kA/s2_card_planting_tree.png',
      'Planting a new tree',
      true,
      "Mumtaz! Planting trees helps Allah's creation.",
    ),
    _Card(
      'river',
      '$_kA/s2_card_littering_river.png',
      'Throwing garbage in the river',
      false,
      'That harms nature. It belongs in the bin.',
    ),
  ],
  trees: [
    '$_kA/tree_4.png',
    '$_kA/s2_tree_1.png',
    '$_kA/s2_tree_2.png',
    '$_kA/s2_tree_3.png',
  ],
  doneTree: '$_kA/s2_tree_3.png',
  doneTitle: 'Flowers & Fruits Complete!',
  doneSub: 'Kind actions today, a greener tomorrow.',
  footer: 'Care for nature and community, and good deeds will bloom!',
  fixedText: true,
  remember:
      'Caring for nature and respecting our community helps good deeds bloom.',
  insects: [(3, 1), (4, 2), (5, 2), (6, 3)],
);

enum _Screen { start, how, play, done, recap, summary }

enum _Target { tree, bin }

class _Fb {
  const _Fb(this.ok, this.text);
  final bool ok;
  final String text;
}

/// A card's lift off the tray: drag offset, tilt, scale and fade.
class _Lift {
  const _Lift(this.off, this.rot, this.scale, this.op);
  static const rest = _Lift(Offset.zero, 0, 1, 1);
  final Offset off;
  final double rot;
  final double scale;
  final double op;

  /// This lift raised by [dy] (the arc of a flight).
  _Lift plusArc(double dy) =>
      dy == 0 ? this : _Lift(off - Offset(0, dy), rot, scale, op);

  static _Lift lerp(_Lift a, _Lift b, double t) => _Lift(
    Offset(
      a.off.dx + (b.off.dx - a.off.dx) * t,
      a.off.dy + (b.off.dy - a.off.dy) * t,
    ),
    a.rot + (b.rot - a.rot) * t,
    a.scale + (b.scale - a.scale) * t,
    a.op + (b.op - a.op) * t,
  );
}

// ---------------------------------------------------------------------------
// CSS keyframe helpers
// ---------------------------------------------------------------------------

/// Progress through an infinite CSS animation, or null before its delay.
double? _phase(double t, double dur, [double delay = 0]) =>
    t < delay ? null : ((t - delay) % dur) / dur;

/// Keyframe interpolation with the timing function applied per segment,
/// as CSS does.
double _kf(
  double p,
  List<double> at,
  List<double> v, [
  Curve c = Curves.linear,
]) {
  if (p <= at.first) return v.first;
  for (var i = 1; i < at.length; i++) {
    if (p <= at[i]) {
      final u = (p - at[i - 1]) / (at[i] - at[i - 1]);
      return v[i - 1] + (v[i] - v[i - 1]) * c.transform(u.clamp(0.0, 1.0));
    }
  }
  return v.last;
}

/// An elliptical radial gradient (CSS `closest-side ellipse`).
ui.Gradient _ellipse(
  Offset c,
  double rx,
  double ry,
  List<Color> colors,
  List<double> stops,
) => ui.Gradient.radial(
  Offset.zero,
  1,
  colors,
  stops,
  TileMode.clamp,
  (Matrix4.identity()
        ..translateByDouble(c.dx, c.dy, 0, 1)
        ..scaleByDouble(rx, ry, 1, 1))
      .storage,
);

Color _rgba(int r, int g, int b, double a) =>
    Color.fromRGBO(r, g, b, a.clamp(0.0, 1.0));

const Curve _easeOut = Cubic(0, 0, 0.58, 1);
const Curve _easeInOut = Cubic(0.42, 0, 0.58, 1);

TextStyle _f(
  double size, {
  FontWeight w = FontWeight.w400,
  Color color = _ink,
  double? h,
  double? ls,
  List<Shadow>? sh,
}) => TextStyle(
  fontFamily: 'Fredoka',
  fontSize: size,
  fontWeight: w,
  color: color,
  height: h,
  letterSpacing: ls,
  shadows: sh,
);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _GoodDeedTreeGameState extends State<GoodDeedTreeGame>
    with TickerProviderStateMixin {
  late final _Session _d = switch (widget.session) {
    GoodDeedTreeSession.rootsAndBranches => _kRoots,
    GoodDeedTreeSession.flowersAndFruits => _kFlowers,
  };

  final GlobalKey _stageKey = GlobalKey();
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker;

  /// Clock for one growth's light-up, glow, motes and sweep.
  /// Start -> How to play: 0 is the start screen, 1 the finished board.
  /// How to play -> game (or Play Again): the pieces of the game arrive.
  late final AnimationController _playCtl = AnimationController(vsync: this);

  /// The game was just started from How to play: its board and kids leave
  /// and the start art fades into the game garden first.
  bool _fromHow = false;

  /// The start screen's entrance: logo, kids, Start button, home.
  late final AnimationController _introCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// What you learned / summary clearing away before Play Again.
  /// Back from the game to the start screen: the pieces leave, then the
  /// start art fades in over the garden.
  late final AnimationController _backCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  late final AnimationController _exitCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late final AnimationController _howCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  late final AnimationController _trayCtl = AnimationController(vsync: this)
    ..addListener(() {
      setState(
        () => _trayY =
            _trayFrom +
            (_trayTo - _trayFrom) * _trayCurve.transform(_trayCtl.value),
      );
    });
  double _trayY = 0;
  double _trayFrom = 0;
  double _trayTo = 0;
  Curve _trayCurve = Curves.linear;

  late final List<AnimationController> _cardCtl;
  final List<_Lift> _lifts = List.filled(5, _Lift.rest);
  final List<_Lift> _liftFrom = List.filled(5, _Lift.rest);
  final List<_Lift> _liftTo = List.filled(5, _Lift.rest);
  final List<Curve> _liftCurve = List.filled(5, Curves.linear);

  /// Height of the arc a card's flight bows up by (0 = straight).
  final List<double> _liftArc = List.filled(5, 0);

  /// A bad deed landing in the bin: the bin squashes and wobbles, dust
  /// puffs from its rim and recycle sparks burst up.
  /// A dragged card hovering over the tree or the bin: it glows.
  late final AnimationController _treeHover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final AnimationController _binHover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  _Target? _over;

  void _setOver(_Target? t) {
    if (t == _over) return;
    _over = t;
    t == _Target.tree ? _treeHover.forward() : _treeHover.reverse();
    t == _Target.bin ? _binHover.forward() : _binHover.reverse();
  }

  late final AnimationController _binCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  _Screen _screen = _Screen.start;
  List<int> _sorted = [];
  int? _sel;
  int _correct = 0;
  int _stage = 0;
  String? _prevTree;
  bool _flash = false;
  bool _burst = false;
  _Fb? _fb;
  int _fbId = 0;
  bool _busy = false;
  bool _sound = true;
  int? _top;
  bool _trayGone = false;
  int _errors = 0;

  /// Which tree was standing from when: each falling leaf keeps the tree
  /// it broke off, so growing the tree never restarts or clears them.
  final List<_Shed> _shed = [];
  final Map<String, _Canopy> _canopyReady = {};
  final Stopwatch _clock = Stopwatch();

  int? _dragIdx;
  int? _dragPointer;
  Offset _dragStart = Offset.zero;
  bool _dragLast = false;

  final List<Timer> _timers = [];
  Timer? _fbT;
  Timer? _swapT;
  Timer? _growT;
  Timer? _trayT;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)
      ..start();
    for (final a in {..._d.trees, _d.doneTree}) {
      () async {
        final c = await _canopyOf(
          a,
          await _swayImage(a),
          await _swayImage(_leavesMask(a)),
        );
        if (mounted) _canopyReady[a] = c;
      }().ignore();
      if (a == _kFruitTree) {
        _swayImage(_fruitMap(a)).ignore();
        _swayImage(_fruitUnder(a)).ignore();
      }
    }
    _shed.add(_Shed(0, _d.trees.first, 0));
    _loadStartLive();
    _introCtl.forward();
    _cardCtl = List.generate(5, (i) {
      final c = AnimationController(vsync: this);
      c.addListener(() {
        setState(
          () => _lifts[i] = _Lift.lerp(
            _liftFrom[i],
            _liftTo[i],
            _liftCurve[i].transform(c.value),
          ).plusArc(_liftArc[i] * 4 * c.value * (1 - c.value)),
        );
      });
      return c;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final a in [
      _kBg,
      _kBin,
      _kStartBg,
      _kHowPanel,
      _kSumTitle,
      _kSumStar,
      _kSumTile,
      _kSumCard,
      _kSumXp,
      _kDoneBoard,
      _kBtnGreen,
      _kBtnGreenDown,
      _kBtnBlue,
      _kBtnBlueDown,
      _kMeterFrame,
      _kWylTitle,
      _kWylGood,
      _kWylBad,
      _kWylPlank,
      _kHintPlank,
      _kFbGood,
      _kStartLogo,
      _kStartGirl,
      _kStartBoy,
      _kBtnStart,
      _kBtnStartDown,
      _kBtnHome,
      _kBtnBack,
      _kBtnSound,
      _kBtnHomeDown,
      _kBtnBackDown,
      _kBtnSoundDown,
      ..._d.trees,
      _d.doneTree,
      _d.howTree,
      ..._d.cards.map((c) => c.image),
    ]) {
      precacheImage(AssetImage(a), context);
    }
  }

  @override
  void dispose() {
    _startLive?.shader.dispose();
    _cancelTimers();
    _ticker.dispose();
    _time.dispose();
    _fx.dispose();
    _howCtl.dispose();
    _playCtl.dispose();
    _introCtl.dispose();
    _exitCtl.dispose();
    _backCtl.dispose();
    _binCtl.dispose();
    _treeHover.dispose();
    _binHover.dispose();
    _trayCtl.dispose();
    for (final c in _cardCtl) {
      c.dispose();
    }
    super.dispose();
  }

  Timer _later(int ms, VoidCallback fn) {
    final t = Timer(Duration(milliseconds: ms), () {
      if (mounted) fn();
    });
    _timers.add(t);
    return t;
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  // -------------------------------------------------------------------------
  // Sound — the prototype's Web Audio tones, as system clicks and haptics.
  // -------------------------------------------------------------------------

  void _chime() {
    if (!_sound) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  void _boing() {
    if (!_sound) return;
    HapticFeedback.mediumImpact();
  }

  // -------------------------------------------------------------------------
  // Card and tray motion
  // -------------------------------------------------------------------------

  void _animLift(int i, _Lift to, int ms, Curve curve, {double arc = 0}) {
    _liftArc[i] = arc;
    _liftFrom[i] = _lifts[i];
    _liftTo[i] = to;
    _liftCurve[i] = curve;
    _cardCtl[i]
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  void _snapBack(int i) =>
      _animLift(i, _Lift.rest, 340, const Cubic(0.34, 1.56, 0.64, 1));

  void _animTray(double to, int ms, Curve curve) {
    _trayFrom = _trayY;
    _trayTo = to;
    _trayCurve = curve;
    _trayCtl
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  void _restoreTray() => _animTray(0, 340, const Cubic(0.34, 1.3, 0.64, 1));

  double get _cardH => _d.fixedText ? 109 : 99;

  // -------------------------------------------------------------------------
  // Drag and tap
  // -------------------------------------------------------------------------

  Offset _local(Offset global) =>
      (_stageKey.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);

  _Target? _targetAt(Offset p) {
    if (_kBinRect.inflate(18).contains(p)) return _Target.bin;
    if (_kTreeRect.inflate(18).contains(p)) return _Target.tree;
    return null;
  }

  void _down(int i, PointerDownEvent e) {
    if (_dragIdx != null) return;
    setState(() => _sel = i);
    if (_busy) return;
    _dragIdx = i;
    _dragPointer = e.pointer;
    _dragStart = _local(e.position);
    _dragLast = _d.cards.length - _sorted.length == 1;
    if (_dragLast) _trayCtl.stop();
    _cardCtl[i].stop();
    setState(() => _top = i);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _dragPointer) return;
    final i = _dragIdx!;
    final p = _local(e.position);
    final d = p - _dragStart;
    setState(() {
      _lifts[i] = _Lift(d, d.dx * 0.03 * math.pi / 180, 1.05, 1);
      if (_dragLast) _trayY = (-d.dy / 280).clamp(0.0, 1.0) * 200;
    });
    _setOver(_targetAt(p));
  }

  void _up(PointerEvent e) {
    if (e.pointer != _dragPointer) return;
    final i = _dragIdx!;
    _dragIdx = null;
    _dragPointer = null;
    final t = e is PointerCancelEvent ? null : _targetAt(_local(e.position));
    _setOver(null);
    if (t != null) {
      _resolve(t, i);
      return;
    }
    _restoreTray();
    _snapBack(i);
  }

  void _showFb(bool ok, String text, int ms) {
    setState(() {
      _fb = _Fb(ok, text);
      _fbId++;
    });
    _fbT?.cancel();
    _fbT = _later(ms, () => setState(() => _fb = null));
  }

  void _tapTarget(_Target target) {
    if (_busy) return;
    final i = _sel;
    if (i == null) {
      _showFb(false, 'Pick a card first, then tap where it goes.', 1700);
      return;
    }
    _resolve(target, i);
  }

  void _resolve(_Target target, int i) {
    final card = _d.cards[i];
    if (_busy || _sorted.contains(i)) return;
    final right = (target == _Target.tree) == card.good;
    if (!right) {
      _errors++;
      _boing();
      _snapBack(i);
      _restoreTray();
      _showFb(
        false,
        card.good
            ? 'Oops! That is a good deed. Give it to the tree!'
            : 'Oops! That one hurts others. Try the bin!',
        1900,
      );
      return;
    }
    _chime();
    final home = Offset(_kHomeX[i] + _kCardW / 2, _kHomeY + _cardH / 2);
    if (target == _Target.tree) {
      _animLift(
        i,
        _Lift(_kTreeRect.center - home, 0, 0.18, 0),
        400,
        const Cubic(0.5, 0, 0.75, 0),
      );
    } else {
      _animLift(
        i,
        _Lift(_kBinMouth + const Offset(0, 10) - home, -0.9, 0.22, 0.4),
        400,
        Curves.easeIn,
        arc: 70,
      );
    }
    _fbT?.cancel();
    setState(() => _busy = true);
    _later(380, () {
      _cardCtl[i].stop();
      _lifts[i] = _Lift.rest;
      final sorted = [..._sorted, i];
      final done = sorted.length >= _d.cards.length;
      final grows = target == _Target.tree;
      final nextStage = grows ? _stage + 1 : _stage;
      final from = _d.trees[math.min(_stage, _d.trees.length - 1)];
      final to = _d.trees[math.min(nextStage, _d.trees.length - 1)];
      final changed = from != to;
      setState(() {
        _sorted = sorted;
        _sel = null;
        _correct++;
        _fb = _Fb(true, card.ok);
        _fbId++;
        _busy = false;
        _burst = grows;
        _flash = changed;
        _prevTree = changed ? from : null;
      });
      if (grows || changed) _fx.forward(from: 0);
      if (!grows) _binCtl.forward(from: 0);
      _swapT?.cancel();
      if (changed) {
        _swapT = _later(620, () {
          _shed.add(_Shed(_time.value, to, _growthOf(to)));
          setState(() => _stage = nextStage);
        });
      } else {
        setState(() => _stage = nextStage);
      }
      _growT?.cancel();
      _growT = _later(
        3050,
        () => setState(() {
          _prevTree = null;
          _flash = false;
        }),
      );
      _fbT = _later(
        3200,
        () => setState(() {
          _fb = null;
          _burst = false;
        }),
      );
      if (done) {
        _trayT?.cancel();
        _trayT = _later(200, () {
          _animTray(200, 450, const Cubic(0.4, 0, 0.7, 0.4));
          _trayT = _later(470, () => setState(() => _trayGone = true));
        });
        _later(
          3400,
          () => setState(() {
            _screen = _Screen.done;
            _clock.stop();
            _fb = null;
            _burst = false;
          }),
        );
      }
    });
  }

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  void _reset(_Screen to) {
    _setOver(null);
    if (to == _Screen.start) {
      _howCtl.value = 0;
      _introCtl.forward(from: 0);
    }
    _fromHow = false;
    _cancelTimers();
    _shed
      ..clear()
      ..add(_Shed(_time.value, _d.trees.first, 0));
    _fx.reset();
    _trayCtl.stop();
    for (var i = 0; i < 5; i++) {
      _cardCtl[i].stop();
      _lifts[i] = _Lift.rest;
    }
    _dragIdx = null;
    _dragPointer = null;
    setState(() {
      _trayY = 0;
      _trayGone = false;
      _screen = to;
      _correct = 0;
      _stage = 0;
      _flash = false;
      _sorted = [];
      _sel = null;
      _fb = null;
      _burst = false;
      _busy = false;
      _top = null;
      _prevTree = null;
      _errors = 0;
    });
  }

  void _goStart() => _reset(_Screen.start);
  void _goHow() {
    setState(() => _screen = _Screen.how);
    _howCtl.forward(from: 0);
  }

  void _goPlay({bool fromHow = false}) {
    _reset(_Screen.play);
    _fromHow = fromHow;
    _playCtl
      ..duration = Duration(milliseconds: fromHow ? 4200 : 1000)
      ..forward(from: 0);
    _clock
      ..reset()
      ..start();
  }

  /// Start art dissolving into the game garden.
  double get _dissolve => _playSpan(0.48, 0.66, Curves.easeInOut);

  /// Zoom into the start art's tree: slow to start, gliding in.
  double get _zoomIn => 1 + 1.1 * _playSpan(0.06, 0.66, Curves.easeInOutSine);

  /// The game scene arrives zoomed in on its tree and eases back out.
  double get _zoomOut =>
      1 + 0.35 * (1 - _playSpan(0.48, 0.8, Curves.easeOutCubic));

  /// Where a point of the start art (px) lands on screen, as an alignment,
  /// matching the cover-fitted, bottom-aligned art.
  Alignment _startArtAlign(BoxConstraints box, Offset art) {
    final sc = math.max(
      box.maxWidth / _kStartBgSize.width,
      box.maxHeight / _kStartBgSize.height,
    );
    final x = (box.maxWidth - _kStartBgSize.width * sc) / 2 + art.dx * sc;
    final y = box.maxHeight - (_kStartBgSize.height - art.dy) * sc;
    return Alignment(x / box.maxWidth * 2 - 1, y / box.maxHeight * 2 - 1);
  }

  /// Where the game tree's centre sits on screen, as an alignment.
  Alignment _gameTreeAlign(BoxConstraints box) {
    final k = math.min(box.maxWidth / _kW, box.maxHeight / _kH);
    final c = _kTreeRect.center;
    final x = (box.maxWidth - _kW * k) / 2 + c.dx * k;
    final y = box.maxHeight - (_kH - c.dy) * k;
    return Alignment(x / box.maxWidth * 2 - 1, y / box.maxHeight * 2 - 1);
  }

  /// Play Again from What you learned or the summary: the screen lifts
  /// and fades while the dimmer clears, then the game's pieces arrive.
  void _goBack() {
    if (_backCtl.isAnimating) return;
    _backCtl.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _goStart();
      _backCtl.value = 0;
    });
  }

  void _playAgain() {
    if (_exitCtl.isAnimating) return;
    _exitCtl.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _goPlay();
      _exitCtl.value = 0;
    });
  }

  Widget _leaving(Widget child) => AnimatedBuilder(
    animation: _exitCtl,
    child: child,
    builder: (context, c) {
      final e = Curves.easeInCubic.transform(_exitCtl.value);
      return IgnorePointer(
        ignoring: _exitCtl.isAnimating,
        child: Opacity(
          opacity: 1 - e,
          child: Transform.translate(
            offset: Offset(0, -30 * e),
            child: Transform.scale(scale: 1 - 0.06 * e, child: c),
          ),
        ),
      );
    },
  );

  /// Progress through [_playCtl]'s window [a]..[b] (0..1), curved.
  double _playSpan(double a, double b, [Curve c = Curves.linear]) =>
      c.transform(((_playCtl.value - a) / (b - a)).clamp(0.0, 1.0));

  /// How far the game pieces have arrived, 0..1.
  double get _enterU {
    if (!_playCtl.isAnimating && _playCtl.value == 0 && _backCtl.value == 0) {
      return 1;
    }
    final u = _fromHow ? _playSpan(0.72, 1) : _playCtl.value;
    // Going back: the pieces leave in reverse.
    final back = Curves.easeInCubic.transform(
      (_backCtl.value / 0.5).clamp(0.0, 1.0),
    );
    return u * (1 - back);
  }

  /// One game piece's arrival in its window [a]..[b] of [_enterU].
  double _enter(double a, double b, Curve c) =>
      c.transform(((_enterU - a) / (b - a)).clamp(0.0, 1.0));

  void _goRecap() => setState(() => _screen = _Screen.recap);
  void _goSummary() => setState(() => _screen = _Screen.summary);

  void _finish() {
    final n = _d.cards.length;
    widget.onComplete(widget.xp, n / (n + _errors) * 100, _errors);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final k = math.min(box.maxWidth / _kW, box.maxHeight / _kH);
        final stageTop = box.maxHeight - _kH * k;
        final padTop = MediaQuery.paddingOf(context).top;
        final shift = math.max(0.0, padTop - stageTop) / k;
        return ColoredBox(
          color: const Color(0xFF8FD0F5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: _background(box)),
              if (_screen == _Screen.start ||
                  _screen == _Screen.how ||
                  (_screen == _Screen.play && _fromHow))
                Positioned.fill(child: _buildIntro(box, padTop)),
              AnimatedBuilder(
                animation: _playCtl,
                builder: (context, stage) => _fromHow
                    ? Transform.scale(
                        scale: _zoomOut,
                        alignment: _gameTreeAlign(box),
                        child: stage,
                      )
                    : stage!,
                child: SizedBox.expand(
                  child: FittedBox(
                    alignment: Alignment.bottomCenter,
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.noScaling),
                      child: SizedBox(
                        key: _stageKey,
                        width: _kW,
                        height: _kH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _AmbientPainter(_time),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: switch (_screen) {
                                _Screen.start => const SizedBox.shrink(),
                                _Screen.how => const SizedBox.shrink(),
                                // Finishing keeps the same garden and grown
                                // tree; only the game pieces make way.
                                _Screen.play ||
                                _Screen.done => _buildPlay(shift),
                                _Screen.recap => _endScene(
                                  _leaving(_buildRecap(shift)),
                                ),
                                _Screen.summary => _endScene(
                                  _leaving(_buildSummary()),
                                ),
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Going back: the start art fades in over the whole garden,
              // then the start screen takes over from it.
              if (_screen == _Screen.play)
                AnimatedBuilder(
                  animation: _backCtl,
                  builder: (context, _) {
                    final v = Curves.easeInOut.transform(
                      ((_backCtl.value - 0.45) / 0.55).clamp(0.0, 1.0),
                    );
                    if (v <= 0) return const SizedBox.shrink();
                    return IgnorePointer(
                      child: Opacity(opacity: v, child: _startArt()),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// The start art, with its swaying flowers once the shader is ready.
  Widget _startArt() {
    final live = _startLive;
    return live != null
        ? CustomPaint(painter: _StartBgPainter(live, _time))
        : Image.asset(
            _kStartBg,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            gaplessPlayback: true,
          );
  }

  Widget _background(BoxConstraints box) {
    final art = _startArt();
    if (_screen == _Screen.start || _screen == _Screen.how) return art;
    final game = Image.asset(
      _kBg,
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
    );
    if (!_fromHow) return game;
    return AnimatedBuilder(
      animation: _playCtl,
      builder: (context, _) {
        final fade = _dissolve;
        final zoomedGame = Transform.scale(
          scale: _zoomOut,
          alignment: _gameTreeAlign(box),
          child: game,
        );
        if (fade >= 1) return zoomedGame;
        return Stack(
          fit: StackFit.expand,
          children: [
            zoomedGame,
            Opacity(
              opacity: 1 - fade,
              child: Transform.scale(
                scale: _zoomIn,
                alignment: _startArtAlign(box, _kStartTreeAt),
                child: art,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Start art drawn through [_kStartBgShader] so its corner flowers sway;
  /// null until loaded, or where shaders aren't supported.
  _StartLive? _startLive;

  Future<void> _loadStartLive() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(_kStartBgShader);
      final bg = await _swayImage(_kStartBg);
      final under = await _swayImage(_kStartBgUnder);
      final sway = await _swayImage(_kStartBgSway);
      if (!mounted) return;
      setState(
        () =>
            _startLive = _StartLive(program.fragmentShader(), bg, under, sway),
      );
    } catch (_) {
      // Shaders unsupported here: the still art stays.
    }
  }

  // ---- start & how to play ----

  /// Maps a rect in the 851x1847 start art to the screen, bottom-aligned
  /// like the art. Fitted so the whole art area is on screen: on phones it
  /// matches the edge-to-edge art; on wider screens (tablets), where the
  /// art's top is cropped, the pieces still all show.
  Rect Function(Rect) _artMap(BoxConstraints box) {
    final sc = math.min(
      box.maxWidth / _kStartBgSize.width,
      box.maxHeight / _kStartBgSize.height,
    );
    final ox = (box.maxWidth - _kStartBgSize.width * sc) / 2;
    final oy = box.maxHeight - _kStartBgSize.height * sc;
    return (r) => Rect.fromLTWH(
      ox + r.left * sc,
      oy + r.top * sc,
      r.width * sc,
      r.height * sc,
    );
  }

  /// Start screen and How to play as one scene on the start art, so the
  /// change between them is a single smooth move: the logo lifts away and
  /// the Start button shrinks off, the kids keep their side and size and
  /// come straight down, the board drops in and settles, and its Start
  /// button pops in last.
  Widget _buildIntro(BoxConstraints box, double padTop) {
    final at = _artMap(box);
    final sc = at(const Rect.fromLTWH(0, 0, 1, 1)).width;
    final panel = at(_kHowPanelAt);
    final board = _howBoard(panel.size);
    return AnimatedBuilder(
      animation: Listenable.merge([_time, _howCtl, _playCtl, _introCtl]),
      builder: (context, _) {
        final t = _time.value;
        final h = _howCtl.value;
        // Entrance: logo drops in, girl then boy rise from the grass, the
        // Start button pops, the home button fades in.
        final e = _introCtl.value;
        double arrive(double a, double b, Curve c) =>
            c.transform(((e - a) / (b - a)).clamp(0.0, 1.0));
        final logoIn = arrive(0, 0.5, const Cubic(0.34, 1.3, 0.64, 1));
        final girlIn = arrive(0.2, 0.65, const Cubic(0.34, 1.2, 0.64, 1));
        final boyIn = arrive(0.3, 0.75, const Cubic(0.34, 1.2, 0.64, 1));
        final btnIn = arrive(0.5, 0.95, const Cubic(0.34, 1.5, 0.64, 1));
        final homeIn = arrive(0.6, 1, Curves.easeOut);
        // Into the game: the board lifts out, the kids go down off screen.
        final exit = _screen == _Screen.play
            ? _playSpan(0, 0.14, Curves.easeInCubic)
            : 0.0;
        if (exit >= 1) return const SizedBox.shrink();
        double span(double a, double b, [Curve c = Curves.linear]) =>
            c.transform(((h - a) / (b - a)).clamp(0.0, 1.0));
        final leave = span(0, 0.35, Curves.easeInCubic);
        final drop = span(0.1, 0.75, Curves.easeInOutCubic);
        final boardIn = span(0.3, 1, const Cubic(0.34, 1.25, 0.64, 1));
        final startIn = span(0.7, 1, const Cubic(0.34, 1.4, 0.64, 1));
        final onStart = _screen == _Screen.start;

        Widget kid(String asset, Rect r, double rise) => Positioned.fromRect(
          rect: at(
            r.translate(0, _kHowKidDrop * drop + 700 * exit + 260 * (1 - rise)),
          ),
          child: Opacity(
            opacity: rise.clamp(0.0, 1.0),
            child: Image.asset(asset, fit: BoxFit.fill),
          ),
        );

        return Stack(
          children: [
            if (h > 0.3)
              Positioned.fromRect(
                rect: panel,
                child: Opacity(
                  opacity: span(0.3, 0.55) * (1 - exit),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      -(panel.bottom) * (1 - boardIn) - panel.bottom * exit,
                    ),
                    child: board,
                  ),
                ),
              ),
            if (leave < 1)
              Positioned.fromRect(
                rect: at(_kStartLogoAt),
                child: Opacity(
                  opacity: (1 - leave) * logoIn.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      math.sin(t * 1.6) * 6 * sc -
                          80 * sc * leave -
                          260 * sc * (1 - logoIn),
                    ),
                    child: Transform.scale(
                      scale: 1 + math.sin(t * 1.6 + 1) * 0.012,
                      child: Image.asset(_kStartLogo, fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
            kid(_kStartGirl, _kStartGirlAt, girlIn),
            kid(_kStartBoy, _kStartBoyAt, boyIn),
            if (leave < 1)
              Positioned.fromRect(
                rect: at(_kStartBtnAt),
                child: IgnorePointer(
                  ignoring: !onStart,
                  child: Opacity(
                    opacity: (1 - leave) * btnIn.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale:
                          (1 + (math.sin(t * 3.4) * 0.5 + 0.5) * 0.04) *
                          (1 - 0.3 * leave) *
                          (0.5 + 0.5 * btnIn),
                      child: _ImageButton(
                        key: const ValueKey('gdt-play'),
                        up: _kBtnStart,
                        down: _kBtnStartDown,
                        onTap: _goHow,
                      ),
                    ),
                  ),
                ),
              ),
            if (h > 0.7)
              Positioned.fromRect(
                rect: at(_kHowStartAt),
                child: IgnorePointer(
                  ignoring: h < 1 || _screen != _Screen.how,
                  child: Opacity(
                    opacity: span(0.7, 0.85) * (1 - exit),
                    child: Transform.scale(
                      scale: (0.7 + 0.3 * startIn) * (1 - 0.4 * exit),
                      child: _ImageButton(
                        key: const ValueKey('gdt-start'),
                        up: _kBtnStart,
                        down: _kBtnStartDown,
                        onTap: () => _goPlay(fromHow: true),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.onExit != null && leave < 1)
              Positioned(
                left: 12,
                top: padTop + 10,
                width: 86,
                height: 80,
                child: IgnorePointer(
                  ignoring: !onStart,
                  child: Opacity(
                    opacity: (1 - leave) * homeIn,
                    child: _ImageButton(
                      key: const ValueKey('gdt-home'),
                      up: _kBtnHome,
                      down: _kBtnHomeDown,
                      onTap: widget.onExit!,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The board: its title sign, four numbered steps and the bottom plank,
  /// placed in the board art's own proportions (983x1394 px).
  Widget _howBoard(Size size) {
    final w = size.width;
    final h = size.height;
    Rect frac(double l, double t, double r, double b) =>
        Rect.fromLTRB(w * l / 983, h * t / 1394, w * r / 983, h * b / 1394);
    final fs = w / 395;
    const ink = Color(0xFF5A2A0E);
    final good = _d.cards.firstWhere((c) => c.good).image;
    final bad = _d.cards.firstWhere((c) => !c.good).image;
    final rows = [
      (const Color(0xFF3FAE3A), 'Drag each picture card', _howStep1(good)),
      (const Color(0xFFF5A915), 'Good deeds go to the tree', _howStep2(good)),
      (const Color(0xFFE5373F), 'Bad deeds go to the bin', _howStep3(bad)),
      (const Color(0xFF8E4FD8), _d.howGrow, _howStep4()),
    ];
    const rowY = [
      (361.0, 541.0),
      (566.0, 758.0),
      (784.0, 976.0),
      (1001.0, 1189.0),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: Image.asset(_kHowPanel, fit: BoxFit.fill)),
        Positioned.fromRect(
          rect: frac(120, 40, 890, 262),
          child: Center(
            child: _outlined(
              'How to Play',
              _f(38 * fs, w: FontWeight.w700, color: Colors.white),
              const Color(0xFF6B3A12),
              6 * fs,
            ),
          ),
        ),
        for (var i = 0; i < 4; i++)
          Positioned.fromRect(
            rect: frac(73, rowY[i].$1, 915, rowY[i].$2),
            child: LayoutBuilder(
              builder: (context, row) {
                final rh = row.maxHeight;
                final rw = row.maxWidth;
                return Row(
                  children: [
                    SizedBox(width: rw * 0.03),
                    SizedBox.square(
                      dimension: rh * 0.58,
                      child: CustomPaint(
                        painter: _NumberFlowerPainter(rows[i].$1),
                        child: Center(
                          child: _outlined(
                            '${i + 1}',
                            _f(
                              rh * 0.3,
                              w: FontWeight.w700,
                              color: Colors.white,
                            ),
                            Color.lerp(rows[i].$1, Colors.black, 0.35)!,
                            2.5 * fs,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: rw * 0.035),
                    SizedBox(
                      width: rw * 0.38,
                      child: Text(
                        rows[i].$2,
                        style: _f(
                          (i == 3 ? 15 : 16.5) * fs,
                          w: FontWeight.w700,
                          color: ink,
                          h: 1.15,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: rh * 0.08),
                        child: rows[i].$3,
                      ),
                    ),
                    SizedBox(width: rw * 0.02),
                  ],
                );
              },
            ),
          ),
        Positioned.fromRect(
          rect: frac(230, 1236, 790, 1380),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * fs),
              child: Text(
                _d.howChip,
                textAlign: TextAlign.center,
                style: _f(14.5 * fs, w: FontWeight.w700, color: ink, h: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A painted pill button (green, or blue for Play Again) with its label.
  Widget _artButton(
    Key key,
    String label, {
    required bool blue,
    required double width,
    required VoidCallback onTap,
  }) => Center(
    child: SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: blue ? _kBtnBlueRatio : _kBtnGreenRatio,
        child: _ImageButton(
          key: key,
          up: blue ? _kBtnBlue : _kBtnGreen,
          down: blue ? _kBtnBlueDown : _kBtnGreenDown,
          onTap: onTap,
          label: _outlined(
            label,
            _f(24, w: FontWeight.w700, color: Colors.white),
            blue ? const Color(0xFF0D4C8C) : const Color(0xFF1E5E0C),
            5,
          ),
        ),
      ),
    ),
  );

  /// Chunky sign lettering: a yellow-to-gold fill inside a thick dark
  /// green outline, sitting on a solid drop — like the painted title art.
  Widget _signTitle(String text) {
    final style = _f(40, w: FontWeight.w700, h: 1);
    const edge = Color(0xFF1F4F0A);
    return Stack(
      children: [
        // Drop under the letters.
        Transform.translate(
          offset: const Offset(0, 3),
          child: Text(
            text,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 8
                ..strokeJoin = StrokeJoin.round
                ..color = edge,
            ),
          ),
        ),
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..strokeJoin = StrokeJoin.round
              ..color = edge,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF59A), Color(0xFFFFD83A), Color(0xFFF6B41C)],
            stops: [0, 0.55, 1],
          ).createShader(r),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }

  /// White text with a thick coloured outline, like the painted titles.
  Widget _outlined(String text, TextStyle style, Color edge, double width) =>
      Stack(
        children: [
          Text(
            text,
            style: style.copyWith(
              color: null,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = width
                ..strokeJoin = StrokeJoin.round
                ..color = edge,
            ),
          ),
          Text(text, style: style),
        ],
      );

  /// A picture card like the ones in the tray, tilted a little.
  Widget _howCard(String image, double tilt) => Transform.rotate(
    angle: tilt,
    child: AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E0),
          border: Border.all(color: const Color(0xFFE2C89A), width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(1, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.asset(image, fit: BoxFit.cover),
        ),
      ),
    ),
  );

  Widget _howArrow(Color color) => AspectRatio(
    aspectRatio: 1.3,
    child: CustomPaint(painter: _ArrowPainter(color)),
  );

  Widget _howStep1(String card) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Positioned.fill(child: CustomPaint(painter: _SparkPainter())),
      _howCard(card, -0.12),
      const Positioned(
        right: 4,
        bottom: -6,
        child: Icon(
          Icons.touch_app,
          size: 30,
          color: Colors.white,
          shadows: [Shadow(color: Color(0xFF3A2410), blurRadius: 2)],
        ),
      ),
    ],
  );

  Widget _howStep2(String card) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(flex: 4, child: _howCard(card, -0.08)),
      Expanded(flex: 3, child: _howArrow(const Color(0xFF3FAE3A))),
      Expanded(
        flex: 4,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFFFF4C2), Color(0x00FFF4C2)],
            ),
          ),
          child: Image.asset(_d.howTree, fit: BoxFit.contain),
        ),
      ),
    ],
  );

  Widget _howStep3(String card) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(flex: 4, child: _howCard(card, -0.08)),
      Expanded(flex: 3, child: _howArrow(const Color(0xFFE5373F))),
      Expanded(flex: 4, child: Image.asset(_kBin, fit: BoxFit.contain)),
    ],
  );

  Widget _howStep4() => Row(
    children: [
      Expanded(flex: 4, child: Image.asset(_d.trees[1], fit: BoxFit.contain)),
      Expanded(flex: 3, child: _howArrow(const Color(0xFF3FAE3A))),
      Expanded(
        flex: 4,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: CustomPaint(painter: _SparkPainter())),
            Image.asset(_d.doneTree, fit: BoxFit.contain),
          ],
        ),
      ),
    ],
  );

  // ---- play ----

  /// The Good Deed Meter on its glossy blue frame.
  Widget _meter() => AspectRatio(
    aspectRatio: _kMeterRatio,
    child: Stack(
      children: [
        Positioned.fill(child: Image.asset(_kMeterFrame, fit: BoxFit.fill)),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                // Shrinks to fit beside the dots when the top bar is tight.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Good Deed Meter',
                      style: _f(
                        12,
                        w: FontWeight.w700,
                        color: _green,
                        ls: 0.48,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Container(
                    key: ValueKey('gdt-meter-$i-${i < _correct}'),
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFE6D5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x14000000),
                        width: 2,
                      ),
                    ),
                    child: i < _correct
                        ? OverflowBox(
                            maxWidth: 15,
                            maxHeight: 15,
                            child: _Pop(
                              ms: 350,
                              child: Container(
                                width: 15,
                                height: 15,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: Alignment(-0.36, -0.4),
                                    radius: 0.976,
                                    colors: [Color(0xFFB6EC6A), _green],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _feedback(_Fb fb) {
    final body = Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fb.ok ? const Color(0xFFFFD640) : _red,
          ),
          child: Text(
            fb.ok ? '★' : '!',
            style: _f(
              17,
              w: FontWeight.w700,
              color: fb.ok ? const Color(0xFFA06A00) : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            fb.text,
            style: _f(
              15,
              w: FontWeight.w600,
              h: 1.25,
              color: fb.ok ? Colors.white : _redText,
            ),
          ),
        ),
      ],
    );
    final box = fb.ok
        // The green banner art carries its own star badge on the left.
        ? AspectRatio(
            aspectRatio: _kFbGoodRatio,
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(_kFbGood, fit: BoxFit.fill),
                  ),
                  Positioned(
                    left: c.maxWidth * 0.22,
                    right: c.maxWidth * 0.05,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fb.text,
                        maxLines: 2,
                        style: _f(
                          c.maxHeight * 0.22,
                          w: FontWeight.w700,
                          h: 1.15,
                          color: Colors.white,
                          sh: const [
                            Shadow(
                              color: Color(0x80205A08),
                              offset: Offset(0, 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EE),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E781E14),
                  offset: Offset(0, 8),
                  blurRadius: 18,
                ),
              ],
            ),
            foregroundDecoration: const _DashedBorder(_red, 3, 18),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            child: body,
          );
    return _Rise(key: ValueKey('gdt-fb-$_fbId'), child: box);
  }

  /// What you learned and the summary: the tree this session grew stays
  /// planted in the garden, still swaying and shedding, under a soft dark
  /// wash so the panels stand out. Same shape for both screens, so the wash
  /// carries straight over from one to the other.
  Widget _endScene(Widget panels) {
    final tree = _d.trees[math.min(_stage, _d.trees.length - 1)];
    final bugs = _d.insects[math.min(_stage, _d.insects.length - 1)];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: _kTreeRect,
          child: IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _GroundShadowPainter()),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _InsectsPainter(_time, bugs.$1, bugs.$2, false),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: _kTreeW,
                  child: _TreeImage(tree, width: _kTreeW, sway: _time),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FallingLeavesPainter(_time, _shed, _canopyReady),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _InsectsPainter(_time, bugs.$1, bugs.$2, true),
                  ),
                ),
              ],
            ),
          ),
        ),
        // The wash reaches past the stage to every screen edge.
        Positioned(
          left: -2000,
          top: -2000,
          right: -2000,
          bottom: -2000,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _exitCtl,
              builder: (context, dim) =>
                  Opacity(opacity: 1 - _exitCtl.value, child: dim),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, v, _) =>
                    ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.35 * v)),
              ),
            ),
          ),
        ),
        Positioned.fill(child: panels),
      ],
    );
  }

  /// How far along its session a tree stage is: 0 first, 1 fully grown.
  double _growthOf(String tree) =>
      _d.trees.indexOf(tree).clamp(0, _d.trees.length) / (_d.trees.length - 1);

  Widget _buildTree() {
    return AnimatedBuilder(
      animation: _fx,
      builder: (context, _) {
        final e = _fx.value * 3.2;
        final flashing = _flash;
        final cur = _d.trees[math.min(_stage, _d.trees.length - 1)];
        final bugs = _d.insects[math.min(_stage, _d.insects.length - 1)];
        final hasBugs = bugs.$1 + bugs.$2 > 0;
        final curOp = !flashing || e < .55
            ? 1.0
            : const Cubic(
                0.22,
                0.7,
                0.25,
                1,
              ).transform(((e - .55) / 1.4).clamp(0.0, 1.0));
        final prevOp = e < .55
            ? 1.0
            : 1 -
                  const Cubic(
                    0.4,
                    0,
                    0.6,
                    1,
                  ).transform(((e - .55) / 1.1).clamp(0.0, 1.0));
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _GroundShadowPainter()),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _HoverGlowPainter(
                    _treeHover,
                    _time,
                    const Offset(0.5, 0.38),
                    0.62,
                    const Color(0xFFFFE27A),
                  ),
                ),
              ),
            ),
            if (hasBugs)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _InsectsPainter(_time, bugs.$1, bugs.$2, false),
                  ),
                ),
              ),
            if (_burst)
              Positioned.fill(child: CustomPaint(painter: _GlowPainter(e))),
            if (_prevTree != null)
              Positioned(
                key: const ValueKey('prev'),
                left: 0,
                bottom: 0,
                width: _kTreeW,
                child: _TreeImage(
                  _prevTree!,
                  width: _kTreeW,
                  light: flashing ? e : null,
                  sway: _time,
                  opacity: prevOp,
                ),
              ),
            Positioned(
              key: const ValueKey('cur'),
              left: 0,
              bottom: 0,
              width: _kTreeW,
              child: _TreeImage(
                cur,
                key: const ValueKey('gdt-tree'),
                width: _kTreeW,
                light: flashing ? e : null,
                sway: _time,
                opacity: curOp,
              ),
            ),
            if (_burst || flashing)
              Positioned.fill(
                child: CustomPaint(
                  painter: _FlashPainter(e, motes: _burst, flash: flashing),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FallingLeavesPainter(_time, _shed, _canopyReady),
                ),
              ),
            ),
            if (hasBugs)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _InsectsPainter(_time, bugs.$1, bugs.$2, true),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBin() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            SizedBox(
              width: 94,
              height: 96,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _BinShadowPainter()),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _HoverGlowPainter(
                          _binHover,
                          _time,
                          const Offset(0.47, 0.5),
                          0.95,
                          const Color(0xFFB8F27A),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -4,
                    bottom: 6,
                    width: 94,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_binCtl, _binHover]),
                      builder: (context, bin) {
                        // Hovered: lifts a little, ready to catch.
                        final lift =
                            1 +
                            0.08 *
                                Curves.easeOutBack.transform(_binHover.value);
                        if (!_binCtl.isAnimating) {
                          return Transform.scale(
                            scale: lift,
                            alignment: Alignment.bottomCenter,
                            child: bin,
                          );
                        }
                        final d = _binCtl.value * 0.9;
                        // Squash on impact, spring back, wobble to rest.
                        final ramp = math.min(d / 0.05, 1.0);
                        final sy =
                            1 -
                            0.13 * ramp * math.exp(-5 * d) * math.cos(16 * d);
                        final sx = 1 + (1 - sy) * 0.7;
                        final rot = 0.08 * math.exp(-4 * d) * math.sin(13 * d);
                        return Transform(
                          alignment: Alignment.bottomCenter,
                          transform: Matrix4.identity()
                            ..rotateZ(rot)
                            ..scaleByDouble(sx, sy, 1, 1),
                          child: bin,
                        );
                      },
                      child: Image.asset(_kBin, width: 94),
                    ),
                  ),
                  Positioned(
                    left: 44,
                    top: 4,
                    child: IgnorePointer(
                      child: CustomPaint(painter: _BinBurstPainter(_binCtl)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xE6FFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Bin',
                style: _f(
                  12,
                  w: FontWeight.w700,
                  color: const Color(0xFF14537F),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardFace(int i) {
    final c = _d.cards[i];
    final picked = _sel == i;
    final label = Text(
      c.text,
      textAlign: TextAlign.center,
      overflow: _d.fixedText ? TextOverflow.clip : null,
      style: _f(
        _d.fixedText ? 9.5 : 10.5,
        w: FontWeight.w600,
        h: _d.fixedText ? 1.15 : 1.1,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFCFE0BB), width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              const BoxShadow(
                color: Color(0x331F420E),
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
              if (picked)
                const BoxShadow(
                  color: Color(0x66E09C00),
                  offset: Offset(0, 4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8EC),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  c.image,
                  width: double.infinity,
                  height: 58,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 3),
              if (_d.fixedText)
                SizedBox(
                  height: 36,
                  child: ClipRect(child: Center(child: label)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 26),
                  child: Center(child: label),
                ),
            ],
          ),
        ),
        if (picked)
          Positioned(
            left: -1,
            right: -1,
            top: -1,
            bottom: -1,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFCC2F), width: 3),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(int i) {
    final l = _lifts[i];
    final rise = _enter(
      0.4 + i * 0.09,
      0.62 + i * 0.09,
      const Cubic(0.34, 1.3, 0.64, 1),
    );
    return Positioned(
      key: ValueKey('gdt-card-${_d.cards[i].id}'),
      left: _kHomeX[i],
      top: _kHomeY,
      width: _kCardW,
      child: _arrive(
        rise,
        dy: 130,
        Listener(
          onPointerDown: (e) => _down(i, e),
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(l.off.dx, l.off.dy, 0, 1)
              ..rotateZ(l.rot)
              ..scaleByDouble(l.scale, l.scale, 1, 1),
            child: Opacity(opacity: l.op.clamp(0.0, 1.0), child: _cardFace(i)),
          ),
        ),
      ),
    );
  }

  Widget _buildPlay(double shift) => AnimatedBuilder(
    animation: Listenable.merge([_playCtl, _backCtl]),
    builder: (context, _) =>
        IgnorePointer(ignoring: _enterU < 1, child: _playStack(shift)),
  );

  /// A piece sliding [dy] and scaling up from [scale0] as it arrives.
  Widget _arrive(double p, Widget child, {double dy = 0, double scale0 = 1}) =>
      Opacity(
        opacity: p.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, dy * (1 - p)),
          child: Transform.scale(
            scale: scale0 + (1 - scale0) * p,
            child: child,
          ),
        ),
      );

  Widget _playStack(double shift) {
    const back = Cubic(0.34, 1.4, 0.64, 1);
    final hand = [
      for (var i = 0; i < _d.cards.length; i++)
        if (!_sorted.contains(i) && i != _top) i,
      if (_top != null && !_sorted.contains(_top)) _top!,
    ];
    final done = _screen == _Screen.done;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!done)
          Positioned(
            top: shift,
            left: 0,
            right: 0,
            child: _arrive(
              _enter(0, 0.35, Curves.easeOutCubic),
              dy: -110,
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 64,
                      child: _ImageButton(
                        key: const ValueKey('gdt-back'),
                        up: _kBtnBack,
                        down: _kBtnBackDown,
                        onTap: _goBack,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _meter()),
                    const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: 64,
                      // Muted: the button goes grey.
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          _sound ? _kIdentity : _kGreyscale,
                        ),
                        child: _ImageButton(
                          key: const ValueKey('gdt-sound'),
                          up: _kBtnSound,
                          down: _kBtnSoundDown,
                          onTap: () => setState(() => _sound = !_sound),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned.fromRect(
          key: const ValueKey('gdt-tree-slot'),
          rect: _kTreeRect,
          child: GestureDetector(
            key: const ValueKey('gdt-tree-zone'),
            behavior: HitTestBehavior.opaque,
            onTap: done ? null : () => _tapTarget(_Target.tree),
            // From How to play the tree fades in with the garden, in place
            // of the start art's painted tree.
            child: Opacity(
              opacity: _fromHow ? _dissolve : _enter(0, 0.35, Curves.easeOut),
              child: _buildTree(),
            ),
          ),
        ),
        if (!done)
          Positioned(
            left: _kBinRect.left,
            top: _kBinRect.top,
            width: _kBinRect.width,
            child: GestureDetector(
              key: const ValueKey('gdt-bin'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _tapTarget(_Target.bin),
              child: _arrive(
                _enter(0.25, 0.55, back),
                dy: 20,
                scale0: 0.3,
                _buildBin(),
              ),
            ),
          ),
        // Hint plank and messages sit above the tree and bin.
        if (!done)
          Positioned(
            top: 84 + shift,
            left: 0,
            right: 0,
            child: Center(
              child: _arrive(
                _enter(0.12, 0.45, back),
                scale0: 0.6,
                // Steps aside while a message shows in its place.
                AnimatedOpacity(
                  opacity: _fb == null ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: SizedBox(
                    width: 330,
                    child: AspectRatio(
                      aspectRatio: _kHintPlankRatio,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(_kHintPlank, fit: BoxFit.fill),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 12,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Drag each card to the tree or the bin',
                                  style: _f(
                                    15,
                                    w: FontWeight.w700,
                                    color: const Color(0xFF5A2A0E),
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
              ),
            ),
          ),
        if (_fb != null && !done)
          Positioned(
            top: 80 + shift,
            left: 10,
            right: 10,
            child: _feedback(_fb!),
          ),
        if (!_trayGone && !done)
          Positioned(
            left: 0,
            top: _kTrayTop,
            width: _kW,
            height: 152,
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(
                  0,
                  _trayY + 170 * (1 - _enter(0.3, 0.62, Curves.easeOutCubic)),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFCFE0BB),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x381F420E),
                        offset: Offset(0, 8),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.only(top: 3),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.elliptical(18, 15),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!done)
          for (final i in hand) _card(i),
        if (done) ..._doneOverlay(shift),
      ],
    );
  }

  // ---- complete ----

  /// MUMTAZ! over the crown and the complete sign below the roots, laid
  /// over the finished garden.
  List<Widget> _doneOverlay(double shift) => [
    Positioned(
      top: 70 + shift,
      left: 0,
      right: 0,
      child: Center(
        child: _Pop(
          ms: 500,
          child: Text(
            'MUMTAZ!',
            style: _f(
              46,
              w: FontWeight.w700,
              color: _gold,
              ls: 0.92,
              sh: const [
                Shadow(color: _green, offset: Offset(0, 4)),
                Shadow(
                  color: Color(0x4D000000),
                  offset: Offset(0, 8),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    Positioned(
      top: 598,
      left: 20,
      right: 20,
      child: _Pop(
        ms: 600,
        child: Column(
          children: [
            SizedBox(
              width: 330,
              child: AspectRatio(
                aspectRatio: _kDoneBoardRatio,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(_kDoneBoard, fit: BoxFit.fill),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _d.doneTitle,
                                textAlign: TextAlign.center,
                                style: _f(
                                  22,
                                  w: FontWeight.w700,
                                  color: _gold,
                                  h: 1.15,
                                  sh: const [
                                    Shadow(
                                      color: Color(0xFF5A2E0E),
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 250,
                                child: Text(
                                  _d.doneSub,
                                  textAlign: TextAlign.center,
                                  style: _f(15, color: Colors.white, h: 1.3),
                                ),
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
            const SizedBox(height: 12),
            SizedBox(
              width: 256,
              child: AspectRatio(
                aspectRatio: _kBtnGreenRatio,
                child: _ImageButton(
                  key: const ValueKey('gdt-learned'),
                  up: _kBtnGreen,
                  down: _kBtnGreenDown,
                  onTap: _goRecap,
                  label: _outlined(
                    'What you learned',
                    _f(24, w: FontWeight.w700, color: Colors.white),
                    const Color(0xFF1E5E0C),
                    5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ];

  // ---- summary ----

  int get _stars => _errors == 0
      ? 3
      : _errors <= 2
      ? 2
      : 1;

  String get _sortTime {
    final s = _clock.elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _statTile(Widget icon, String value, String label) => AspectRatio(
    aspectRatio: _kSumTileRatio,
    child: Stack(
      children: [
        Positioned.fill(child: Image.asset(_kSumTile, fit: BoxFit.fill)),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
            child: Row(
              children: [
                SizedBox.square(dimension: 34, child: Center(child: icon)),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(value, style: _f(20, w: FontWeight.w700, h: 1.05)),
                        SizedBox(
                          width: 92,
                          child: Text(
                            label,
                            maxLines: 2,
                            style: _f(
                              11,
                              w: FontWeight.w600,
                              color: _green,
                              h: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSummary() {
    final good = _d.cards.where((c) => c.good).length;
    final bad = _d.cards.length - good;
    final stars = _stars;
    final cheer = switch (stars) {
      3 => 'Perfect sorting!',
      2 => 'Great sorting!',
      _ => 'Good effort, keep practising!',
    };
    Widget star(int i) {
      final on = i < stars;
      final big = i == 1;
      return Transform.translate(
        offset: Offset(0, big ? -8 : 0),
        child: _Pop(
          key: ValueKey('gdt-star-$i'),
          ms: 450 + i * 180,
          child: SizedBox(
            width: big ? 74 : 58,
            child: AspectRatio(
              aspectRatio: _kSumStarRatio,
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(on ? _kIdentity : _kGreyscale),
                child: Image.asset(_kSumStar, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }

    // Shrinks to fit on short screens instead of overflowing.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: LayoutBuilder(
        builder: (context, c) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: c.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SizedBox(
                      width: 300,
                      child: AspectRatio(
                        aspectRatio: _kSumTitleRatio,
                        child: LayoutBuilder(
                          builder: (context, b) => Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  _kSumTitle,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              // The name on the wood above the strip.
                              Positioned(
                                left: b.maxWidth * 0.1,
                                right: b.maxWidth * 0.1,
                                top: b.maxHeight * 0.13,
                                height: b.maxHeight * 0.3,
                                child: FittedBox(
                                  child: Text(
                                    'Session Summary',
                                    style: _f(
                                      26,
                                      w: FontWeight.w700,
                                      color: _gold,
                                      sh: const [
                                        Shadow(
                                          color: Color(0xFF4A2408),
                                          offset: Offset(0, 2.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // The session in the cream strip.
                              Positioned(
                                left: b.maxWidth * 0.15,
                                right: b.maxWidth * 0.15,
                                top: b.maxHeight * 0.5,
                                height: b.maxHeight * 0.2,
                                child: FittedBox(
                                  child: Text(
                                    _d.tag,
                                    style: _f(
                                      14,
                                      w: FontWeight.w700,
                                      color: _brownText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      star(0),
                      const SizedBox(width: 6),
                      star(1),
                      const SizedBox(width: 6),
                      star(2),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cheer,
                    textAlign: TextAlign.center,
                    style: _f(
                      20,
                      w: FontWeight.w700,
                      color: Colors.white,
                      sh: const [
                        Shadow(color: _greenDark, offset: Offset(0, 2)),
                        Shadow(
                          color: Color(0x4D000000),
                          offset: Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _statTile(
                          Image.asset(_d.doneTree, fit: BoxFit.contain),
                          '$good',
                          'Good deeds grew the tree',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statTile(
                          Image.asset(_kBin, width: 30, fit: BoxFit.contain),
                          '$bad',
                          'Wrong actions in the bin',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _statTile(
                          Text(
                            _errors == 0 ? '✓' : '!',
                            style: _f(
                              20,
                              w: FontWeight.w700,
                              color: _errors == 0 ? _green : _red,
                            ),
                          ),
                          '$_errors',
                          _errors == 1 ? 'Mistake' : 'Mistakes',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statTile(
                          Text(
                            '⏱',
                            style: _f(18, color: const Color(0xFF1C6EA8)),
                          ),
                          _sortTime,
                          'Time to sort',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox(
                      width: 140,
                      child: AspectRatio(
                        aspectRatio: _kSumXpRatio,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(_kSumXp, fit: BoxFit.fill),
                            ),
                            Center(
                              child: _outlined(
                                '+${widget.xp} XP',
                                _f(20, w: FontWeight.w700, color: Colors.white),
                                const Color(0xFFB45F00),
                                4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: _kSumCardRatio,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(_kSumCard, fit: BoxFit.fill),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 280,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'REMEMBER',
                                      style: _f(
                                        12,
                                        w: FontWeight.w700,
                                        color: _green,
                                        ls: 1.44,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _d.remember,
                                      textAlign: TextAlign.center,
                                      style: _f(15, h: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _artButton(
                    const ValueKey('gdt-finish'),
                    'Finish',
                    blue: false,
                    width: 250,
                    onTap: _finish,
                  ),
                  const SizedBox(height: 9),
                  _artButton(
                    const ValueKey('gdt-summary-again'),
                    'Play Again',
                    blue: true,
                    width: 230,
                    onTap: _playAgain,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- recap ----

  /// One of the what-you-learned panels: its art with the tab's label and
  /// the cards listed inside, laid out in the art's own proportions.
  Widget _recapPanel(bool good, double width) {
    final art = good ? _kWylGood : _kWylBad;
    // Art size, tab label box and content box, in art px (1000 wide).
    final artH = good ? 642.0 : 559.0;
    final tab = good
        ? const Rect.fromLTRB(360, 28, 770, 126)
        : const Rect.fromLTRB(345, 20, 780, 120);
    final body = good
        ? const Rect.fromLTRB(90, 152, 910, 588)
        : const Rect.fromLTRB(60, 142, 940, 522);
    final k = width / 1000;
    final cards = _d.cards.where((c) => c.good == good).toList();
    final edge = good ? const Color(0xFF1F6B12) : const Color(0xFFA3171C);
    return SizedBox(
      width: width,
      height: artH * k,
      child: Stack(
        children: [
          Positioned.fill(child: Image.asset(art, fit: BoxFit.fill)),
          Positioned.fromRect(
            rect: Rect.fromLTRB(
              tab.left * k,
              tab.top * k,
              tab.right * k,
              tab.bottom * k,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _outlined(
                  good ? 'Good Deeds' : 'Not Good Deeds',
                  _f(19, w: FontWeight.w700, color: Colors.white),
                  edge,
                  4,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: Rect.fromLTRB(
              body.left * k,
              body.top * k,
              body.right * k,
              body.bottom * k,
            ),
            child: Column(
              children: [
                for (final (n, c) in cards.indexed) ...[
                  if (n > 0)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 56),
                      color: good
                          ? const Color(0x33589E2F)
                          : const Color(0x33D9534A),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: good
                                ? const Color(0xFFEAF6DC)
                                : const Color(0xFFFCE8E6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(c.image, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c.text,
                            maxLines: 2,
                            style: _f(
                              14.5,
                              w: FontWeight.w600,
                              color: const Color(0xFF2B2B2B),
                              h: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecap(double shift) {
    return Padding(
      padding: EdgeInsets.only(top: shift + 8, bottom: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: _kW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pop(
                ms: 420,
                child: SizedBox(
                  width: 340,
                  child: AspectRatio(
                    aspectRatio: 1000 / 323,
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(_kWylTitle, fit: BoxFit.fill),
                          ),
                          // Inside the plank, clear of its ends and leaves.
                          Positioned(
                            left: c.maxWidth * 0.13,
                            right: c.maxWidth * 0.13,
                            top: c.maxHeight * 0.36,
                            bottom: c.maxHeight * 0.2,
                            child: FittedBox(
                              child: _signTitle('What you learned'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _Pop(ms: 560, child: _recapPanel(true, 330)),
              const SizedBox(height: 6),
              _Pop(ms: 700, child: _recapPanel(false, 330)),
              const SizedBox(height: 18),
              _Pop(
                ms: 860,
                child: _artButton(
                  const ValueKey('gdt-again'),
                  'Play Again',
                  blue: true,
                  width: 250,
                  onTap: _playAgain,
                ),
              ),
              const SizedBox(height: 12),
              _Pop(
                ms: 960,
                child: _artButton(
                  const ValueKey('gdt-continue'),
                  'Continue',
                  blue: false,
                  width: 250,
                  onTap: _goSummary,
                ),
              ),
              const SizedBox(height: 18),
              _Pop(
                ms: 1060,
                child: SizedBox(
                  width: 310,
                  child: AspectRatio(
                    aspectRatio: 1000 / 243,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(_kWylPlank, fit: BoxFit.fill),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(44, 12, 44, 12),
                            child: Center(
                              child: Text(
                                _d.footer,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: _f(
                                  13.5,
                                  w: FontWeight.w700,
                                  color: const Color(0xFF3A2410),
                                  h: 1.2,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

const List<double> _kIdentity = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];
const List<double> _kGreyscale = [
  .3, .59, .11, 0, 0, //
  .3, .59, .11, 0, 0, //
  .3, .59, .11, 0, 0, //
  0, 0, 0, .75, 0, //
];

class _StartLive {
  const _StartLive(this.shader, this.bg, this.under, this.sway);
  final ui.FragmentShader shader;
  final ui.Image bg;
  final ui.Image under;
  final ui.Image sway;
}

/// The start art, cover-fitted and bottom-aligned like the still image,
/// with its corner plants swaying.
class _StartBgPainter extends CustomPainter {
  _StartBgPainter(this.live, this.time) : super(repaint: time);
  final _StartLive live;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final sc = math.max(
      size.width / _kStartBgSize.width,
      size.height / _kStartBgSize.height,
    );
    final art = _kStartBgSize * sc;
    canvas.save();
    canvas.translate((size.width - art.width) / 2, size.height - art.height);
    live.shader
      ..setFloat(0, art.width)
      ..setFloat(1, art.height)
      ..setFloat(2, time.value)
      ..setImageSampler(0, live.bg)
      ..setImageSampler(1, live.under)
      ..setImageSampler(2, live.sway);
    canvas.drawRect(Offset.zero & art, Paint()..shader = live.shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StartBgPainter old) => old.live != live;
}

/// A soft glow blooming behind a drop target while a card hovers over it,
/// breathing gently. [at] is the centre as a fraction of the box and
/// [radius] a fraction of its height.
class _HoverGlowPainter extends CustomPainter {
  _HoverGlowPainter(this.hover, this.time, this.at, this.radius, this.color)
    : super(repaint: Listenable.merge([hover, time]));
  final Animation<double> hover;
  final ValueListenable<double> time;
  final Offset at;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeOut.transform(hover.value);
    if (v <= 0) return;
    final pulse = 0.85 + 0.15 * math.sin(time.value * 4);
    final c = Offset(size.width * at.dx, size.height * at.dy);
    final r = size.height * radius * (0.9 + 0.1 * v);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            color.withValues(alpha: 0.75 * v * pulse),
            color.withValues(alpha: 0.3 * v * pulse),
            color.withValues(alpha: 0),
          ],
          const [0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_HoverGlowPainter old) => false;
}

/// Dust puffing from the bin's rim and recycle sparks and paper bits
/// bursting up and falling back, drawn around the rim.
class _BinBurstPainter extends CustomPainter {
  _BinBurstPainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;

  static const _colors = [
    Color(0xFF6DD13A),
    Color(0xFF3FAE3A),
    Color(0xFFFFFFFF),
    Color(0xFF4FB3F6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = anim.value;
    if (v <= 0 || v >= 1) return;
    final t = v * 0.9;

    // Dust ring.
    final puff = (t / 0.45).clamp(0.0, 1.0);
    if (puff < 1) {
      final e = Curves.easeOutCubic.transform(puff);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, 4),
          width: 20 + 70 * e,
          height: 8 + 22 * e,
        ),
        Paint()
          ..color = Color.fromRGBO(240, 236, 220, 0.55 * (1 - puff))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Sparks and paper bits.
    final fade = (1 - ((t - 0.45) / 0.45).clamp(0.0, 1.0));
    final r = math.Random(7);
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + (r.nextDouble() - 0.5) * 2.1;
      final sp = 70 + r.nextDouble() * 60;
      final pos = Offset(
        math.cos(a) * sp * t,
        math.sin(a) * sp * t + 0.5 * 240 * t * t,
      );
      final col = _colors[i % _colors.length].withValues(alpha: fade);
      final sz = 2.4 + r.nextDouble() * 2.2;
      if (i % 3 == 0) {
        // A scrap of paper, tumbling.
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(t * (6 + i));
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: sz * 1.8, height: sz),
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.95 * fade),
        );
        canvas.restore();
      } else {
        canvas.drawCircle(pos, sz, Paint()..color = col);
        canvas.drawCircle(
          pos,
          sz,
          Paint()
            ..color = Color.fromRGBO(30, 80, 20, 0.35 * fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BinBurstPainter old) => false;
}

/// A five-petal flower badge behind a step number.
class _NumberFlowerPainter extends CustomPainter {
  const _NumberFlowerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final flower = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      flower.addOval(
        Rect.fromCircle(
          center: c + Offset(math.cos(a), math.sin(a)) * r * 0.45,
          radius: r * 0.5,
        ),
      );
    }
    flower.addOval(Rect.fromCircle(center: c, radius: r * 0.55));
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    canvas.drawPath(flower.shift(Offset(0, r * 0.08)), Paint()..color = dark);
    canvas.drawPath(
      flower,
      Paint()
        ..shader = ui.Gradient.radial(c - Offset(r * .3, r * .3), r * 1.3, [
          Color.lerp(color, Colors.white, 0.35)!,
          color,
        ]),
    );
    canvas.drawPath(
      flower,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..color = dark,
    );
  }

  @override
  bool shouldRepaint(_NumberFlowerPainter old) => old.color != color;
}

/// A chunky curved arrow with a dark rim.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shaft = Path()
      ..moveTo(w * .1, h * .62)
      ..quadraticBezierTo(w * .45, h * .2, w * .7, h * .42);
    final head = Path()
      ..moveTo(w * .92, h * .5)
      ..lineTo(w * .6, h * .22)
      ..lineTo(w * .62, h * .66)
      ..close();
    final dark = Color.lerp(color, Colors.black, 0.4)!;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      shaft,
      line
        ..color = dark
        ..strokeWidth = h * .24,
    );
    canvas.drawPath(
      head,
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = h * .1,
    );
    canvas.drawPath(
      shaft,
      line
        ..color = color
        ..strokeWidth = h * .15,
    );
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

/// Little gold sparkle strokes around a picture.
class _SparkPainter extends CustomPainter {
  const _SparkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFFC928)
      ..strokeWidth = size.shortestSide * 0.05
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width * .82, size.height * .18);
    for (final a in [-1.9, -1.2, -0.5]) {
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + d * size.shortestSide * .12,
        c + d * size.shortestSide * .3,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => false;
}

/// A painted button: shows [down] while held (or dims [up] when there is no
/// pressed art) and sinks a little.
class _ImageButton extends StatefulWidget {
  const _ImageButton({
    super.key,
    required this.up,
    this.down,
    required this.onTap,
    this.label,
  });

  final String up;
  final String? down;
  final VoidCallback onTap;

  /// Text laid over the art, fitted inside its middle.
  final Widget? label;

  @override
  State<_ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<_ImageButton> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(
      _held && widget.down != null ? widget.down! : widget.up,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    final label = widget.label;
    final img = label == null
        ? art
        : Stack(
            alignment: Alignment.center,
            children: [
              art,
              FractionallySizedBox(
                widthFactor: 0.7,
                heightFactor: 0.55,
                child: FittedBox(child: label),
              ),
            ],
          );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _held = true),
      onTapUp: (_) => setState(() => _held = false),
      onTapCancel: () => setState(() => _held = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _held ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: _held && widget.down == null
            ? ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  .82, 0, 0, 0, 0, //
                  0, .82, 0, 0, 0, //
                  0, 0, .82, 0, 0, //
                  0, 0, 0, 1, 0, //
                ]),
                child: img,
              )
            : img,
      ),
    );
  }
}

/// CSS `border: Npx dashed` on a rounded box.
class _DashedBorder extends Decoration {
  const _DashedBorder(this.color, this.width, this.radius);
  final Color color;
  final double width;
  final double radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedBorderPainter(this);
}

class _DashedBorderPainter extends BoxPainter {
  _DashedBorderPainter(this.d);
  final _DashedBorder d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = (offset & cfg.size!).deflate(d.width / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(d.radius - d.width / 2)),
      );
    final dash = d.width * 3;
    final gap = d.width * 2;
    final paint = Paint()
      ..color = d.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = d.width;
    for (final m in path.computeMetrics()) {
      for (var s = 0.0; s < m.length; s += dash + gap) {
        canvas.drawPath(m.extractPath(s, math.min(s + dash, m.length)), paint);
      }
    }
  }
}

/// `gdt-pop`: scale .6 -> 1.08 -> 1 while fading in.
class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.ms, required this.child});
  final int ms;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: ms),
    builder: (_, p, child) => Opacity(
      opacity: _kf(p, [0, .6, 1], [0, 1, 1], _easeOut),
      child: Transform.scale(
        scale: _kf(p, [0, .6, 1], [.6, 1.08, 1], _easeOut),
        child: child,
      ),
    ),
    child: child,
  );
}

/// `gdt-rise`: slide up 14px while fading in.
class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 250),
    curve: _easeOut,
    builder: (_, p, child) => Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, 14 * (1 - p)), child: child),
    ),
    child: child,
  );
}

class _Shadow {
  const _Shadow(this.dy, this.blur, this.color);
  final double dy;
  final double blur;
  final Color color;
}

/// A tree with its CSS `drop-shadow`, optionally mid `gdt-lightup`.
class _TreeImage extends StatelessWidget {
  const _TreeImage(
    this.asset, {
    super.key,
    required this.width,
    this.light,
    this.opacity = 1,
    this.sway,
  });

  final String asset;
  final double width;

  /// Seconds into `gdt-lightup`, or null when resting.
  final double? light;
  final double opacity;

  /// Game clock driving the crown's breeze; null holds the tree still.
  final ValueListenable<double>? sway;

  @override
  Widget build(BuildContext context) {
    // Resting, the planted tree casts no silhouette; its ground shadow is
    // [_GroundShadowPainter]. The glow grows out of this during light-up.
    const sh = _Shadow(0, 0, Color(0x00FFFAE1));
    // gdt-lightup keyframes over 3s, ease-out per segment:
    // drop-shadow offset/blur/colour, brightness, saturate.
    var dy = sh.dy;
    var blur = sh.blur;
    var color = sh.color;
    var b = 1.0;
    var s = 1.0;
    final e = light;
    if (e != null && e < 3) {
      const at = [0.0, .14, .38, .64, 1.0];
      final p = e / 3;
      dy = _kf(p, at, [sh.dy, 0, 0, 0, sh.dy], _easeOut);
      blur = _kf(p, at, [sh.blur, 70, 80, 50, sh.blur], _easeOut);
      b = _kf(p, at, [1, 9, 7, 3, 1], _easeOut);
      s = _kf(p, at, [1, 0, .05, .45, 1], _easeOut);
      final cs = [
        sh.color,
        _rgba(255, 250, 225, 1),
        _rgba(255, 248, 215, 1),
        _rgba(255, 244, 190, .85),
        sh.color,
      ];
      var i = 1;
      while (i < at.length - 1 && p > at[i]) {
        i++;
      }
      final u = ((p - at[i - 1]) / (at[i] - at[i - 1])).clamp(0.0, 1.0);
      color = Color.lerp(cs[i - 1], cs[i], _easeOut.transform(u))!;
    }
    final img = Image.asset(asset, width: width, gaplessPlayback: true);
    Widget body = Stack(
      clipBehavior: Clip.none,
      children: [
        if (color.a > 0)
          Transform.translate(
            offset: Offset(0, dy),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: blur / 2,
                sigmaY: blur / 2,
                tileMode: TileMode.decal,
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                child: img,
              ),
            ),
          ),
        if (sway == null) img else _SwayTree(asset, width: width, time: sway!),
      ],
    );
    if (b != 1 || s != 1) {
      // saturate(s) then brightness(b), per the CSS filter spec.
      body = ColorFiltered(
        colorFilter: ColorFilter.matrix([
          b * (.213 + .787 * s),
          b * (.715 - .715 * s),
          b * (.072 - .072 * s),
          0,
          0,
          b * (.213 - .213 * s),
          b * (.715 + .285 * s),
          b * (.072 - .072 * s),
          0,
          0,
          b * (.213 - .213 * s),
          b * (.715 - .715 * s),
          b * (.072 + .928 * s),
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: body,
      );
    }
    return RepaintBoundary(
      child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: body),
    );
  }
}

const String _kSwayShader = 'shaders/good_deed_tree_sway.frag';
final Future<ui.FragmentProgram> _swayProgram = ui.FragmentProgram.fromAsset(
  _kSwayShader,
);
final Map<String, Future<ui.Image>> _swayImages = {};

/// Each tree's leaf mask (blossoms and fruit excluded), baked from its art.
String _leavesMask(String tree) => tree.replaceFirst('.png', '_leaves.png');

/// Only Session 2's final tree bears fruit; it swings from baked stem
/// pivots over a copy of the tree with the fruit painted out.
const String _kFruitTree = '$_kA/s2_tree_3.png';
String _fruitMap(String tree) => tree.replaceFirst('.png', '_fruit.png');
String _fruitUnder(String tree) => tree.replaceFirst('.png', '_under.png');

Future<ui.Image> _swayImage(String asset) =>
    _swayImages[asset] ??= rootBundle.load(asset).then((data) async {
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    });

/// The tree drawn through [_kSwayShader]: only its foliage moves in the
/// breeze; trunk and branches hold still. Shows the plain image until the shader is ready, or
/// for good where shaders aren't supported.
class _SwayTree extends StatefulWidget {
  const _SwayTree(this.asset, {required this.width, required this.time});
  final String asset;
  final double width;
  final ValueListenable<double> time;

  @override
  State<_SwayTree> createState() => _SwayTreeState();
}

class _SwayTreeState extends State<_SwayTree> {
  ui.FragmentShader? _shader;
  ui.Image? _image;
  ui.Image? _mask;
  ui.Image? _under;
  ui.Image? _fruit;
  String? _imageFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SwayTree old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) _load();
  }

  Future<void> _load() async {
    final asset = widget.asset;
    try {
      final program = await _swayProgram;
      final image = await _swayImage(asset);
      final mask = await _swayImage(_leavesMask(asset));
      final fruity = asset == _kFruitTree;
      final under = fruity ? await _swayImage(_fruitUnder(asset)) : null;
      final fruit = fruity ? await _swayImage(_fruitMap(asset)) : null;
      if (!mounted || widget.asset != asset) return;
      setState(() {
        _shader ??= program.fragmentShader();
        _image = image;
        _mask = mask;
        _under = under;
        _fruit = fruit;
        _imageFor = asset;
      });
    } catch (_) {
      // Shaders unsupported here: the still tree stays.
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final image = _image;
    final mask = _mask;
    if (shader == null ||
        image == null ||
        mask == null ||
        _imageFor != widget.asset) {
      return Image.asset(
        widget.asset,
        width: widget.width,
        gaplessPlayback: true,
      );
    }
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.width * image.height / image.width,
        child: CustomPaint(
          painter: _SwayPainter(
            shader,
            image,
            mask,
            _under,
            _fruit,
            widget.time,
          ),
        ),
      ),
    );
  }
}

/// Where leaves can break off a tree, the colour of the leaf at each spot,
/// the ground line at the tree's roots, and how leafy the tree is — read
/// once from the art.
class _Canopy {
  const _Canopy(this.spots, this.colors, this.ground, this.leafiness);
  final List<Offset> spots;
  final List<Color> colors;
  final double ground;

  /// 0 for a bare tree up to 1 for a full crown; sets how hard leaves fall.
  final double leafiness;
}

final Map<String, Future<_Canopy>> _canopies = {};

Future<_Canopy> _canopyOf(String asset, ui.Image image, ui.Image mask) =>
    _canopies[asset] ??= () async {
      final px = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      final mk = (await mask.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      final w = image.width;
      final h = image.height;
      final spots = <Offset>[];
      final colors = <Color>[];
      var ground = 0;
      var leaf = 0;
      var cells = 0;
      for (var y = 0; y < h; y += 3) {
        for (var x = 0; x < w; x += 3) {
          final i = (y * w + x) * 4;
          cells++;
          if (px.getUint8(i + 3) > 128) ground = y;
          if (mk.getUint8(i) > 128) leaf++;
          if (x % 9 != 0 || y % 9 != 0 || mk.getUint8(i) < 230) continue;
          final r = px.getUint8(i);
          final g = px.getUint8(i + 1);
          final b = px.getUint8(i + 2);
          // Leaf faces only, not their dark outlines.
          if (g < 110 || g < r || g < b) continue;
          spots.add(Offset(x / w, y / h));
          colors.add(Color.fromARGB(255, r, g, b));
        }
      }
      // A full crown covers about 30% of the art.
      final leafiness = (leaf / cells / 0.3).clamp(0.0, 1.0);
      return _Canopy(spots, colors, ground / h, leafiness);
    }();

/// A tree stage and the clock time it started standing.
class _Shed {
  const _Shed(this.start, this.asset, this.growth);
  final double start;
  final String asset;

  /// Stage in the session, 0..1: a grown tree sheds much harder.
  final double growth;
}

/// Leaves breaking off the crown and drifting down: each glides side to
/// side like a real leaf, tilting into every swing and flipping as it
/// tumbles, drifts with the breeze, then settles by the roots for 30 s and
/// fades. A young tree with a few leaves drops one now and then; the fuller
/// the crown and the later the stage, the more leaves fall. Every leaf
/// belongs to the tree stage that was standing when it broke off
/// ([history]), so leaves already falling or lying carry on when the tree
/// grows. Tree-box coordinates.
class _FallingLeavesPainter extends CustomPainter {
  _FallingLeavesPainter(this.time, this.history, this.canopies)
    : super(repaint: time);
  final ValueListenable<double> time;
  final List<_Shed> history;
  final Map<String, _Canopy> canopies;

  static const int _maxSlots = 30;

  /// Longest a leaf is on screen: loosening, the longest fall, 30 s lying
  /// on the grass, and its fade.
  static const double _life = 45;

  _Shed? _standing(double at) {
    for (var j = history.length - 1; j >= 0; j--) {
      if (history[j].start <= at) return history[j];
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final k = size.width / 292;
    for (var i = 0; i < _maxSlots; i++) {
      final period = 6.5 + i * 0.6;
      final local = t + i * 2.3;
      // Every leaf this slot has dropped that is still falling or lying.
      for (var cycle = (local / period).floor(); ; cycle--) {
        final u = local - cycle * period;
        if (u > _life) break;
        final shed = _standing(t - u);
        if (shed == null) break;
        final canopy = canopies[shed.asset];
        if (canopy == null || canopy.spots.isEmpty) continue;
        // Fuller crown and later stage both shed more, steeply.
        final full = canopy.leafiness * (0.6 + 0.4 * shed.growth);
        final slots = 1 + (math.pow(full, 1.3) * (_maxSlots - 1)).round();
        if (i >= slots) continue;
        final rnd = math.Random(i * 7919 + cycle * 104729);
        // Some cycles stay on the branch, so the rhythm never repeats.
        if (rnd.nextDouble() < 0.55 - 0.52 * full) continue;
        final n = rnd.nextInt(canopy.spots.length);
        final spot = canopy.spots[n];
        final base = canopy.colors[n];
        final len = (13 + rnd.nextDouble() * 5) * k;
        final amp = (10 + rnd.nextDouble() * 12) * k;
        final om = 1.8 + rnd.nextDouble() * 0.9;
        final ph = rnd.nextDouble() * 2 * math.pi;
        final vy = (40 + rnd.nextDouble() * 18) * k;
        final drift = (4 + rnd.nextDouble() * 10) * k;
        final spin = 0.8 + rnd.nextDouble() * 1.4;
        final tilt = rnd.nextDouble() * math.pi;

        final x0 = spot.dx * size.width;
        final y0 = spot.dy * size.height;
        final groundY = (canopy.ground - rnd.nextDouble() * 0.03) * size.height;
        const detach = 0.35;
        final land = math.max(0.0, (groundY - y0) / vy);
        const rest = 30.0;
        const fade = 0.8;
        if (u > detach + land + rest + fade) continue;

        Offset at(double s) => Offset(
          x0 + amp * (math.sin(om * s + ph) - math.sin(ph)) + drift * s,
          y0 + vy * s + 3 * k * math.sin(2 * (om * s + ph)),
        );
        double rotAt(double s) => tilt + 0.7 * math.cos(om * s + ph);

        Offset pos;
        double rot;
        double sx;
        double sy;
        double op = 1;
        if (u < detach) {
          // Loosening on its twig.
          final q = u / detach;
          pos = at(0) + Offset(math.sin(u * 40) * 0.8 * k, 0);
          rot = rotAt(0) + math.sin(u * 30) * 0.15;
          sx = 0.7 + 0.3 * q;
          sy = sx;
          op = q;
        } else if (u < detach + land) {
          final f = u - detach;
          pos = at(f);
          rot = rotAt(f);
          final flip = math.cos(spin * f + ph);
          sx = 0.35 + 0.65 * flip.abs();
          sy = 1;
        } else {
          // Settled on the grass, seen edge-on; then gone.
          final r = u - detach - land;
          final q = (r / 0.25).clamp(0.0, 1.0);
          final end = rotAt(land);
          pos = Offset(at(land).dx, groundY);
          rot = end + (0.1 - end % math.pi) * q;
          sx = 1;
          sy = 1 - 0.5 * q;
          if (r > rest) op = 1 - (r - rest) / fade;
        }
        _leaf(canvas, pos, rot, sx, sy, len, base, op.clamp(0.0, 1.0));
      }
    }
  }

  void _leaf(
    Canvas canvas,
    Offset pos,
    double rot,
    double sx,
    double sy,
    double len,
    Color base,
    double op,
  ) {
    if (op <= 0) return;
    Color shade(double f) => Color.from(
      alpha: op,
      red: (base.r * f).clamp(0.0, 1.0),
      green: (base.g * f).clamp(0.0, 1.0),
      blue: (base.b * f).clamp(0.0, 1.0),
    );
    final hl = len / 2;
    final hw = len * 0.24;
    final body = Path()
      ..moveTo(-hl, 0)
      ..quadraticBezierTo(-hl * 0.1, -hw * 2, hl, 0)
      ..quadraticBezierTo(-hl * 0.1, hw * 2, -hl, 0)
      ..close();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rot);
    canvas.scale(sx, sy);
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, -hw), Offset(0, hw), [
          shade(1.12),
          shade(0.82),
        ]),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-hl, 0),
      Offset(hl * 0.75, 0),
      line
        ..color = shade(0.6)
        ..strokeWidth = len * 0.05,
    );
    canvas.drawLine(
      Offset(-hl, 0),
      Offset(-hl - len * 0.12, len * 0.04),
      line
        ..color = shade(0.45)
        ..strokeWidth = len * 0.07,
    );
    canvas.drawPath(
      body,
      line
        ..color = shade(0.42)
        ..strokeWidth = len * 0.07,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FallingLeavesPainter old) => true;
}

class _SwayPainter extends CustomPainter {
  _SwayPainter(
    this.shader,
    this.image,
    this.mask,
    this.under,
    this.fruit,
    this.time,
  ) : super(repaint: time);
  final ui.FragmentShader shader;
  final ui.Image image;
  final ui.Image mask;
  final ui.Image? under;
  final ui.Image? fruit;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, fruit == null ? 0 : 1)
      ..setImageSampler(0, image)
      ..setImageSampler(1, mask)
      ..setImageSampler(2, under ?? image)
      ..setImageSampler(3, fruit ?? mask);
    // Room around the tree for the crown to swing into.
    canvas.drawRect((Offset.zero & size).inflate(10), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_SwayPainter old) =>
      old.image != image ||
      old.mask != mask ||
      old.fruit != fruit ||
      old.shader != shader;
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// `gdt-glow`: the warm halo that swells behind the tree on every good deed.
class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.e);
  final double e;

  @override
  void paint(Canvas canvas, Size size) {
    final p = (e / 2.6).clamp(0.0, 1.0);
    const c = Cubic(0.33, 0, 0.2, 1);
    final op = _kf(p, [0, .3, 1], [0, 1, 0], c);
    if (op <= 0) return;
    final sc = .7 + (1.12 - .7) * c.transform(p);
    final r = 260 * sc;
    final o = Offset(size.width / 2, size.height * .4);
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          o,
          r,
          [
            _rgba(255, 252, 236, op),
            _rgba(255, 220, 90, .6 * op),
            _rgba(255, 255, 255, 0),
          ],
          const [0, .48, .78],
        ),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.e != e;
}

/// `gdt-mote`, `gdt-bloom` and `gdt-sweep`, all screen-blended over the tree.
class _FlashPainter extends CustomPainter {
  const _FlashPainter(this.e, {required this.motes, required this.flash});
  final double e;
  final bool motes;
  final bool flash;

  static const _motes = [
    (.22, .52, 9.0, .15, 2.4),
    (.42, .30, 11.0, .5, 2.6),
    (.66, .44, 8.0, .85, 2.5),
    (.52, .62, 7.0, 1.15, 2.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (motes) {
      for (final (x, y, d, delay, dur) in _motes) {
        if (e < delay) continue;
        final p = ((e - delay) / dur).clamp(0.0, 1.0);
        final op = _kf(p, [0, .3, 1], [0, .95, 0], _easeOut);
        if (op <= 0) continue;
        final q = _easeOut.transform(p);
        final ty = 16 + (-52 - 16) * q;
        final sc = .3 + (.5 - .3) * q;
        final o = Offset(size.width * x + d / 2, size.height * y + d / 2 + ty);
        final r = d / 2 * sc;
        canvas.drawCircle(
          o,
          r,
          Paint()
            ..blendMode = BlendMode.screen
            ..shader = ui.Gradient.radial(
              o,
              r,
              [
                _rgba(255, 255, 255, op),
                _rgba(255, 240, 180, .6 * op),
                _rgba(255, 240, 180, 0),
              ],
              const [0, .45, .75],
            ),
        );
      }
    }
    if (!flash) return;

    // Bloom: a white-hot disc that swells and fades.
    final bp = (e / 2.8).clamp(0.0, 1.0);
    const bc = Cubic(0.3, 0, 0.35, 1);
    const bat = [0.0, .14, .56, 1.0];
    final bop = _kf(bp, bat, [0, 1, 1, 0], bc);
    if (bop > 0) {
      final box = Rect.fromLTRB(-120, -130, size.width + 120, size.height + 80);
      final sc = _kf(bp, bat, [.7, 1.08, 1.18, 1.4], bc);
      final c = Offset(box.center.dx, box.top + box.height * .46);
      final r = math.min(box.width / 2, box.height * .46) * sc;
      final o = box.center + (c - box.center) * sc;
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            o,
            r,
            [
              _rgba(255, 255, 255, bop),
              _rgba(255, 255, 250, bop),
              _rgba(255, 250, 215, .92 * bop),
              _rgba(255, 232, 150, .6 * bop),
              _rgba(255, 226, 120, 0),
            ],
            const [0, .42, .62, .80, 1],
          ),
      );
    }

    // Sweep: a band of light rising up through the crown.
    final sp = (e / 2.1).clamp(0.0, 1.0);
    const scv = Cubic(0.25, 0.6, 0.3, 1);
    final sop = _kf(sp, [0, .2, 1], [0, 1, 0], scv);
    if (sop <= 0) return;
    final h = size.height * .62;
    final box = Rect.fromLTWH(-14, size.height - h, size.width + 28, h);
    final q = scv.transform(sp);
    final ty = h * (.45 + (-1.25 - .45) * q);
    final sy = .55 + (1.25 - .55) * q;
    canvas.save();
    canvas.translate(box.center.dx, box.center.dy + ty);
    canvas.scale(1, sy);
    canvas.translate(-box.center.dx, -box.center.dy);
    canvas.saveLayer(
      box,
      Paint()
        ..blendMode = BlendMode.screen
        ..color = Color.fromRGBO(0, 0, 0, sop),
    );
    canvas.drawRect(
      box,
      Paint()
        ..shader = ui.Gradient.linear(
          box.bottomCenter,
          box.topCenter,
          [
            _rgba(255, 255, 255, 0),
            _rgba(255, 252, 232, .75),
            _rgba(255, 255, 255, .95),
            _rgba(255, 246, 200, 0),
          ],
          const [0, .45, .62, 1],
        ),
    );
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _ellipse(
          box.center,
          box.width / 2,
          box.height / 2,
          const [
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x8C000000),
            Color(0x00000000),
          ],
          const [0, .18, .58, 1],
        ),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlashPainter old) =>
      old.e != e || old.motes != motes || old.flash != flash;
}

/// The bin's two soft contact shadows on the grass.
class _BinShadowPainter extends CustomPainter {
  const _BinShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final a = Rect.fromLTWH(3, size.height - 3 - 20, 88, 20);
    canvas.drawOval(
      a.inflate(4),
      Paint()
        ..shader = _ellipse(
          a.center,
          a.width / 2 + 4,
          a.height / 2 + 4,
          const [Color(0x80122A08), Color(0x3D122A08), Color(0x00122A08)],
          const [0, .62, 1],
        ),
    );
    canvas.save();
    canvas.translate(22, size.height + 2 - 7.5);
    canvas.rotate(-6 * math.pi / 180);
    const b = Rect.fromLTWH(0, -7.5, 104, 15);
    canvas.drawOval(
      b,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..shader = ui.Gradient.linear(b.centerLeft, b.centerRight, const [
          Color(0x5716300A),
          Color(0x0016300A),
        ]),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BinShadowPainter old) => false;
}

/// Plants the tree in the backdrop's dirt patch: a faint canopy shadow cast
/// down-left (the sun is top right), a soft pool of shade under the roots,
/// and a dark contact line where they meet the soil. Tree-box coordinates.
class _GroundShadowPainter extends CustomPainter {
  const _GroundShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final yb = h * 0.938;
    void pool(Offset c, double rx, double ry, Color col, List<double> stops) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
        Paint()
          ..shader = _ellipse(c, rx, ry, [
            col,
            col.withValues(alpha: col.a * 0.5),
            col.withValues(alpha: 0),
          ], stops),
      );
    }

    pool(Offset(w * .36, yb - 2), w * .52, h * .055, _rgba(30, 45, 10, .22), [
      0,
      .55,
      1,
    ]);
    pool(Offset(w * .52, yb - 4), w * .36, h * .045, _rgba(45, 28, 12, .45), [
      0,
      .5,
      1,
    ]);
    pool(Offset(w * .52, yb - 2), w * .29, h * .018, _rgba(35, 20, 8, .55), [
      0,
      .6,
      1,
    ]);
  }

  @override
  bool shouldRepaint(_GroundShadowPainter old) => false;
}

/// Butterflies and bees around the crown, more of them as the tree grows.
/// Butterflies wander on slow looping paths, flapping in bursts and gliding
/// with wings open, bobbing with each beat and pointing where they fly;
/// bees hover and dart with a fast buzz. Alternate insects fly behind the
/// tree ([front] false) and in front of it, for depth. Tree-box coordinates.
class _InsectsPainter extends CustomPainter {
  _InsectsPainter(this.time, this.butterflies, this.bees, this.front)
    : super(repaint: time);
  final ValueListenable<double> time;
  final int butterflies;
  final int bees;
  final bool front;

  /// Wing light / dark tones: monarch, lemon, blue, pink, cabbage white.
  static const _wings = [
    (Color(0xFFFFA62B), Color(0xFFD9550B)),
    (Color(0xFFFFEA6E), Color(0xFFEFB400)),
    (Color(0xFF8AD0FF), Color(0xFF2A74D0)),
    (Color(0xFFFFC2E0), Color(0xFFE0609C)),
    (Color(0xFFFFFFFF), Color(0xFFCFD9E6)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width;
    final h = size.height;
    final k = w / 292;

    for (var i = 0; i < butterflies; i++) {
      if ((i.isOdd) != front) continue;
      final r = math.Random(i * 977 + 13);
      final a = 0.14 + r.nextDouble() * 0.14;
      final b = 0.4 + r.nextDouble() * 0.3;
      final c = 0.18 + r.nextDouble() * 0.16;
      final d = 0.5 + r.nextDouble() * 0.3;
      final p = List.generate(4, (_) => r.nextDouble() * 2 * math.pi);
      Offset at(double s) => Offset(
        w *
            (.5 +
                .62 *
                    (.65 * math.sin(a * s + p[0]) +
                        .35 * math.sin(b * s + p[1]))),
        h *
            (.34 +
                .3 *
                    (.6 * math.sin(c * s + p[2]) +
                        .4 * math.cos(d * s + p[3]))),
      );
      final pos = at(t);
      final vel = at(t + 0.05) - pos;
      // Flap in bursts, glide in between.
      final glide = math.sin(t * (0.6 + r.nextDouble() * 0.4) + p[1]) > 0.55;
      final beat = t * 2 * math.pi * (6.5 + r.nextDouble() * 2) + p[2];
      final open = glide
          ? 0.92 + 0.08 * math.sin(t * 3)
          : 0.15 + 0.85 * math.cos(beat).abs();
      final bob = glide ? 0.0 : -2.2 * k * math.sin(beat);
      final heading = math.atan2(vel.dy, vel.dx) + math.pi / 2;
      final (light, dark) = _wings[i % _wings.length];
      final sc = (7.5 + r.nextDouble() * 2.5) * k * (front ? 1 : 0.8);
      _butterfly(
        canvas,
        pos + Offset(0, bob),
        heading,
        open,
        sc,
        light,
        dark,
        front ? 1 : 0.85,
      );
    }

    for (var i = 0; i < bees; i++) {
      if ((i.isEven) != front) continue;
      final r = math.Random(i * 613 + 71);
      final a = 0.35 + r.nextDouble() * 0.3;
      final b = 0.9 + r.nextDouble() * 0.5;
      final p = List.generate(4, (_) => r.nextDouble() * 2 * math.pi);
      Offset at(double s) => Offset(
        w *
                (.5 +
                    .45 *
                        (.7 * math.sin(a * s + p[0]) +
                            .3 * math.sin(b * s + p[1]))) +
            1.6 * k * math.sin(s * 9.1 + p[2]),
        h *
                (.3 +
                    .22 *
                        (.6 * math.sin(a * 1.3 * s + p[2]) +
                            .4 * math.cos(b * .8 * s + p[3]))) +
            1.4 * k * math.cos(s * 11.3 + p[3]),
      );
      final pos = at(t);
      final vel = at(t + 0.08) - pos;
      final sc = (front ? 1.0 : 0.8) * k;
      _bee(canvas, pos, vel, t, sc, front ? 1 : 0.85);
    }
  }

  void _butterfly(
    Canvas canvas,
    Offset pos,
    double heading,
    double open,
    double s,
    Color light,
    Color dark,
    double op,
  ) {
    const ink = Color(0xFF3A2410);
    final fore = Path()
      ..moveTo(0, -0.15 * s)
      ..cubicTo(-0.3 * s, -1.1 * s, -1.15 * s, -1.05 * s, -1.0 * s, -0.45 * s)
      ..cubicTo(-0.95 * s, -0.05 * s, -0.5 * s, 0.1 * s, 0, 0.1 * s)
      ..close();
    final hind = Path()
      ..moveTo(0, 0.05 * s)
      ..cubicTo(-0.55 * s, 0.05 * s, -0.95 * s, 0.4 * s, -0.6 * s, 0.85 * s)
      ..cubicTo(-0.35 * s, 1.05 * s, -0.1 * s, 0.6 * s, 0, 0.35 * s)
      ..close();
    final fill = Paint()
      ..shader = ui.Gradient.radial(Offset.zero, 1.2 * s, [
        light.withValues(alpha: op),
        dark.withValues(alpha: op),
      ]);
    final edge = Paint()
      ..color = ink.withValues(alpha: op)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09 * s
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.85 * op);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.scale(side * open, 1);
      canvas.drawPath(hind, fill);
      canvas.drawPath(hind, edge);
      canvas.drawPath(fore, fill);
      canvas.drawPath(fore, edge);
      canvas.drawCircle(Offset(-0.82 * s, -0.62 * s), 0.07 * s, dot);
      canvas.drawCircle(Offset(-0.62 * s, -0.8 * s), 0.06 * s, dot);
      canvas.restore();
    }
    // Body, head and antennae.
    final body = Paint()..color = ink.withValues(alpha: op);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 0.15 * s),
        width: 0.2 * s,
        height: 1.0 * s,
      ),
      body,
    );
    canvas.drawCircle(Offset(0, -0.42 * s), 0.13 * s, body);
    final ant = Paint()
      ..color = ink.withValues(alpha: op)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * s
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(0, -0.5 * s)
          ..quadraticBezierTo(
            side * 0.1 * s,
            -0.8 * s,
            side * 0.3 * s,
            -0.95 * s,
          ),
        ant,
      );
      canvas.drawCircle(Offset(side * 0.3 * s, -0.95 * s), 0.05 * s, body);
    }
    canvas.restore();
  }

  void _bee(
    Canvas canvas,
    Offset pos,
    Offset vel,
    double t,
    double k,
    double op,
  ) {
    const ink = Color(0xFF2A1C08);
    final dir = vel.dx >= 0 ? 1.0 : -1.0;
    final tilt = (vel.dy / (vel.dx.abs() + 2)).clamp(-0.5, 0.5);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(dir * k, k);
    canvas.rotate(tilt * 0.6);
    // Wings: a fast blur above the back.
    final beat = math.sin(t * 2 * math.pi * 24).abs();
    final wing = Paint()
      ..color = Colors.white.withValues(alpha: (0.35 + 0.3 * beat) * op);
    final wingEdge = Paint()
      ..color = const Color(0xFF9DB8C8).withValues(alpha: 0.6 * op)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (final (dx, rot) in [(-0.8, -0.5), (0.6, -0.2)]) {
      canvas.save();
      canvas.translate(dx, -2.6);
      canvas.rotate(rot);
      canvas.scale(1, 0.4 + 0.6 * beat);
      final r = Rect.fromCenter(
        center: const Offset(0, -2.2),
        width: 4.2,
        height: 5.2,
      );
      canvas.drawOval(r, wing);
      canvas.drawOval(r, wingEdge);
      canvas.restore();
    }
    // Striped body.
    final bodyRect = Rect.fromCenter(
      center: Offset.zero,
      width: 8.5,
      height: 6,
    );
    final body = Path()..addOval(bodyRect);
    canvas.drawPath(
      body,
      Paint()..color = const Color(0xFFFFC928).withValues(alpha: op),
    );
    canvas.save();
    canvas.clipPath(body);
    final stripe = Paint()..color = ink.withValues(alpha: op);
    canvas.drawRect(const Rect.fromLTWH(-1.6, -4, 1.5, 8), stripe);
    canvas.drawRect(const Rect.fromLTWH(1.1, -4, 1.4, 8), stripe);
    canvas.restore();
    canvas.drawPath(
      body,
      Paint()
        ..color = ink.withValues(alpha: op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-4.1, -0.5)
        ..lineTo(-5.6, 0)
        ..lineTo(-4.1, 0.6),
      Paint()..color = ink.withValues(alpha: op),
    );
    canvas.drawCircle(
      const Offset(4.6, -0.4),
      2.1,
      Paint()..color = ink.withValues(alpha: op),
    );
    canvas.drawCircle(
      const Offset(5.2, -0.9),
      0.55,
      Paint()..color = Colors.white.withValues(alpha: 0.9 * op),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsectsPainter old) =>
      old.butterflies != butterflies || old.bees != bees || old.front != front;
}

/// Cloud: top, size, gradient centre (fraction), core/mid alpha, mid stop,
/// blur, duration, delay.
const _kClouds = [
  (.10, 108.0, 36.0, .38, .62, .9, .5, .58, 4.0, 84.0, 0.0),
  (.19, 82.0, 27.0, .54, .58, .78, .36, .58, 4.0, 118.0, 16.0),
  (.29, 140.0, 40.0, .44, .60, .6, .24, .62, 6.0, 152.0, 44.0),
];

/// Bird: top, scale, alpha, flap period, flight duration, delay.
const _kBirds = [
  (.16, 1.0, .7, .44, 27.0, 3.0),
  (.23, .74, .62, .5, 36.0, 13.0),
  (.31, .88, .66, .4, 31.0, 24.0),
];

/// The living garden over the backdrop: sunbeam, dappled light, slow rays,
/// drifting clouds and birds.
class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.time) : super(repaint: time);
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width;
    final h = size.height;

    // Sunbeam — held still.
    {
      const op = .6;
      final box = Rect.fromLTWH(w * .22, -h * .16, w * .88, h * .62);
      final c = Offset(box.left + box.width * .62, box.top + box.height * .24);
      final r = [
        c.dx - box.left,
        box.right - c.dx,
        c.dy - box.top,
        box.bottom - c.dy,
      ].reduce(math.min);
      canvas.drawRect(
        box,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              _rgba(255, 255, 255, .55 * op),
              _rgba(255, 250, 214, .22 * op),
              _rgba(255, 250, 214, 0),
            ],
            const [0, .48, .78],
          ),
      );
    }

    // Rays — held still.
    {
      final box = Rect.fromLTWH(w * .52, -h * .24, w * .92, h * .8);
      final c = box.center;
      final r = math.min(box.width, box.height) / 2;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-math.pi / 2);
      final path = Path();
      const wedge = 2.5 * math.pi / 180;
      final reach = r * .72;
      for (var i = 0; i < 30; i++) {
        final a = i * 12 * math.pi / 180;
        path
          ..moveTo(0, 0)
          ..lineTo(math.cos(a) * reach, math.sin(a) * reach)
          ..lineTo(math.cos(a + wedge) * reach, math.sin(a + wedge) * reach)
          ..close();
      }
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            Offset.zero,
            r,
            [
              _rgba(255, 255, 255, .18),
              _rgba(255, 255, 255, .18),
              _rgba(255, 255, 255, .081),
              _rgba(255, 255, 255, 0),
            ],
            const [0, .14, .44, .70],
          ),
      );
      canvas.restore();
    }

    // Clouds — gdt-cloud.
    for (final (top, cw, ch, fx, fy, a1, a2, mid, blur, dur, delay)
        in _kClouds) {
      final p = _phase(t, dur, delay);
      if (p == null) continue;
      final op = _kf(p, [0, .08, .88, 1], [0, 1, 1, 0]);
      final x = -160 + 580 * p;
      final c = Offset(x + cw * fx, h * top + ch * fy);
      final rx = math.min(cw * fx, cw * (1 - fx)) + blur;
      final ry = math.min(ch * fy, ch * (1 - fy)) + blur;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
        Paint()
          ..shader = _ellipse(
            c,
            rx,
            ry,
            [
              _rgba(255, 255, 255, a1 * op),
              _rgba(255, 255, 255, a2 * op),
              _rgba(255, 255, 255, 0),
            ],
            [0, mid, 1],
          ),
      );
    }

    // Birds — gdt-fly with gdt-flap wings.
    for (final (top, sc, alpha, flap, dur, delay) in _kBirds) {
      final p = _phase(t, dur, delay);
      if (p == null) continue;
      final op = _kf(p, [0, .07, .92, 1], [0, .9, .9, 0]);
      final x = _kf(p, [0, .5, 1], [-70, 200, 450]);
      final y = _kf(p, [0, .5, 1], [0, -30, 14]);
      final f = _phase(t, flap)!;
      final ang = _kf(f, [0, .5, 1], [16, 2, 16], _easeInOut) * math.pi / 180;
      final sy = _kf(f, [0, .5, 1], [1, .22, 1], _easeInOut);
      final paint = Paint()..color = _rgba(46, 64, 86, alpha * op);
      canvas.save();
      canvas.translate(x + 12.5, h * top + y + 4);
      canvas.scale(sc);
      canvas.translate(-12.5, -4);
      for (final left in [true, false]) {
        final pivot = left ? const Offset(12, 4) : const Offset(13, 4);
        final ox = left ? 0.0 : 13.0;
        canvas.save();
        canvas.translate(pivot.dx, pivot.dy);
        canvas.rotate(left ? -ang : ang);
        canvas.scale(1, sy);
        canvas.translate(-pivot.dx, -pivot.dy);
        final outer = Rect.fromLTWH(ox, 0, 12, 8);
        final inner = Rect.fromCenter(
          center: outer.center,
          width: 12,
          height: 4,
        );
        canvas.drawPath(
          Path()
            ..moveTo(ox, 4)
            ..arcTo(outer, math.pi, math.pi, false)
            ..arcTo(inner, 0, -math.pi, false)
            ..close(),
          paint,
        );
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => false;
}
