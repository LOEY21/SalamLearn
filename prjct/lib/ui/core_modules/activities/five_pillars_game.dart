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
const String _kHowPanel = '$_kA/howto_panel.png';
const String _kHowReady = '$_kA/howto_ready.png';
const String _kHowReadyDown = '$_kA/howto_ready_down.png';

/// How-to-play panel art is 915x1497; drawn 338 wide on the stage.
const double _kHowPanelW = 338;
const double _kHowPanelScale = _kHowPanelW / 915;
const Color _howInk = Color(0xFF5A2E0E);
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
const _greenTop = Color(0xFF3FC463);
const _greenBottom = Color(0xFF1F8F42);
const _greenEdge = Color(0xFF14662F);
const _blueTop = Color(0xFF4AA3EF);
const _blueBottom = Color(0xFF1B6DC0);
const _blueEdge = Color(0xFF12508F);
const _backInk = Color(0xFF1B4E8A);
const _pipDone = Color(0xFF2EA34F);
const _pipNow = Color(0xFFFFC72C);
const _pipIdle = Color(0x2E1B4E8A);
const _cardBg = Color(0xF5FFFCF0);
const _cardEdge = Color(0xFFE6C56B);
const _labelInk = Color(0xFFB07D16);
const _promptInk = Color(0xFF24324A);
const _cheerInk = Color(0xFF1F7A3C);
const _gold = Color(0xFFFFC72C);
const _doneScrim = Color(0x8C0B284A);
const _doneCard = Color(0xFAFFFCF3);
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
      _kHowPanel,
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
        _fanfare();
        setState(() {
          _screen = _Screen.done;
          _doneT0 = _now;
          _setCheer(null);
        });
      } else {
        setState(() => _setCheer(null));
      }
    });
  }

  void _wrongScenario(bool onSlot) {
    _nope();
    if (!onSlot) return;
    _errors++;
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
        if (!mounted) return;
        _fanfare();
        setState(() {
          _screen = _Screen.done;
          _doneT0 = _now;
          _setCheer(null);
        });
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
    if (_dragId != null || _screen != _Screen.play) return;
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
                child: _backButton(widget.onExit!),
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
    final move = _howTo ? Curves.easeInOutCubic.transform(_c01(ho / 0.7)) : 0.0;
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
                    Positioned.fromRect(
                      rect: Rect.lerp(
                        const Rect.fromLTWH(4, 427, 171, 252),
                        const Rect.fromLTWH(2, 552, 166, 245),
                        move,
                      )!,
                      child: _arrive(
                        girl,
                        const _Mascot(_kStartGirl, feetX: 0.4),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: Rect.lerp(
                        const Rect.fromLTWH(243, 423, 148, 250),
                        const Rect.fromLTWH(254, 578, 132, 222),
                        move,
                      )!,
                      child: _arrive(
                        boy,
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
                        left: 76,
                        top: 752,
                        width: 240,
                        height: 70,
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
                                label: "I'm Ready!",
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

  /// The how-to-play card: panel art with its blank title, ribbon and
  /// step areas filled in. Positions are in the art's own pixels.
  Widget _howPanel(double ho) {
    final panel = _dropCurve.transform(_once(ho, 0.55, 0.15));
    Widget at(double ax, double ay, double aw, Widget child, [double d = 0]) {
      final e = Curves.easeOut.transform(_once(ho, 0.4, d));
      return Positioned(
        left: ax * _kHowPanelScale,
        top: ay * _kHowPanelScale,
        width: aw * _kHowPanelScale,
        child: Opacity(
          opacity: e,
          child: Transform.translate(
            offset: Offset(10 * (1 - e), 0),
            child: child,
          ),
        ),
      );
    }

    final step = _baloo(15.5, 700, _howInk, height: 1.12);
    return Positioned(
      left: (_kW - _kHowPanelW) / 2,
      top: 30,
      width: _kHowPanelW,
      height: 1497 * _kHowPanelScale,
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
                  child: Image.asset(_kHowPanel, fit: BoxFit.fill),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 178 * _kHowPanelScale,
                  child: const Center(child: _HowTitle()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 336 * _kHowPanelScale,
                  height: 64 * _kHowPanelScale,
                  child: Center(
                    child: Text(
                      'Build the Five Pillars',
                      style: _baloo(16.5, 800, _howInk),
                    ),
                  ),
                ),
                at(
                  215,
                  478,
                  330,
                  Text('Listen to\nthe question.', style: step),
                  0.35,
                ),
                at(
                  215,
                  672,
                  400,
                  Text(
                    'Drag the correct\npillar to the\nglowing place.',
                    style: step,
                  ),
                  0.47,
                ),
                at(
                  215,
                  1124,
                  330,
                  Text(
                    'Build all 5 pillars\nto complete\nthe mosque.',
                    style: step,
                  ),
                  0.59,
                ),
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

  Widget _backButton(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      key: const ValueKey('fp-back'),
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Color(0x4D1B4E8A), offset: Offset(0, 4)),
        ],
      ),
      child: Text('‹', style: _baloo(22, 800, _backInk)),
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
        _backButton(_reset),
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
        GestureDetector(
          // Voice-over is off in the prototype's defaults, so the prompt
          // button only acknowledges the tap.
          onTap: _pick,
          child: Container(
            width: 54,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_blueTop, _blueBottom],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(color: _blueEdge, offset: Offset(0, 4)),
              ],
            ),
            child: const Text('🔊', style: TextStyle(fontSize: 21)),
          ),
        ),
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
              return Opacity(
                opacity: _c01(o),
                child: Transform.scale(
                  scale: s,
                  alignment: Alignment.bottomCenter,
                  child: _slotArt(p),
                ),
              );
            }),
          ),
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

  Widget _buildDone() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(_kSceneArt, fit: BoxFit.cover),
        const ColoredBox(color: _doneScrim),
        _stage(
          Padding(
            padding: const EdgeInsets.all(26),
            child: Center(
              child: _fx((now) {
                final e = _ease.transform(_once(now - _doneT0, 0.5));
                return Opacity(
                  opacity: e,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - e)),
                    child: _buildDoneCard(),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      decoration: BoxDecoration(
        color: _doneCard,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _gold, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 20),
            blurRadius: 50,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Mumtāz!', style: _baloo(44, 800, _cheerInk, height: 1)),
          const SizedBox(height: 14),
          Text(
            'You built the mosque. These are the Five Pillars of Islam.',
            textAlign: TextAlign.center,
            style: _baloo(19, 600, _doneInk),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _kPillars.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1 / _kPillarAspect,
                    child: _shadowed(
                      _kPillars[i].src,
                      dy: 5,
                      blur: 5,
                      shadow: _shadowInk.withValues(alpha: 0.3),
                      cacheWidth: _kPillarCache,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _doneButton(
            'Play again',
            const ValueKey('fp-again'),
            _greenTop,
            _greenBottom,
            _greenEdge,
            _start,
          ),
          const SizedBox(height: 14),
          _doneButton(
            'Continue',
            const ValueKey('fp-continue'),
            _blueTop,
            _blueBottom,
            _blueEdge,
            _finish,
          ),
        ],
      ),
    );
  }

  Widget _doneButton(
    String label,
    Key key,
    Color top,
    Color bottom,
    Color edge,
    VoidCallback onTap,
  ) => GestureDetector(
    key: key,
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 15, bottom: 17),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 6))],
      ),
      child: Text(label, style: _baloo(24, 800, Colors.white)),
    ),
  );
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
  });
  final String up;
  final String down;
  final VoidCallback onTap;
  final String? label;

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
                  size: 31,
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
