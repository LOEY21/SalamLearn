import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// The Five Pillars — drag the five pillar columns onto the mosque wall.
/// Ported 1:1 from the supplied "Five Pillars" (Session 1, Scenarios) and
/// "Five Pillars Ordering" (Session 2) prototypes: painted start screen with
/// a bobbing Play button, the mosque scene with its five glowing sockets, the
/// pillar tray, the drag ghost, cheers, and the Mumtāz! card.
///
/// [FivePillarsMode.scenarios] asks five questions, one slot at a time; only
/// the last pillar placed can be lifted back out. [FivePillarsMode.ordering]
/// lights all five slots at once and any placed pillar can be lifted.
///
/// The prototypes are authored against a fixed 393x852 phone frame, so the
/// scene is built inside that virtual stage and scaled to fit; the painted
/// backgrounds run on past the stage to the screen edges.
class FivePillarsGame extends StatefulWidget {
  const FivePillarsGame({
    super.key,
    required this.mode,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final FivePillarsMode mode;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Leaves the lesson from the start screen's back button.
  final VoidCallback? onExit;

  @override
  State<FivePillarsGame> createState() => _FivePillarsGameState();
}

// ---------------------------------------------------------------------------
// Stage, assets, data — all lifted from the prototypes.
// ---------------------------------------------------------------------------

const double _kW = 393;
const double _kH = 852;
const String _kA = 'assets/images/five_pillars';
const String _kStartBg = '$_kA/start_bg.png';
const String _kStartBgMask = '$_kA/start_bg_mask.png';

/// [_kStartBg] with the two lanterns painted out, for the live background;
/// the lanterns are drawn over it as swinging sprites.
const String _kStartBgPalms = '$_kA/start_bg_palms.png';
const String _kStartBgLive = '$_kA/start_bg_live.png';
const Size _kStartBgSize = Size(853, 1844);

/// Centre of the painted pillar wall in [_kStartBg]: the entrance
/// transition pushes in on it.
const Offset _kPillarsFocus = Offset(426, 990);

/// Entrance: push-in and light bloom, then the flash clearing over the game.
const double _kEnterDur = 4.0;
const double _kFlashDur = 1.0;
const Color _kFlash = Color(0xFFFFF8E6);
const Curve _pushCurve = Cubic(0.5, 0, 0.2, 1);

/// Finale: each placed pillar lights [_kLightGap]s after the last, then
/// the scene holds lit before the end screen.
const double _kLightGap = 0.8;
const double _kLightDur = 0.7;
const double _kLightHold = 1.3;

class _Lantern {
  const _Lantern(this.asset, this.rect, this.pivot, this.phase);
  final String asset;

  /// Sprite and hook position, in [_kStartBg] pixels.
  final Rect rect;
  final Offset pivot;
  final double phase;
}

const List<_Lantern> _kLanterns = [
  _Lantern(
    '$_kA/start_lantern_l.png',
    Rect.fromLTWH(19, 122, 81, 250),
    Offset(59, 124),
    0,
  ),
  _Lantern(
    '$_kA/start_lantern_r.png',
    Rect.fromLTWH(751, 122, 85, 257),
    Offset(793, 124),
    1.9,
  ),
];
const String _kStartBgShader = 'shaders/five_pillars_bg.frag';
const String _kStartLogo = '$_kA/start_logo.png';
const String _kStartGirl = '$_kA/start_girl.png';
const String _kStartBoy = '$_kA/start_boy.png';
const String _kStartCaption = '$_kA/start_caption.png';
const String _kStartPlay = '$_kA/start_play.png';
const String _kStartPlayDown = '$_kA/start_play_down.png';
const String _kBtnHome = '$_kA/btn_home.png';
const String _kBtnHomeDown = '$_kA/btn_home_down.png';
const String _kBtnBack = '$_kA/btn_back.png';
const String _kBtnBackDown = '$_kA/btn_back_down.png';
const String _kBtnSound = '$_kA/btn_sound.png';
const String _kBtnSoundDown = '$_kA/btn_sound_down.png';
const String _kDoneFrame = '$_kA/done_frame.png';
const String _kDoneStar = '$_kA/done_star.png';
const String _kHowPanelS1 = '$_kA/howto_panel_s1.png';
const String _kHowPanelS2 = '$_kA/howto_panel_s2.png';
const String _kHowReady = '$_kA/howto_ready.png';
const String _kHowReadyDown = '$_kA/howto_ready_down.png';

/// How-to-play boards fill the stage width, like the reference.
const double _kHowPanelW = 380;
const double _kHowPanelTop = 56;
const Color _howInk = Color(0xFF5A2E0E);
const Color _howNavy = Color(0xFF14306E);
const String _kSceneArt = '$_kA/bg_mosque.png';

/// Each slot's glow is cut from its own painted socket in [_kSceneArt], so
/// it sits exactly over it. Rects are stage coordinates.
const List<Rect> _kSocketRects = [
  Rect.fromLTWH(9.83, 373.62, 61.61, 171.54),
  Rect.fromLTWH(87.89, 372.02, 60.54, 173.13),
  Rect.fromLTWH(167.03, 372.02, 59.48, 173.13),
  Rect.fromLTWH(244.03, 372.02, 61.07, 173.13),
  Rect.fromLTWH(321.04, 372.55, 61.61, 172.60),
];
String _socketGlow(int i) => '$_kA/slot_glow_$i.png';

// background-size: 115% auto; the new art (851x1847) sits 13px lower
// in its frame than the prototype's, so 34.4% (not 28%) keeps each
// painted socket under its slot.
const double _kBgW = _kW * 1.15;
const double _kBgH = _kBgW * 1847 / 851;
const double _kBgTop = (_kH - _kBgH) * 0.344;

/// Pillar art is 1024x1536; decoded no larger than it is ever drawn.
const int _kPillarCache = 480;
const double _kPillarAspect = 1536 / 1024;

class _Pillar {
  const _Pillar(this.id, this.label, this.w, this.mb, this.ml);
  final String id;
  final String label;

  /// Normalized render sizes: every pillar's artwork is scaled so the
  /// visible column is the same height (162px) and sits on the same
  /// baseline.
  final double w;
  final double mb;
  final double ml;

  String get src => '$_kA/pillar_$id.png';
}

const List<_Pillar> _kPillars = [
  _Pillar('shahadah', 'Shahādah (Faith)', 119, 3, 0),
  _Pillar('salah', 'Ṣalāh (Prayer)', 117, 4, 0),
  _Pillar('zakah', 'Zakāh (Charity)', 120, 6, 0),
  _Pillar('sawm', 'Ṣawm (Fasting)', 121, 7, 0),
  _Pillar('hajj', 'Ḥajj (Pilgrimage)', 121, 7, 1),
];

_Pillar _pillar(String id) => _kPillars.firstWhere((p) => p.id == id);

/// End-screen recap: what each pillar means, and its art's colour.
const Map<String, (String, Color)> _kPillarRecap = {
  'shahadah': ('Believing in Allah and His Messenger', Color(0xFF1E9E3E)),
  'salah': ('Praying five times every day', Color(0xFF1F6FD8)),
  'zakah': ('Sharing with people in need', Color(0xFFE9A10C)),
  'sawm': ('Fasting in the month of Ramadan', Color(0xFF7B3FC8)),
  'hajj': ('The journey to the Kaaba in Makkah', Color(0xFFD7262E)),
};

/// Session 1's five scenarios, one per slot.
const List<(String, String)> _kQuestions = [
  (
    'Amina wants to become a good Muslim. What is the first pillar?',
    'shahadah',
  ),
  ('Ahmad hears the Adhan (call to prayer). What should he do?', 'salah'),
  ('Fatimah has extra food and toys. What is the kind thing to do?', 'zakah'),
  ('It is the month of Ramadan. What do Muslims do?', 'sawm'),
  ('A family travels to Makkah. What is this special journey called?', 'hajj'),
];

/// Session 2's single instruction, target order and fixed tray order.
const String _kInstruction =
    'Can you put the Five Pillars in the correct order to build the mosque?';
const List<String> _kTargets = ['shahadah', 'salah', 'zakah', 'sawm', 'hajj'];
const List<String> _kTrayOrder = ['sawm', 'shahadah', 'hajj', 'zakah', 'salah'];

// Slot row: left .4%, right .6%, top 45.6%, height 18.3% of the stage.
const double _kSlotL = _kW * 0.004;
const double _kSlotT = _kH * 0.456;
const double _kSlotH = _kH * 0.183;
const double _kSlotW = (_kW - _kW * 0.004 - _kW * 0.006) / 5;

// Tray: top 66%, padding 0 4px 26px; items 23% wide with -1.8% margins.
const double _kTrayT = _kH * 0.66;
const double _kTrayBottom = _kH - 26;
const double _kTrayInnerW = _kW - 8;
const double _kTrayInnerH = _kTrayBottom - _kTrayT;
const double _kItemW = _kTrayInnerW * 0.23;
const double _kItemM = _kTrayInnerW * 0.018;
const double _kItemOuter = _kItemW - 2 * _kItemM;
const double _kTrayStart = 4 + (_kTrayInnerW - 5 * _kItemOuter) / 2;
const double _kItemH = _kTrayInnerH * 0.92;

// Palette.
const _startBack = Color(0xFF0D2036);
const _sceneBase = Color(0xFFF3E4C4);
const _blueBottom = Color(0xFF1B6DC0);
const _pipDone = Color(0xFF2EA34F);
const _pipNow = Color(0xFFFFC72C);
const _pipIdle = Color(0x2E1B4E8A);
const _cardBg = Color(0xF5FFFCF0);
const _cardEdge = Color(0xFFE6C56B);
const _labelInk = Color(0xFFB07D16);
const _promptInk = Color(0xFF24324A);
const _cheerInk = Color(0xFF1F7A3C);
const _gold = Color(0xFFFFC72C);
const _doneInk = Color(0xFF3B4A63);
const _shadowInk = Color(0xFF28200A);

const Curve _linear = Curves.linear;
const Curve _ease = Curves.ease;
const Curve _easeInOut = Curves.easeInOut;
const Curve _sceneCurve = Cubic(0.2, 0.8, 0.3, 1);
const Curve _dropCurve = Cubic(0.2, 0.9, 0.3, 1);
const Curve _popCurve = Cubic(0.3, 1.5, 0.5, 1);

double _c01(double v) => v.clamp(0.0, 1.0);

/// Interpolates a CSS `@keyframes` track with [curve] applied per segment.
double _kf(
  double t,
  List<double> stops,
  List<double> vals, [
  Curve curve = _linear,
]) {
  if (t <= stops.first) return vals.first;
  for (var i = 0; i < stops.length - 1; i++) {
    if (t <= stops[i + 1]) {
      final span = stops[i + 1] - stops[i];
      final u = span <= 0 ? 1.0 : curve.transform(_c01((t - stops[i]) / span));
      return vals[i] + (vals[i + 1] - vals[i]) * u;
    }
  }
  return vals.last;
}

/// Progress of a one-shot animation of [dur] seconds, [t] seconds in.
double _once(double t, double dur, [double delay = 0]) =>
    _c01((t - delay) / dur);

double _loop(double t, double dur) {
  final x = t % dur;
  return (x < 0 ? x + dur : x) / dur;
}

TextStyle _baloo(
  double size,
  double weight,
  Color color, {
  double? height,
  double ls = 0,
}) => TextStyle(
  fontFamily: 'Baloo2Var',
  fontSize: size,
  fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
  fontVariations: [ui.FontVariation.weight(weight)],
  color: color,
  height: height,
  letterSpacing: ls,
);

/// An image with a CSS `drop-shadow(0 dy blur color)` under it.
Widget _shadowed(
  String asset, {
  required double dy,
  required double blur,
  required Color shadow,
  int? cacheWidth,
}) => Stack(
  clipBehavior: Clip.none,
  fit: StackFit.expand,
  children: [
    Transform.translate(
      offset: Offset(0, dy),
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blur / 2,
          sigmaY: blur / 2,
          tileMode: TileMode.decal,
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.fill,
          cacheWidth: cacheWidth,
          color: shadow,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    ),
    Image.asset(asset, fit: BoxFit.fill, cacheWidth: cacheWidth),
  ],
);

enum _Screen { start, play, done }

class _FivePillarsGameState extends State<FivePillarsGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  double get _now => _clock.value * 3600.0;

  bool get _scenarios => widget.mode == FivePillarsMode.scenarios;

  _Screen _screen = _Screen.start;
  int _step = 0;
  List<String?> _placed = List.filled(5, null);
  List<String> _order = _kPillars.map((p) => p.id).toList();
  String? _dragId;
  Offset _dragAt = Offset.zero;
  int? _dragPointer;
  String? _cheer;
  bool _leaving = false;
  bool _entering = false;
  bool _howTo = false;
  double _howT0 = 0;
  double _enterT0 = 0;
  Alignment _sceneAlign = Alignment.center;
  int _wrongIdx = -1;
  int _hover = -1;
  int _errors = 0;

  /// Set once every pillar is in: the finished pillars light up one by
  /// one before the end screen.
  double? _finaleT0;
  final List<Timer> _finaleTs = [];

  /// Wrong drops per pillar, for the end screen's first-try badges.
  final Map<String, int> _missed = {};

  // Mount times, so each CSS animation starts when its element appears.
  double _startT0 = 0;
  double _playT0 = 0;
  double _doneT0 = 0;
  double _cheerT0 = 0;
  double _shakeT0 = -10;
  final List<double> _popT0 = List.filled(5, -10);
  final List<double> _glowT0 = List.filled(5, 0);
  final List<bool> _glowWas = List.filled(5, false);

  Timer? _leaveT;
  Timer? _enterT;
  Timer? _cheerT;

  // Live start-screen background; null until loaded (static art meanwhile).
  ui.FragmentShader? _bgShader;
  ui.Image? _bgImage;
  ui.Image? _bgMask;
  ui.Image? _bgPalms;

  final math.Random _rng = math.Random();

  int get _placedCount => _placed.where((p) => p != null).length;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..forward();
    _loadLiveBg();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final config = createLocalImageConfiguration(context);
    for (final a in [
      _kStartBg,
      for (final l in _kLanterns) l.asset,
      _kStartLogo,
      _kStartGirl,
      _kStartBoy,
      _kStartCaption,
      _kStartPlay,
      _kStartPlayDown,
      _kHowPanelS1,
      _kHowPanelS2,
      _kDoneFrame,
      _kDoneStar,
      _kBtnHome,
      _kBtnHomeDown,
      _kBtnBack,
      _kBtnBackDown,
      _kBtnSound,
      _kBtnSoundDown,
      _kHowReady,
      _kHowReadyDown,
      _kSceneArt,
    ]) {
      AssetImage(a).resolve(config);
    }
  }

  Future<void> _loadLiveBg() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(_kStartBgShader);
      final images = await Future.wait([
        _decodeAsset(_kStartBgLive),
        _decodeAsset(_kStartBgMask),
        _decodeAsset(_kStartBgPalms),
      ]);
      if (!mounted) {
        for (final i in images) {
          i.dispose();
        }
        return;
      }
      setState(() {
        _bgShader = program.fragmentShader();
        _bgImage = images[0];
        _bgMask = images[1];
        _bgPalms = images[2];
      });
    } catch (_) {
      // Shaders unsupported here: the static art stays.
    }
  }

  static Future<ui.Image> _decodeAsset(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  @override
  void dispose() {
    _bgShader?.dispose();
    _bgImage?.dispose();
    _bgMask?.dispose();
    _bgPalms?.dispose();
    _leaveT?.cancel();
    _enterT?.cancel();
    _cheerT?.cancel();
    for (final t in _finaleTs) {
      t.cancel();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _clock.dispose();
    super.dispose();
  }

  static Duration _ms(int ms) => Duration(milliseconds: ms);

  // -------------------------------------------------------------------------
  // Sound — the prototype's Web Audio tones, as system clicks and haptics.
  // -------------------------------------------------------------------------

  void _chime() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  void _thud() => HapticFeedback.heavyImpact();
  void _nope() => HapticFeedback.mediumImpact();
  void _pick() => HapticFeedback.selectionClick();
  void _fanfare() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.heavyImpact();
  }

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  void _setCheer(String? c) {
    if (_cheer == null && c != null) _cheerT0 = _now;
    _cheer = c;
  }

  int _shakingSlot() {
    if (_scenarios) {
      return _screen == _Screen.play && _cheer == 'Try again' ? _step : -1;
    }
    return _wrongIdx;
  }

  void _showHowTo() {
    if (_howTo) return;
    _chime();
    setState(() {
      _howTo = true;
      _howT0 = _now;
    });
  }

  void _start() {
    if (_screen == _Screen.start) {
      if (_entering) return;
      _chime();
      setState(() {
        _entering = true;
        _enterT0 = _now;
      });
      _enterT = Timer(_ms((_kEnterDur * 1000).round()), () {
        if (mounted) _beginPlay();
      });
      return;
    }
    _chime();
    _beginPlay();
  }

  void _beginPlay() {
    final order = _scenarios
        ? (_kPillars.map((p) => p.id).toList()..shuffle(_rng))
        : _kTrayOrder.toList();
    final fromStart = _screen == _Screen.start;
    setState(() {
      _entering = false;
      _screen = _Screen.play;
      _playT0 = _now;
      _step = 0;
      _placed = List.filled(5, null);
      _order = order;
      _dragId = null;
      _dragPointer = null;
      _cheer = null;
      _leaving = fromStart;
      _wrongIdx = -1;
      _errors = 0;
      _missed.clear();
      _finaleT0 = null;
    });
    _leaveT?.cancel();
    if (fromStart) {
      _leaveT = Timer(_ms((_kFlashDur * 1000).round()), () {
        if (mounted) setState(() => _leaving = false);
      });
    }
  }

  void _reset() {
    _cheerT?.cancel();
    for (final t in _finaleTs) {
      t.cancel();
    }
    _finaleT0 = null;
    setState(() {
      _screen = _Screen.start;
      _startT0 = _now;
      _entering = false;
      _howTo = false;
      _step = 0;
      _placed = List.filled(5, null);
      _dragId = null;
      _dragPointer = null;
      _cheer = null;
      _wrongIdx = -1;
    });
  }

  void _finish() {
    final attempts = 5 + _errors;
    widget.onComplete(widget.xp, 5 / attempts * 100.0, _errors);
  }

  void _beginDrag(String id, PointerDownEvent e) {
    _dragId = id;
    _dragAt = e.localPosition;
    _dragPointer = e.pointer;
  }

  void _grab(String id, PointerDownEvent e) {
    if (_placed.contains(id)) return;
    if (!_scenarios && _screen != _Screen.play) return;
    setState(() => _beginDrag(id, e));
  }

  void _liftPlaced(int idx, PointerDownEvent e) {
    final id = _placed[idx];
    if (id == null || _screen != _Screen.play) return;
    if (_scenarios) {
      if (idx != _placedCount - 1) return;
      _pick();
      _cheerT?.cancel();
      setState(() {
        for (var i = idx; i < 5; i++) {
          _placed[i] = null;
        }
        _step = idx;
        _setCheer(null);
        _beginDrag(id, e);
      });
    } else {
      _pick();
      setState(() {
        _placed[idx] = null;
        _wrongIdx = -1;
        _setCheer(null);
        _beginDrag(id, e);
      });
    }
  }

  void _drop(Offset at) {
    final id = _dragId;
    setState(() {
      _dragId = null;
      _dragPointer = null;
    });
    if (id == null) return;
    final idx = _slotAt(at);
    if (_scenarios) {
      final ok = idx == _step && _step < 5 && id == _kQuestions[_step].$2;
      if (ok) {
        _correctScenario(id);
      } else {
        _wrongScenario(idx == _step);
      }
    } else {
      if (idx < 0 || _placed[idx] != null) {
        _nope();
        return;
      }
      if (_kTargets[idx] == id) {
        _correctOrdering(id, idx);
      } else {
        _wrongOrdering(idx);
      }
    }
  }

  void _correctScenario(String id) {
    final next = _step + 1;
    _thud();
    setState(() {
      _placed[_step] = id;
      _popT0[_step] = _now;
      _step = next;
      _setCheer('Excellent!');
    });
    _cheerT?.cancel();
    _cheerT = Timer(_ms(1500), () {
      if (!mounted) return;
      if (next >= _kQuestions.length) {
        _startFinale();
      } else {
        setState(() => _setCheer(null));
      }
    });
  }

  void _startFinale() {
    setState(() {
      _finaleT0 = _now;
      _setCheer(null);
    });
    for (final t in _finaleTs) {
      t.cancel();
    }
    _finaleTs
      ..clear()
      ..addAll([
        for (var i = 0; i < 5; i++)
          Timer(_ms((i * _kLightGap * 1000).round()), _chime),
        Timer(
          _ms((((4 * _kLightGap) + _kLightDur + _kLightHold) * 1000).round()),
          () {
            if (!mounted) return;
            _fanfare();
            setState(() {
              _screen = _Screen.done;
              _doneT0 = _now;
              _finaleT0 = null;
            });
          },
        ),
      ]);
  }

  void _wrongScenario(bool onSlot) {
    _nope();
    if (!onSlot) return;
    _errors++;
    final want = _kQuestions[_step].$2;
    _missed[want] = (_missed[want] ?? 0) + 1;
    final was = _shakingSlot();
    setState(() => _setCheer('Try again'));
    if (_shakingSlot() != was) _shakeT0 = _now;
    _cheerT?.cancel();
    _cheerT = Timer(_ms(1100), () {
      if (mounted) setState(() => _setCheer(null));
    });
  }

  void _correctOrdering(String id, int idx) {
    _thud();
    setState(() {
      _placed[idx] = id;
      _popT0[idx] = _now;
      _wrongIdx = -1;
      _setCheer(_placedCount >= 5 ? null : 'Excellent!');
    });
    final count = _placedCount;
    _cheerT?.cancel();
    if (count >= 5) {
      _cheerT = Timer(_ms(1200), () {
        if (mounted) _startFinale();
      });
    } else {
      _cheerT = Timer(_ms(1100), () {
        if (mounted) setState(() => _setCheer(null));
      });
    }
  }

  void _wrongOrdering(int idx) {
    _nope();
    _errors++;
    _missed[_kTargets[idx]] = (_missed[_kTargets[idx]] ?? 0) + 1;
    final was = _shakingSlot();
    setState(() {
      _setCheer('Try again');
      _wrongIdx = idx;
    });
    if (_shakingSlot() != was) _shakeT0 = _now;
    _cheerT?.cancel();
    _cheerT = Timer(_ms(1100), () {
      if (!mounted) return;
      setState(() {
        _setCheer(null);
        _wrongIdx = -1;
      });
    });
  }

  // -------------------------------------------------------------------------
  // Geometry — stands in for the prototype's DOM hit testing.
  // -------------------------------------------------------------------------

  static Rect _slotRect(int i) =>
      Rect.fromLTWH(_kSlotL + i * _kSlotW, _kSlotT, _kSlotW, _kSlotH);

  static Rect _slotArtRect(int i, _Pillar p) {
    final s = _slotRect(i);
    final w = p.w;
    final bottom = s.bottom + p.mb + 2;
    return Rect.fromLTWH(
      s.left + _kSlotW / 2 + p.ml - w / 2,
      bottom - w * _kPillarAspect,
      w,
      w * _kPillarAspect,
    );
  }

  static Rect _itemRect(int j) => Rect.fromLTWH(
    _kTrayStart + j * _kItemOuter - _kItemM,
    _kTrayBottom - _kItemH,
    _kItemW,
    _kItemH,
  );

  static Rect _itemArtRect(int j, _Pillar p) {
    final box = _itemRect(j);
    final w = p.w;
    return Rect.fromLTWH(
      box.left + (_kItemW - w + p.ml) / 2,
      _kTrayBottom + p.mb - w * _kPillarAspect,
      w,
      w * _kPillarAspect,
    );
  }

  int _trayAt(Offset p) {
    for (var j = _order.length - 1; j >= 0; j--) {
      if (_itemRect(j).contains(p) ||
          _itemArtRect(j, _pillar(_order[j])).contains(p)) {
        return j;
      }
    }
    return -1;
  }

  /// The slot under [p] (its own box or its pillar art), topmost first.
  /// (-1, false) if none; the bool is whether the pillar art was hit.
  (int, bool) _slotHit(Offset p) {
    for (var i = 4; i >= 0; i--) {
      final id = _placed[i];
      if (id != null && _slotArtRect(i, _pillar(id)).contains(p)) {
        return (i, true);
      }
      if (_slotRect(i).contains(p)) return (i, false);
    }
    return (-1, false);
  }

  int _slotAt(Offset p) {
    // The tray panel sits above everything from 66% down.
    if (p.dy >= _kTrayT) return -1;
    return _slotHit(p).$1;
  }

  void _onDown(PointerDownEvent e) {
    if (_dragId != null || _screen != _Screen.play || _finaleT0 != null) {
      return;
    }
    final p = e.localPosition;
    // The tray panel sits above the slots and holds every tray pillar.
    if (p.dy >= _kTrayT) {
      final j = _trayAt(p);
      if (j >= 0) _grab(_order[j], e);
      return;
    }
    final (i, onArt) = _slotHit(p);
    if (i >= 0 && onArt) _liftPlaced(i, e);
  }

  void _onMove(PointerMoveEvent e) {
    if (_dragId == null || e.pointer != _dragPointer) return;
    setState(() => _dragAt = e.localPosition);
  }

  void _onUp(PointerEvent e) {
    if (_dragId == null || e.pointer != _dragPointer) return;
    _drop(e.localPosition);
  }

  void _onHover(PointerHoverEvent e) {
    final j = _trayAt(e.localPosition);
    if (j != _hover) setState(() => _hover = j);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  Widget _fx(Widget Function(double now) builder) =>
      AnimatedBuilder(animation: _clock, builder: (_, _) => builder(_now));

  Widget _stage(Widget child, [Alignment align = Alignment.center]) =>
      SizedBox.expand(
        child: FittedBox(
          alignment: align,
          child: SizedBox(width: _kW, height: _kH, child: child),
        ),
      );

  bool _glowActive(int i) {
    if (_screen != _Screen.play) return false;
    if (_scenarios) return i == _step && _cheer == null;
    return _placed[i] == null;
  }

  @override
  Widget build(BuildContext context) {
    for (var i = 0; i < 5; i++) {
      final on = _glowActive(i);
      if (on && !_glowWas[i]) _glowT0[i] = _now;
      _glowWas[i] = on;
    }
    return LayoutBuilder(
      builder: (context, box) {
        final k = math.min(box.maxWidth / _kW, box.maxHeight / _kH);
        final stageTop = (box.maxHeight - _kH * k) / 2;
        final padTop = MediaQuery.paddingOf(context).top;
        final shift = math.max(0.0, padTop - stageTop) / k;
        // Lift the play stage so the scene art's top edge meets the screen
        // top; otherwise the cover backdrop shows above it as a second arch.
        final gap = box.maxHeight - _kH * k;
        final sceneTop = math.min(gap / 2, -_kBgTop * k);
        _sceneAlign = gap > 0
            ? Alignment(0, sceneTop / gap * 2 - 1)
            : Alignment.center;
        final playShift = math.max(0.0, padTop - sceneTop) / k;
        return ColoredBox(
          color: _startBack,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_screen == _Screen.start) _buildStart(shift),
              if (_screen == _Screen.play) _buildPlay(playShift),
              if (_dragId != null)
                _stage(IgnorePointer(child: _buildGhost()), _sceneAlign),
              if (_screen == _Screen.done) _buildDone(),
            ],
          ),
        );
      },
    );
  }

  // ---- start ----

  Widget _buildStart(double shift) {
    return _fx(
      (now) => _startScene(
        now - _startT0,
        play: _ImageButton(
          key: const ValueKey('fp-play'),
          up: _kStartPlay,
          down: _kStartPlayDown,
          onTap: _showHowTo,
        ),
        back: widget.onExit == null
            ? null
            : Positioned(
                left: 16,
                top: 16 + shift,
                child: _iconButton(
                  'fp-home',
                  _kBtnHome,
                  _kBtnHomeDown,
                  widget.onExit!,
                ),
              ),
      ),
    );
  }

  /// The start screen's layers, laid out over the reference composition
  /// (851x1847) scaled onto the 393x852 stage. [t] is seconds since the
  /// screen appeared; the entrance plays over the first ~1.2s.
  Widget _startScene(
    double t, {
    required Widget play,
    Widget? back,
  }) => LayoutBuilder(
    builder: (context, box) {
      final k = math.max(
        box.maxWidth / _kStartBgSize.width,
        box.maxHeight / _kStartBgSize.height,
      );
      final focus = Offset(
        (box.maxWidth - _kStartBgSize.width * k) / 2 + _kPillarsFocus.dx * k,
        _kPillarsFocus.dy * k,
      );
      final e = _entering ? _now - _enterT0 : 0.0;
      final push = _pushCurve.transform(_c01(e / _kEnterDur));
      final zoom = 1 + 1.6 * push;
      final fg = 1 - Curves.easeOut.transform(_c01(e / 0.6));
      final light = Curves.easeIn.transform(
        _c01((e - 1.6) / (_kEnterDur - 1.6)),
      );
      // Arrival: the courtyard eases back from the pillars (the exit's
      // push-in, reversed) out of a warm veil, then the title art lands.
      final settle = Curves.easeOutCubic.transform(_c01(t / 1.6));
      final bgZoom = zoom * (1 + 0.14 * (1 - settle));
      final veil = 1 - Curves.easeOut.transform(_c01(t / 0.8));
      Widget scaled(double z, Widget child) => Transform.scale(
        scale: z,
        origin: focus - box.biggest.center(Offset.zero),
        child: child,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          _startLayers(
            t,
            (c) => scaled(bgZoom, c),
            (c) => scaled(zoom, c),
            bgZoom,
            play: play,
            back: back,
            fg: fg,
          ),
          if (veil > 0)
            IgnorePointer(
              child: ColoredBox(color: _kFlash.withValues(alpha: veil)),
            ),
          if (light > 0) ...[
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      focus.dx / box.maxWidth * 2 - 1,
                      focus.dy / box.maxHeight * 2 - 1,
                    ),
                    radius: 0.1 + 1.9 * light,
                    colors: [
                      Colors.white.withValues(alpha: light),
                      _kFlash.withValues(alpha: light * 0.85),
                      const Color(0xFFFFE3A0).withValues(alpha: light * 0.35),
                      const Color(0x00FFE3A0),
                    ],
                    stops: const [0, 0.35, 0.7, 1],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: ColoredBox(
                color: _kFlash.withValues(
                  alpha: Curves.easeIn.transform(_c01((light - 0.6) / 0.4)),
                ),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _startLayers(
    double t,
    Widget Function(Widget) zoomedBg,
    Widget Function(Widget) zoomed,
    double bgZoom, {
    required Widget play,
    Widget? back,
    required double fg,
  }) {
    double enter(double delay, double dur) =>
        _dropCurve.transform(_once(t, dur, delay));
    final bob = _kf(_loop(t, 2.4), [0, 0.5, 1], [0, -6, 0], _easeInOut);

    final logo = enter(0.3, 0.7);
    final girl = Curves.easeOutCubic.transform(_once(t, 0.6, 0.5));
    final boy = Curves.easeOutCubic.transform(_once(t, 0.6, 0.62));
    final button = enter(0.95, 0.5);
    final caption = enter(1.1, 0.5);

    // Title -> how to play: the title art lifts away, the mascots step
    // down to flank the panel, which rises in with its steps one by one.
    final ho = _howTo ? _now - _howT0 : 0.0;
    final out = _howTo ? Curves.easeOut.transform(_c01(ho / 0.35)) : 0.0;
    final ready = _howTo ? _dropCurve.transform(_once(ho, 0.45, 0.85)) : 0.0;

    final shader = _bgShader;
    // The shader zooms itself (its pixels are mapped from the canvas);
    // everything else is scaled about the same point on screen.
    final bg = shader != null
        ? Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _StartBgPainter(
                  shader,
                  _bgImage!,
                  _bgMask!,
                  _bgPalms!,
                  _now,
                  bgZoom,
                ),
              ),
              zoomedBg(_lanterns(_now)),
            ],
          )
        : zoomedBg(
            Image.asset(
              _kStartBg,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        zoomed(
          Opacity(
            opacity: fg,
            child: IgnorePointer(
              ignoring: _entering,
              child: _stage(
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 73,
                      top: 54,
                      width: 247,
                      height: 239,
                      child: Opacity(
                        opacity: logo * (1 - out),
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            -40 * (1 - logo) + bob * 0.6 - 24 * out,
                          ),
                          child: Transform.scale(
                            scale: (0.85 + 0.15 * logo) * (1 - 0.08 * out),
                            child: Image.asset(
                              _kStartLogo,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_howTo) _howPanel(ho),
                    Positioned(
                      left: 4,
                      top: 427,
                      width: 171,
                      height: 252,
                      child: _arrive(
                        girl * (1 - out),
                        const _Mascot(_kStartGirl, feetX: 0.4),
                      ),
                    ),
                    Positioned(
                      left: 243,
                      top: 423,
                      width: 148,
                      height: 250,
                      child: _arrive(
                        boy * (1 - out),
                        const _Mascot(_kStartBoy, feetX: 0.55),
                      ),
                    ),
                    Positioned(
                      left: 102,
                      top: 634,
                      width: 188,
                      height: 74,
                      child: IgnorePointer(
                        ignoring: _howTo,
                        child: Opacity(
                          opacity: button * (1 - out),
                          child: Transform.translate(
                            offset: Offset(0, bob * button),
                            child: Transform.scale(
                              scale: (0.7 + 0.3 * button) * (1 - 0.15 * out),
                              child: play,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 50,
                      top: 717,
                      width: 293,
                      height: 65,
                      child: Opacity(
                        opacity: caption * (1 - out),
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - caption) + 20 * out),
                          child: Image.asset(
                            _kStartCaption,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    if (_howTo)
                      Positioned(
                        left: 68,
                        top: _kHowPanelTop + _howPanelH + 6,
                        width: 257,
                        height: 75,
                        child: Opacity(
                          opacity: ready,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              _kf(
                                    _loop(ho, 2.4),
                                    [0, 0.5, 1],
                                    [0, -5, 0],
                                    _easeInOut,
                                  ) *
                                  ready,
                            ),
                            child: Transform.scale(
                              scale: 0.7 + 0.3 * ready,
                              child: _ImageButton(
                                key: const ValueKey('fp-ready'),
                                up: _kHowReady,
                                down: _kHowReadyDown,
                                onTap: _start,
                                label: "I'm Ready!  \u203A",
                              ),
                            ),
                          ),
                        ),
                      ),
                    ?back,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A one-time soft rise into place; still once it lands.
  static Widget _arrive(double e, Widget child) => Opacity(
    opacity: e,
    child: Transform.translate(offset: Offset(0, 16 * (1 - e)), child: child),
  );

  double get _howPanelH => _kHowPanelW * (_scenarios ? 1610 / 939 : 1631 / 941);

  /// The how-to-play board for this session: its art has the title,
  /// ribbon, step and prompt areas left blank, filled in here. Positions
  /// are in the board art's own pixels.
  Widget _howPanel(double ho) {
    final s1 = _scenarios;
    final k = _kHowPanelW / (s1 ? 939 : 941);
    final panel = _dropCurve.transform(_once(ho, 0.55, 0.15));
    Widget fadeIn(double d, Widget child) {
      final e = Curves.easeOut.transform(_once(ho, 0.4, d));
      return Opacity(
        opacity: e,
        child: Transform.translate(
          offset: Offset(10 * (1 - e), 0),
          child: child,
        ),
      );
    }

    Widget at(double x, double y, double w, Widget child, [double d = 0]) =>
        Positioned(
          left: x * k,
          top: y * k,
          width: w * k,
          child: fadeIn(d, child),
        );
    Widget centred(double cx, double cy, Widget child, [double d = 0]) =>
        Positioned(
          left: cx * k - 60,
          top: cy * k - 30,
          width: 120,
          height: 60,
          child: fadeIn(d, Center(child: child)),
        );

    // A cream halo keeps text legible where it overlaps the scenery art.
    const halo = [
      Shadow(color: Color(0xF2FFF8EA), blurRadius: 4),
      Shadow(color: Color(0xCCFFF8EA), blurRadius: 9),
    ];
    final head = _baloo(17.5, 800, _howNavy, height: 1.05);
    final body = _baloo(
      12.5,
      600,
      _howInk,
      height: 1.12,
    ).copyWith(shadows: halo);
    Widget step(String h, String b) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(h, style: head.copyWith(shadows: halo)),
        const SizedBox(height: 1),
        Text(b, style: body),
      ],
    );
    Widget label(_Pillar p) {
      final parts = p.label.split(' (');
      return Container(
        padding: const EdgeInsets.fromLTRB(4, 1, 4, 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD9A93A), width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(parts[0], style: _baloo(7.5, 800, _howInk, height: 1)),
            if (parts.length > 1)
              Text(
                '(${parts[1]}',
                style: _baloo(5.2, 700, _howInk, height: 1.1),
              ),
          ],
        ),
      );
    }

    final row = s1
        ? const ['hajj', 'salah', 'zakah', 'sawm', 'shahadah']
        : const ['shahadah', 'salah', 'zakah', 'sawm', 'hajj'];
    final rowX = s1
        ? const [210.0, 340.0, 470.0, 600.0, 730.0]
        : const [200.0, 335.0, 470.0, 605.0, 740.0];

    return Positioned(
      left: (_kW - _kHowPanelW) / 2,
      top: _kHowPanelTop,
      width: _kHowPanelW,
      height: _howPanelH,
      child: Opacity(
        opacity: panel,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - panel)),
          child: Transform.scale(
            scale: 0.92 + 0.08 * panel,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    s1 ? _kHowPanelS1 : _kHowPanelS2,
                    fit: BoxFit.fill,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 150 * k,
                  child: const Center(child: _HowTitle()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 292 * k,
                  height: 66 * k,
                  child: Center(
                    child: Text(
                      s1 ? 'Build the Five Pillars' : 'Order the Five Pillars',
                      style: _baloo(17, 800, _howInk),
                    ),
                  ),
                ),
                at(
                  205,
                  406,
                  690,
                  step(
                    s1 ? 'Listen to the question' : 'Listen to the instruction',
                    'Tap the sound button and\nlisten carefully.',
                  ),
                  0.3,
                ),
                if (s1)
                  Positioned(
                    left: 362 * k,
                    top: 548 * k,
                    width: 450 * k,
                    height: 145 * k,
                    child: fadeIn(
                      0.4,
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(6, 1, 6, 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD75E),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'STEP 1 OF 5',
                                style: _baloo(8, 800, _howInk, ls: 0.4),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Amina wants to become\na good Muslim. What is\nthe first pillar?',
                              style: _baloo(12, 700, _howNavy, height: 1.1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 395 * k,
                    top: 560 * k,
                    width: 380 * k,
                    height: 130 * k,
                    child: fadeIn(
                      0.4,
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Put the Five Pillars\nin the correct order\nfrom 1 to 5.',
                          textAlign: TextAlign.center,
                          style: _baloo(12, 700, _howNavy, height: 1.12),
                        ),
                      ),
                    ),
                  ),
                at(
                  205,
                  s1 ? 736 : 748,
                  690,
                  step(
                    s1 ? 'Drag the correct pillar' : 'Drag each pillar',
                    s1
                        ? 'Drag the pillar that matches\nthe answer to the glowing place.'
                        : 'Move every pillar to the correct slot.',
                  ),
                  0.5,
                ),
                at(
                  205,
                  s1 ? 1148 : 1170,
                  690,
                  step(
                    s1 ? 'Build all 5 pillars' : 'Put them in order',
                    s1
                        ? 'Answer all the questions and place\nthe five pillars to complete the mosque!'
                        : 'Arrange the Five Pillars from 1 to 5.',
                  ),
                  0.7,
                ),
                for (var n = 0; n < 5; n++) ...[
                  if (!s1)
                    centred(
                      rowX[n],
                      1328,
                      Text(
                        '${n + 1}',
                        style: _baloo(15, 800, Colors.white, height: 1)
                            .copyWith(
                              shadows: const [
                                Shadow(
                                  color: Color(0x80000000),
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                      ),
                      0.8,
                    ),
                  centred(
                    rowX[n],
                    s1 ? 1492 : 1500,
                    label(_pillar(row[n])),
                    0.8 + n * 0.05,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The hanging lanterns, placed over the cover-fit background and
  /// swinging on their hooks with the same gusts that move the palms.
  Widget _lanterns(double t) => LayoutBuilder(
    builder: (context, box) {
      final k = math.max(
        box.maxWidth / _kStartBgSize.width,
        box.maxHeight / _kStartBgSize.height,
      );
      final ox = (box.maxWidth - _kStartBgSize.width * k) / 2;
      // Matches the gust envelope in five_pillars_bg.frag.
      final gust =
          0.55 +
          0.45 *
              (0.5 + 0.5 * math.sin(t * 0.31)) *
              (0.6 + 0.4 * math.sin(t * 0.17 + 1.3));
      return Stack(
        children: [
          for (final l in _kLanterns)
            Positioned(
              left: ox + l.rect.left * k,
              top: l.rect.top * k,
              width: l.rect.width * k,
              height: l.rect.height * k,
              child: Transform.rotate(
                alignment: Alignment(
                  (l.pivot.dx - l.rect.left) / l.rect.width * 2 - 1,
                  (l.pivot.dy - l.rect.top) / l.rect.height * 2 - 1,
                ),
                // A pendulum pushed by the wind, plus a slower drift.
                angle:
                    0.05 * gust * math.sin(t * 2 * math.pi / 2.4 + l.phase) +
                    0.012 * math.sin(t * 2 * math.pi / 5.3 + l.phase * 2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -l.rect.width * 0.45,
                      right: -l.rect.width * 0.45,
                      top: l.rect.height * 0.25,
                      height: l.rect.height * 0.75,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFFE3A0).withValues(
                                alpha:
                                    0.32 +
                                    0.05 * math.sin(t * 11) * math.sin(t * 6.7),
                              ),
                              const Color(0x00FFE3A0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Image.asset(l.asset, fit: BoxFit.fill),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  /// The game's pill buttons (home, back, sound): 70x42, pressed art
  /// swapped in while held.
  Widget _iconButton(String key, String up, String down, VoidCallback onTap) =>
      SizedBox(
        width: 70,
        height: 42,
        child: _ImageButton(
          key: ValueKey(key),
          up: up,
          down: down,
          onTap: onTap,
        ),
      );

  // ---- play ----

  Widget _buildPlay(double shift) {
    return _fx((now) {
      final u = _once(now - _playT0, 0.55);
      final e = _sceneCurve.transform(u);
      return Opacity(
        // Coming in under the flash, the scene is already fully there.
        opacity: _leaving ? 1 : e,
        child: Transform.scale(
          scale: 1.05 - 0.05 * e,
          alignment: const Alignment(0, -0.1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Wider-than-phone screens: the scene art covers the sides
              // the stage's own background doesn't reach.
              const ColoredBox(color: _sceneBase),
              Image.asset(_kSceneArt, fit: BoxFit.cover),
              _stage(
                MouseRegion(
                  onHover: _onHover,
                  onExit: (_) {
                    if (_hover != -1) setState(() => _hover = -1);
                  },
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onDown,
                    onPointerMove: _onMove,
                    onPointerUp: _onUp,
                    onPointerCancel: _onUp,
                    child: _buildScene(shift),
                  ),
                ),
                _sceneAlign,
              ),
              if (_leaving) _buildFlash(now),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFlash(double now) {
    final e = Curves.easeOutCubic.transform(_once(now - _playT0, _kFlashDur));
    return IgnorePointer(
      child: ColoredBox(color: _kFlash.withValues(alpha: 1 - e)),
    );
  }

  Widget _uiDrop(double delay, double dy, double dur, Widget child) => _fx((
    now,
  ) {
    final e = _dropCurve.transform(_once(now - _playT0, dur, delay));
    return Opacity(
      opacity: e,
      child: Transform.translate(offset: Offset(0, dy * (1 - e)), child: child),
    );
  });

  Widget _buildScene(double shift) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: (_kW - _kBgW) * 0.5,
          top: _kBgTop,
          width: _kBgW,
          height: _kBgH,
          child: Image.asset(_kSceneArt, fit: BoxFit.fill),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 16 + shift,
          child: _uiDrop(0.12, -18, 0.5, _buildTopBar()),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 70 + shift,
          child: _uiDrop(0.2, -18, 0.5, _buildPromptCard()),
        ),
        for (var i = 0; i < 5; i++)
          Positioned.fromRect(rect: _slotRect(i), child: _buildSlot(i)),
        Positioned(
          left: 0,
          right: 0,
          top: _kTrayT,
          bottom: -_kH,
          child: _uiDrop(0.28, 26, 0.55, _buildTray()),
        ),
        if (_cheer != null)
          Positioned(
            left: 0,
            right: 0,
            top: _kH * 0.62,
            child: IgnorePointer(child: Center(child: _buildCheer())),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    final count = _placedCount;
    return Row(
      children: [
        _iconButton('fp-back', _kBtnBack, _kBtnBackDown, _reset),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(color: Color(0x2E1B4E8A), offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: _scenarios
                            ? (i < count
                                  ? _pipDone
                                  : i == _step
                                  ? _pipNow
                                  : _pipIdle)
                            : (_placed[i] != null ? _pipDone : _pipIdle),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Voice-over is off in the prototype's defaults, so the prompt
        // button only acknowledges the tap.
        _iconButton('fp-sound', _kBtnSound, _kBtnSoundDown, _pick),
      ],
    );
  }

  Widget _buildPromptCard() {
    final String label;
    final String prompt;
    if (_scenarios) {
      label = 'Step ${math.min(_step + 1, 5)} of 5';
      prompt = _step < 5 ? _kQuestions[_step].$1 : 'Mosque complete!';
    } else {
      label = '$_placedCount of 5 placed';
      prompt = _kInstruction;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardEdge, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47142846),
            offset: Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _blueBottom,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🕌', style: TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: _baloo(13, 700, _labelInk, ls: 0.6),
                ),
                Text(
                  prompt,
                  key: const ValueKey('fp-prompt'),
                  style: _baloo(18, 600, _promptInk, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Session 1's single lit slot: a beam of light settling onto the
  /// socket and a warm pool on the floor ([behind] the glow), then rising
  /// motes and twinkles in front of it.
  Widget _slotMagic(int i, {required bool behind, double? from}) {
    final sock = _kSocketRects[i].shift(-_slotRect(i).topLeft);
    final area = Rect.fromLTRB(
      sock.left - 44,
      sock.top - 150,
      sock.right + 44,
      sock.bottom + 26,
    );
    return Positioned.fromRect(
      rect: area,
      child: IgnorePointer(
        child: _fx(
          (now) => CustomPaint(
            painter: _SlotMagicPainter(
              now - (from ?? _glowT0[i]),
              sock.shift(-area.topLeft),
              behind,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(int i) {
    final id = _placed[i];
    final p = id == null ? null : _pillar(id);
    final active = _glowActive(i);
    final shaking = _shakingSlot() == i;
    final strong = _scenarios;
    final dur = _scenarios ? 1.4 : 2.0;
    final delay = _scenarios ? 0.0 : i * 0.16;

    Widget slot = Stack(
      key: ValueKey('fp-slot-$i'),
      clipBehavior: Clip.none,
      children: [
        if (p != null && _finaleT0 != null)
          _slotMagic(i, behind: true, from: _finaleT0! + i * _kLightGap),
        if (p != null)
          Positioned(
            left: _kSlotW / 2 + p.ml - p.w / 2,
            bottom: -(p.mb + 2),
            width: p.w,
            height: p.w * _kPillarAspect,
            child: _fx((now) {
              final u = _once(now - _popT0[i], 0.45);
              final s = _kf(u, [0, 0.6, 1], [0.4, 1.12, 1], _popCurve);
              final o = _kf(u, [0, 0.6, 1], [0, 1, 1], _popCurve);
              final f0 = _finaleT0;
              final tl = f0 == null ? -1.0 : now - f0 - i * _kLightGap;
              final lit = tl < 0
                  ? 0.0
                  : Curves.easeOutCubic.transform(_c01(tl / _kLightDur));
              final flash = tl < 0 ? 0.0 : 1 - _c01(tl / 0.9);
              final breathe = 0.5 + 0.5 * math.sin(now * 2.2 + i);
              Widget tinted(Color c) => Image.asset(
                p.src,
                fit: BoxFit.fill,
                cacheWidth: _kPillarCache,
                color: c,
                colorBlendMode: BlendMode.srcIn,
              );
              return Opacity(
                opacity: _c01(o),
                child: Transform.scale(
                  scale: s * (1 + 0.06 * flash * lit),
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      if (lit > 0)
                        Opacity(
                          opacity: lit * (0.75 + 0.25 * breathe),
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 12,
                              sigmaY: 12,
                              tileMode: TileMode.decal,
                            ),
                            child: tinted(const Color(0xFFFFC53A)),
                          ),
                        ),
                      _slotArt(p),
                      if (flash > 0)
                        Opacity(
                          opacity: 0.85 * flash * lit,
                          child: tinted(const Color(0xFFFFF7D6)),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        if (p != null && _finaleT0 != null)
          _slotMagic(i, behind: false, from: _finaleT0! + i * _kLightGap),
        if (active) ...[
          Positioned(
            left: -_kSlotW * 0.3,
            right: -_kSlotW * 0.3,
            top: -_kSlotH * 0.22,
            bottom: -_kSlotH * 0.14,
            child: _fx((now) {
              final u = _loop(now - _glowT0[i] - delay, dur);
              final pre = now - _glowT0[i] < delay;
              final o = pre
                  ? 1.0
                  : _kf(u, [0, 0.5, 1], [0.6, 1, 0.6], _easeInOut);
              return Opacity(
                opacity: o,
                child: CustomPaint(
                  painter: _HaloPainter(
                    strong ? 0.6 : 0.46,
                    strong ? 0.32 : 0.24,
                  ),
                ),
              );
            }),
          ),
          if (_scenarios) _slotMagic(i, behind: true),
          Positioned.fromRect(
            rect: _kSocketRects[i].shift(-_slotRect(i).topLeft),
            child: _fx((now) {
              final pre = now - _glowT0[i] < delay;
              final u = _loop(now - _glowT0[i] - delay, dur);
              final pulse = pre
                  ? 1.0
                  : _kf(u, [0, 0.5, 1], [0, 1, 0], _easeInOut);
              // A soft band of light rising up the column every cycle.
              final sweep = pre
                  ? -1.0
                  : 1.4 - 2.8 * _loop(now - _glowT0[i], 2.6);
              final art = _socketGlow(i);
              Widget bloom(double sigma, Color c) => ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.decal,
                ),
                child: Image.asset(
                  art,
                  fit: BoxFit.fill,
                  color: c,
                  colorBlendMode: BlendMode.srcIn,
                ),
              );
              return IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: 0.75 + 0.25 * pulse,
                      child: bloom(
                        12 + 8 * pulse,
                        strong
                            ? const Color(0xFFFFA000)
                            : const Color(0xE6FFA000),
                      ),
                    ),
                    Opacity(
                      opacity: 0.85 + 0.15 * pulse,
                      child: bloom(4 + 2 * pulse, const Color(0xFFFFD84A)),
                    ),
                    Opacity(
                      opacity: 0.9 + 0.1 * pulse,
                      child: Image.asset(art, fit: BoxFit.fill),
                    ),
                    ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (r) => LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: const [
                          Color(0x00FFFFFF),
                          Color(0x99FFFFF0),
                          Color(0x00FFFFFF),
                        ],
                        stops: [
                          _c01((sweep + 1) / 2 - 0.12),
                          _c01((sweep + 1) / 2),
                          _c01((sweep + 1) / 2 + 0.12),
                        ],
                      ).createShader(r),
                      child: Image.asset(art, fit: BoxFit.fill),
                    ),
                  ],
                ),
              );
            }),
          ),
          if (_scenarios) _slotMagic(i, behind: false),
          if (!_scenarios)
            Positioned(
              left: _kSlotW / 2 - 13,
              bottom: 6,
              width: 26,
              height: 26,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xF2FFFCF0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0A92C), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D50320A),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  '${i + 1}',
                  style: _baloo(15, 800, const Color(0xFFA97612), height: 1),
                ),
              ),
            ),
        ],
      ],
    );

    if (shaking) {
      final inner = slot;
      slot = _fx((now) {
        final u = _once(now - _shakeT0, 0.4);
        final dx = _kf(u, [0, 0.25, 0.75, 1], [0, -7, 7, 0], _ease);
        return Transform.translate(offset: Offset(dx, 0), child: inner);
      });
    }
    return slot;
  }

  static Widget _slotArt(_Pillar p) => RepaintBoundary(
    child: _shadowed(
      p.src,
      dy: 6,
      blur: 6,
      shadow: _shadowInk.withValues(alpha: 0.35),
      cacheWidth: _kPillarCache,
    ),
  );

  Widget _buildTray() {
    return Stack(
      clipBehavior: Clip.none,
      children: [for (var j = 0; j < _order.length; j++) _buildTrayItem(j)],
    );
  }

  Widget _buildTrayItem(int j) {
    final id = _order[j];
    final p = _pillar(id);
    final r = _itemArtRect(j, p).shift(const Offset(0, -_kTrayT));
    final hidden = _placed.contains(id) || _dragId == id;
    return Positioned.fromRect(
      rect: r,
      child: AnimatedSlide(
        key: ValueKey('fp-tray-$id'),
        offset: Offset(0, _hover == j ? -8 / r.height : 0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        child: Opacity(
          opacity: hidden ? 0 : 1,
          child: RepaintBoundary(
            child: _shadowed(
              p.src,
              dy: 5,
              blur: 5,
              shadow: _shadowInk.withValues(alpha: 0.3),
              cacheWidth: _kPillarCache,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheer() {
    return _fx((now) {
      final u = _once(now - _cheerT0, 0.4);
      final s = _kf(u, [0, 0.6, 1], [0.4, 1.12, 1], _popCurve);
      final o = _kf(u, [0, 0.6, 1], [0, 1, 1], _popCurve);
      return Opacity(
        opacity: _c01(o),
        child: Transform.scale(
          scale: s,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xF7FFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47000000),
                  offset: Offset(0, 10),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Text('⭐ ${_cheer ?? ''}', style: _baloo(26, 800, _cheerInk)),
          ),
        ),
      );
    });
  }

  Widget _buildGhost() {
    final p = _pillar(_dragId!);
    final h = p.w * _kPillarAspect;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _dragAt.dx - p.w / 2,
          top: _dragAt.dy - h * 0.62,
          width: p.w,
          height: h,
          child: Transform.rotate(
            angle: -3 * math.pi / 180,
            child: Transform.scale(
              scale: 1.06,
              child: _shadowed(
                p.src,
                dy: 14,
                blur: 16,
                shadow: Colors.black.withValues(alpha: 0.4),
                cacheWidth: _kPillarCache,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- done ----

  int get _stars => _errors == 0
      ? 3
      : _errors <= 2
      ? 2
      : 1;

  Widget _buildDone() {
    final shader = _bgShader;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The start screen's courtyard, lanterns and all.
        if (shader != null)
          _fx(
            (now) => Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _StartBgPainter(
                    shader,
                    _bgImage!,
                    _bgMask!,
                    _bgPalms!,
                    now,
                    1,
                  ),
                ),
                _lanterns(now),
              ],
            ),
          )
        else
          Image.asset(
            _kStartBg,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        IgnorePointer(
          child: _fx(
            (now) => CustomPaint(painter: _ConfettiPainter(now - _doneT0)),
          ),
        ),
        _stage(_fx((now) => _buildDoneCard(now - _doneT0))),
      ],
    );
  }

  /// End-screen layout, placed over the reference composition (851x1847)
  /// scaled onto the 393x852 stage.
  Widget _buildDoneCard(double t) {
    double pop(double delay, [double dur = 0.45]) =>
        _dropCurve.transform(_once(t, dur, delay));
    Widget rise(double e, Widget child, [double dy = 14]) => Opacity(
      opacity: _c01(e),
      child: Transform.translate(offset: Offset(0, dy * (1 - e)), child: child),
    );
    Widget at(double l, double tp, double w, double h, Widget child) =>
        Positioned(left: l, top: tp, width: w, height: h, child: child);

    final card = pop(0, 0.55);
    final accuracy = (5 / (5 + _errors) * 100).round();
    final secs = (_doneT0 - _playT0).round();
    final time = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final xpShown = (widget.xp * Curves.easeOut.transform(_once(t, 0.9, 1.0)))
        .round();

    Widget star({double size = 40, bool on = true}) => Image.asset(
      _kDoneStar,
      width: size,
      fit: BoxFit.contain,
      color: on ? null : const Color(0xFFF1E9D8),
      colorBlendMode: on ? null : BlendMode.modulate,
      opacity: on ? null : const AlwaysStoppedAnimation(0.55),
    );

    Widget stat(Widget icon, String value, String label, Color c, Color bg) =>
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.55), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.18),
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              SizedBox(width: 26, height: 26, child: icon),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: _baloo(20, 800, c, height: 1)),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: _baloo(10.5, 700, _doneInk, height: 1.15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    Widget recapRow(int i) {
      final p = _kPillars[i];
      final (meaning, colour) = _kPillarRecap[p.id]!;
      final tries = 1 + (_missed[p.id] ?? 0);
      final parts = p.label.split(' (');
      return Container(
        padding: const EdgeInsets.fromLTRB(7, 2, 8, 2),
        decoration: BoxDecoration(
          color: Color.lerp(Colors.white, colour, 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colour.withValues(alpha: 0.3), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: colour.withValues(alpha: 0.1),
              offset: const Offset(0, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(colour, Colors.white, 0.2)!, colour],
                ),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: colour.withValues(alpha: 0.4),
                    offset: const Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Text(
                '${i + 1}',
                style: _baloo(15, 800, Colors.white, height: 1),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 28,
              height: 46,
              child: Image.asset(p.src, fit: BoxFit.contain, cacheWidth: 120),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: parts[0],
                            style: _baloo(16, 800, colour, height: 1.1),
                          ),
                          if (parts.length > 1)
                            TextSpan(
                              text: '  (${parts[1]}',
                              style: _baloo(11.5, 700, _doneInk, height: 1.1),
                            ),
                        ],
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      meaning,
                      style: _baloo(10.5, 600, _doneInk, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tries == 1
                    ? const Color(0xFFDDF5E3)
                    : const Color(0xFFFFEBC6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tries == 1 ? '✓ 1st try' : '$tries tries',
                style: _baloo(
                  10.5,
                  800,
                  tries == 1
                      ? const Color(0xFF1F7A3C)
                      : const Color(0xFF9A5A0A),
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    const navy = Color(0xFF14306E);
    return Opacity(
      opacity: _c01(card),
      child: Transform.translate(
        offset: Offset(0, 30 * (1 - card)),
        child: Transform.scale(
          scale: 0.94 + 0.06 * card,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              at(20, 112, 353, 662, Image.asset(_kDoneFrame, fit: BoxFit.fill)),
              // Title with its little constellation of stars.
              for (final (x, y, sz, d) in const [
                (45.0, 170.0, 20.0, 0.35),
                (68.0, 152.0, 12.0, 0.45),
                (322.0, 150.0, 12.0, 0.5),
                (330.0, 168.0, 21.0, 0.4),
              ])
                Positioned(
                  left: x,
                  top: y,
                  child: Transform.scale(
                    scale: pop(d, 0.5) * (0.9 + 0.1 * math.sin(t * 3 + x)),
                    child: star(size: sz),
                  ),
                ),
              at(
                0,
                136,
                _kW,
                54,
                Center(
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * pop(0.2, 0.55),
                    child: Opacity(
                      opacity: _c01(pop(0.2)),
                      child: const _OutlinedText(
                        'Mumtāz!',
                        size: 50,
                        fill: [
                          Color(0xFFFFF3B0),
                          Color(0xFFFFC928),
                          Color(0xFFF29A0E),
                        ],
                        stroke: Color(0xFF6B3208),
                        strokeWidth: 7,
                      ),
                    ),
                  ),
                ),
              ),
              at(
                40,
                191,
                313,
                40,
                rise(
                  pop(0.35),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _scenarios
                            ? 'You answered all five questions\nand built the mosque!'
                            : 'You put the Five Pillars in order\nand built the mosque!',
                        textAlign: TextAlign.center,
                        style: _baloo(15.5, 800, navy, height: 1.18),
                      ),
                    ),
                  ),
                ),
              ),
              for (var k = 0; k < 3; k++)
                at(
                  124 + k * 50.0,
                  236,
                  46,
                  46,
                  Transform.scale(
                    scale: pop(0.55 + k * 0.2, 0.5),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (k < _stars)
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.55 + 0.25 * math.sin(t * 2.6 + k),
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: 7,
                                  sigmaY: 7,
                                ),
                                child: Image.asset(
                                  _kDoneStar,
                                  color: const Color(0xFFFFD34D),
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(child: star(on: k < _stars)),
                      ],
                    ),
                  ),
                ),
              at(
                37,
                291,
                319,
                53,
                rise(
                  pop(0.95),
                  Row(
                    children: [
                      Expanded(
                        child: stat(
                          star(size: 26),
                          '+$xpShown',
                          'XP earned',
                          const Color(0xFFE08A00),
                          const Color(0xFFFFF4DA),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: stat(
                          const Icon(
                            Icons.track_changes_rounded,
                            size: 26,
                            color: Color(0xFF1F9A46),
                          ),
                          '$accuracy%',
                          'Accuracy',
                          const Color(0xFF1F7A3C),
                          const Color(0xFFE6F7EA),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: stat(
                          const Icon(
                            Icons.access_time_filled_rounded,
                            size: 26,
                            color: Color(0xFF1F6FD8),
                          ),
                          time,
                          'Time',
                          const Color(0xFF1F5FC8),
                          const Color(0xFFE6F0FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              at(
                40,
                358,
                313,
                28,
                rise(
                  pop(1.15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.4,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0x00D9A93A), Color(0xFFD9A93A)],
                            ),
                          ),
                        ),
                      ),
                      Text(
                        ' ◆ ',
                        style: _baloo(10, 800, const Color(0xFFD9A93A)),
                      ),
                      Flexible(
                        flex: 8,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'The Five Pillars of Islam',
                            style: _baloo(15.5, 800, const Color(0xFF6B3208)),
                          ),
                        ),
                      ),
                      Text(
                        ' ◆ ',
                        style: _baloo(10, 800, const Color(0xFFD9A93A)),
                      ),
                      Expanded(
                        child: Container(
                          height: 1.4,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD9A93A), Color(0x00D9A93A)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < 5; i++)
                at(
                  36,
                  389 + i * 60.0,
                  321,
                  53,
                  rise(pop(1.25 + i * 0.1, 0.4), recapRow(i)),
                ),
              at(
                34,
                694,
                325,
                54,
                rise(
                  pop(1.9, 0.5),
                  Row(
                    children: [
                      Expanded(
                        child: _ImageButton(
                          key: const ValueKey('fp-again'),
                          up: _kHowReady,
                          down: _kHowReadyDown,
                          onTap: _start,
                          label: 'Play Again',
                          labelSize: 21,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ImageButton(
                          key: const ValueKey('fp-continue'),
                          up: _kHowReady,
                          down: _kHowReadyDown,
                          onTap: _finish,
                          label: 'Continue \u203A',
                          labelSize: 21,
                        ),
                      ),
                    ],
                  ),
                  20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotMagicPainter extends CustomPainter {
  _SlotMagicPainter(this.t, this.sock, this.behind);

  /// Seconds since the slot lit up.
  final double t;
  final Rect sock;
  final bool behind;

  static double _h(int i, int k) {
    final x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  void _twinkle(Canvas c, Offset o, double r, double a) {
    if (a <= 0.01 || r <= 0.1) return;
    final glow = Paint()
      ..color = const Color(0xFFFFE08A).withValues(alpha: 0.55 * a)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    c.drawCircle(o, r * 0.9, glow);
    final star = Path();
    for (var k = 0; k < 8; k++) {
      final ang = k * math.pi / 4 - math.pi / 2;
      final rr = k.isEven ? r : r * 0.22;
      final pt = o + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
      k == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    star.close();
    c.drawPath(
      star,
      Paint()..color = const Color(0xFFFFFDF0).withValues(alpha: a),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t < 0) return;
    final enter = Curves.easeOutCubic.transform(_c01(t / 0.7));
    final breathe = 0.5 + 0.5 * math.sin(t * 2.4);
    final cx = sock.center.dx;
    final base = sock.bottom - 4;
    final w = sock.width;

    if (behind) {
      // Beam: narrow at the top, spreading onto the socket, sliding down
      // into place when the slot lights up.
      final top = sock.top - 140 * enter;
      final beam = Path()
        ..moveTo(cx - w * 0.28, top)
        ..lineTo(cx + w * 0.28, top)
        ..lineTo(cx + w * 0.85, base)
        ..lineTo(cx - w * 0.85, base)
        ..close();
      final beamRect = Rect.fromLTRB(cx - w, top, cx + w, base);
      canvas.drawPath(
        beam,
        Paint()
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0x00FFE6A0),
              Color.fromRGBO(255, 226, 150, (0.22 + 0.1 * breathe) * enter),
              Color.fromRGBO(255, 214, 110, (0.32 + 0.12 * breathe) * enter),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(beamRect),
      );
      // Soft moving streaks inside the beam.
      for (var k = 0; k < 3; k++) {
        final phase = t * (0.35 + 0.1 * k) + k * 2.1;
        final sx = cx + math.sin(phase) * w * 0.35;
        final a = (0.14 + 0.1 * math.sin(phase * 1.7)).clamp(0.0, 1.0) * enter;
        final streak = Path()
          ..moveTo(sx - 2, top + 8)
          ..lineTo(sx + 2, top + 8)
          ..lineTo(sx + w * 0.12 + (sx - cx) * 0.6, base)
          ..lineTo(sx - w * 0.12 + (sx - cx) * 0.6, base)
          ..close();
        canvas.drawPath(
          streak,
          Paint()
            ..blendMode = BlendMode.plus
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0x00FFF6D8),
                Color.fromRGBO(255, 246, 216, a),
              ],
            ).createShader(beamRect),
        );
      }
      // Warm pool of light on the step.
      final pool = Rect.fromCenter(
        center: Offset(cx, base + 4),
        width: w * (2.0 + 0.2 * breathe),
        height: w * 0.42,
      );
      canvas.drawOval(
        pool,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 236, 170, (0.55 + 0.2 * breathe) * enter),
              Color.fromRGBO(255, 190, 60, 0.25 * enter),
              const Color(0x00FFB020),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(pool),
      );
      return;
    }

    // Motes drifting up from the base, swaying as they rise.
    for (var k = 0; k < 16; k++) {
      final speed = 0.28 + 0.2 * _h(k, 1);
      final life = (t * speed + _h(k, 2)) % 1.0;
      final y = base - life * (sock.height + 60);
      final x =
          cx +
          (_h(k, 3) - 0.5) * w * 1.3 +
          math.sin(t * (1.2 + _h(k, 4)) + k) * 5;
      final fade = math.sin(life * math.pi) * enter;
      final r = 0.9 + 1.6 * _h(k, 5);
      canvas.drawCircle(
        Offset(x, y),
        r * 2.6,
        Paint()
          ..color = const Color(0xFFFFD86A).withValues(alpha: 0.35 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = const Color(0xFFFFFBEA).withValues(alpha: 0.95 * fade),
      );
    }

    // Twinkles around the capital, each on its own beat.
    const spots = [
      Offset(-0.62, 0.06),
      Offset(0.66, 0.16),
      Offset(-0.5, 0.52),
      Offset(0.58, 0.7),
    ];
    for (var k = 0; k < spots.length; k++) {
      final beat = (t * 0.9 + k * 0.27) % 1.0;
      final a = math.pow(math.sin(beat * math.pi), 3).toDouble() * enter;
      final o = Offset(
        cx + spots[k].dx * w,
        sock.top + spots[k].dy * sock.height,
      );
      _twinkle(canvas, o, 3.5 + 3.5 * a, a);
    }
  }

  @override
  bool shouldRepaint(_SlotMagicPainter old) => old.t != t;
}

/// Gold, green and blue confetti drifting down over the finished mosque:
/// a burst in the first seconds, then a light steady fall.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;

  static const _colours = [
    Color(0xFFFFC72C),
    Color(0xFF2FB24C),
    Color(0xFF3A8DEB),
    Color(0xFFF26B5B),
    Color(0xFFFFF1B8),
  ];

  static double _h(int i, int k) {
    final x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 46; i++) {
      final speed = 0.09 + 0.08 * _h(i, 1);
      final start = _h(i, 2) * 3.0;
      final life = (t - start * 0.35) * speed;
      if (life < 0) continue;
      final y = (life % 1.25) - 0.1;
      final x = _h(i, 3) + 0.04 * math.sin(t * (1 + _h(i, 4)) + i);
      final a = t < 0.3 ? t / 0.3 : 1.0;
      paint.color = _colours[i % _colours.length].withValues(alpha: 0.9 * a);
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(t * (2 + 3 * _h(i, 5)) + i);
      final w = 5 + 4 * _h(i, 6);
      final flip = math.cos(t * (3 + 2 * _h(i, 7)) + i).abs();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: w,
            height: w * 0.55 * (0.3 + flip),
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// The start screen's Play button: its pressed state only drops the lower
/// shadow (the bob animation owns the transform).
/// A standing mascot grounded on the courtyard floor: a soft contact
/// shadow under the feet and a cast shadow thrown down-left, away from
/// the sun in the art's top-right corner, sharp at the feet and fading
/// with distance.
class _Mascot extends StatelessWidget {
  const _Mascot(this.asset, {required this.feetX});
  final String asset;

  /// Horizontal centre of the feet, as a fraction of the art's width.
  final double feetX;

  static const _shadowInk = Color(0xFF3A2410);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        Widget silhouette(double blur, double alpha) => ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
            tileMode: TileMode.decal,
          ),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.white.withValues(alpha: alpha),
                Colors.white.withValues(alpha: alpha * 0.35),
                Colors.transparent,
              ],
              stops: const [0, 0.45, 0.95],
            ).createShader(r),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              color: _shadowInk,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        );
        // Flip about the feet line, flatten onto the floor, lean left.
        final cast = Matrix4.identity()
          ..setEntry(1, 1, -0.26)
          ..setEntry(0, 1, 0.62);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: cast,
                child: silhouette(2.5, 0.42),
              ),
            ),
            Positioned(
              left: w * (feetX - 0.36),
              width: w * 0.72,
              top: h - 11,
              height: 16,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 3),
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: OvalBorder(),
                    color: Color(0x803A2410),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: Image.asset(asset, fit: BoxFit.contain)),
          ],
        );
      },
    );
  }
}

class _StartBgPainter extends CustomPainter {
  _StartBgPainter(
    this.shader,
    this.image,
    this.mask,
    this.palms,
    this.time,
    this.zoom,
  );
  final ui.FragmentShader shader;
  final ui.Image image;
  final ui.Image mask;
  final ui.Image palms;
  final double time;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, image.width.toDouble())
      ..setFloat(3, image.height.toDouble())
      ..setFloat(4, time)
      ..setFloat(5, zoom)
      ..setFloat(6, _kPillarsFocus.dx / _kStartBgSize.width)
      ..setFloat(7, _kPillarsFocus.dy / _kStartBgSize.height)
      ..setImageSampler(0, image)
      ..setImageSampler(1, mask)
      ..setImageSampler(2, palms);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_StartBgPainter old) =>
      old.time != time || old.zoom != zoom;
}

class _ImageButton extends StatefulWidget {
  const _ImageButton({
    super.key,
    required this.up,
    required this.down,
    required this.onTap,
    this.label,
    this.labelSize = 31,
  });
  final String up;
  final String down;
  final VoidCallback onTap;
  final String? label;
  final double labelSize;

  @override
  State<_ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<_ImageButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _down ? widget.down : widget.up,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            if (label != null)
              Center(
                child: _OutlinedText(
                  label,
                  size: widget.labelSize,
                  fill: const [Colors.white, Color(0xFFFFF4D6)],
                  stroke: const Color(0xFF14450F),
                  strokeWidth: 6,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chunky game-title lettering: a gradient fill over a thick outline,
/// with a drop shadow underneath.
class _OutlinedText extends StatelessWidget {
  const _OutlinedText(
    this.text, {
    required this.size,
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });
  final String text;
  final double size;
  final List<Color> fill;
  final Color stroke;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final base = _baloo(size, 800, Colors.white, height: 1);
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(0, size * 0.09),
          child: Text(
            text,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..color = stroke.withValues(alpha: 0.55),
              color: null,
            ),
          ),
        ),
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
            color: null,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fill,
          ).createShader(r),
          child: Text(text, style: base),
        ),
      ],
    );
  }
}

class _HowTitle extends StatelessWidget {
  const _HowTitle();

  @override
  Widget build(BuildContext context) => const _OutlinedText(
    'How to Play',
    size: 46,
    fill: [Color(0xFFFFF3B0), Color(0xFFFFC928), Color(0xFFF29A0E)],
    stroke: Color(0xFF6B3208),
    strokeWidth: 7,
  );
}

/// The active slot's warm halo: CSS
/// `radial-gradient(58% 46% at 50% 52%, a1 0%, a2 48%, transparent 76%)`.
class _HaloPainter extends CustomPainter {
  const _HaloPainter(this.a1, this.a2);
  final double a1;
  final double a2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.52);
    final rx = size.width * 0.58;
    final ry = size.height * 0.46;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(rx, ry);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          Color.fromRGBO(120, 62, 0, a1),
          Color.fromRGBO(120, 62, 0, a2),
          const Color.fromRGBO(120, 62, 0, 0),
        ],
        [0, 0.48, 0.76],
      );
    canvas.drawRect(
      Rect.fromLTRB(
        -c.dx / rx,
        -c.dy / ry,
        (size.width - c.dx) / rx,
        (size.height - c.dy) / ry,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.a1 != a1 || old.a2 != a2;
}
