import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// Ayah Builder — listen to an ayah, then drag its word cards into the
/// numbered slots in order. Ported 1:1 from the supplied "Ayah Builder"
/// mobile prototype: same night-mosque scene and ambient motion, how-to
/// card, listen-first screen, drag-and-drop puzzle and Masha'Allah reward,
/// with the same copy, colours and timings. The start screen is built from
/// the separately supplied start-screen artwork (see [_buildStart]).
///
/// The prototype was authored against a fixed 402x874 phone frame, so the
/// whole game is built inside that same virtual frame and scaled to fit (see
/// [build]); the backdrop runs full-bleed behind it.
///
/// One [AyahBuilderSession] per lesson, distributed across Stages 2-7 as the
/// prototype lists them. [sessions] is the full list, so the reward screen
/// knows whether a next session follows.
class AyahBuilderGame extends StatefulWidget {
  const AyahBuilderGame({
    super.key,
    required this.sessions,
    required this.initialIndex,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final List<AyahBuilderSession> sessions;
  final int initialIndex;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  final VoidCallback? onExit;

  @override
  State<AyahBuilderGame> createState() => _AyahBuilderGameState();
}

// ---------------------------------------------------------------------------
// Frame, assets, palette — all lifted from the prototype.
// ---------------------------------------------------------------------------

const double _kW = 402;
const double _kH = 874;
const String _kBg = 'assets/images/ayah_builder/bg_night_mosque.png';
const String _kA = 'assets/images/ayah_builder';
const String _kStartBg = '$_kA/start_bg.jpg';
const String _kMascotReward = 'assets/images/mascot/girl/cheer.png';

const _cream = Color(0xFFFFF8E7);
const _gold = Color(0xFFFFD35C);
const _sky = Color(0xFF9FD6E8);
const _teal = Color(0xFF17879E);
const _navyInk = Color(0xFF0F2147);
const _stepInk = Color(0xFF122A55);
const _amberEdge = Color(0xFFE9A73C);
const _green = Color(0xFF2BB673);
const _red = Color(0xFFFF6B6B);
const _redDeep = Color(0xFFC93B3B);
const _brownInk = Color(0xFF3A2306);
const _goldEdge = Color(0xFFB87B22);
const _goldShade = Color(0xFF96631A);

Color _cr(double a) => _cream.withValues(alpha: a);

const _panelGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xE6172A6E), Color(0xF00A1440)], // .9 / .94
);

// Easing, straight from the prototype's CSS.
const Curve _easeOut = Curves.easeOut;
const Curve _easeInOut = Curves.easeInOut;
const Curve _linear = Curves.linear;
const Curve _snapBack = Cubic(0.3, 1.4, 0.6, 1);

double _c01(double v) => v.clamp(0.0, 1.0);

/// Interpolates a CSS `@keyframes` track: [stops] are the percentage marks
/// (0..1) and [vals] the value at each, with [curve] applied within each
/// segment the way a CSS timing function is.
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

/// `animation: <name> <dur>s infinite` — repeating phase 0..1.
double _loop(double t, double dur, [double delay = 0]) {
  final x = (t - delay) % dur;
  return (x < 0 ? x + dur : x) / dur;
}

/// `animation: <name> <dur>s <delay>s both` — progress 0..1, held at ends.
double _once(double t, double dur, [double delay = 0]) =>
    _c01((t - delay) / dur);

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

TextStyle _nunito(
  double size,
  double weight,
  Color color, {
  double? height,
  double? ls,
}) => TextStyle(
  fontFamily: 'NunitoVar',
  fontSize: size,
  fontWeight: _fw(weight),
  fontVariations: [ui.FontVariation.weight(weight)],
  color: color,
  height: height,
  letterSpacing: ls,
);

TextStyle _arabic(double size, Color color, double height) => TextStyle(
  fontFamily: 'ScheherazadeNew',
  fontSize: size,
  color: color,
  height: height,
);

// The prototype's inline SVG icons, verbatim.
const _svgBack =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#FFF8E7" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5 8 12l7 7"/></svg>';
const _svgClose =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#FFF8E7" stroke-width="2.5" stroke-linecap="round"><path d="m6 6 12 12M18 6 6 18"/></svg>';
const _svgArrowDark =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#3A2306" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h13m-5-6 6 6-6 6"/></svg>';
const _svgSpeakerWide =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><path d="M11 5 6 9H3v6h3l5 4z" fill="#fff"/><path d="M15.5 9.2c1.3 1.4 1.3 4.2 0 5.6"/><path d="M18.3 6.5c2.6 2.8 2.6 8.2 0 11"/></svg>';
const _svgSpeaker =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><path d="M11 5 6 9H3v6h3l5 4z" fill="#fff"/><path d="M15.5 9.2c1.3 1.4 1.3 4.2 0 5.6"/></svg>';
const _svgSoundOn =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#FFF8E7" stroke-width="2" stroke-linecap="round"><path d="M11 5 6 9H3v6h3l5 4z" fill="#FFF8E7"/><path d="M15.5 9.2c1.3 1.4 1.3 4.2 0 5.6"/></svg>';
const _svgSoundOff =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#FFF8E7" stroke-width="2" stroke-linecap="round"><path d="M11 5 6 9H3v6h3l5 4z" fill="#FFF8E7"/><path d="m16 10 5 5m0-5-5 5"/></svg>';
const _svgPlaySmall =
    '<svg viewBox="0 0 12 14"><path d="M1.5 1 11 7l-9.5 6z" fill="#062038"/></svg>';
const _svgStar =
    '<svg viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.1 6.6.9-4.8 4.7 1.2 6.6L12 17.6l-5.9 3.2 1.2-6.6L2.5 9.5l6.6-.9z" fill="#FFD35C"/></svg>';
const _svgStarBig =
    '<svg viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.1 6.6.9-4.8 4.7 1.2 6.6L12 17.6l-5.9 3.2 1.2-6.6L2.5 9.5l6.6-.9z" fill="#FFD35C" stroke="#B87B22" stroke-width="1"/></svg>';
const _svgCheck =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"><path d="m5 13 4 4 10-10"/></svg>';
const _svgCross =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#C93B3B" stroke-width="3.5" stroke-linecap="round"><path d="m6 6 12 12M18 6 6 18"/></svg>';
const _svgReplay =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#FFF8E7" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/></svg>';

Widget _svg(String s, double w, [double? h]) =>
    SvgPicture.string(s, width: w, height: h ?? w);

enum _Screen { start, instructions, listen, puzzle, reward }

enum _Msg { none, strip, last, oops, idle }

class _AyahBuilderGameState extends State<AyahBuilderGame>
    with SingleTickerProviderStateMixin {
  // One monotonic clock drives every animation; each derives its phase from
  // the elapsed seconds.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  )..forward();

  double get _now => _clock.value * 3600.0;

  final List<Timer> _timers = [];
  final GlobalKey _frameKey = GlobalKey();
  final List<GlobalKey> _slotKeys = List.generate(8, (_) => GlobalKey());
  final List<GlobalKey> _cardKeys = List.generate(8, (_) => GlobalKey());

  late final int _sessionIdx = widget.initialIndex;
  _Screen _screen = _Screen.start;
  double _screenT0 = 0;

  List<bool> _placed = [];
  List<double> _placedT0 = [];
  List<int> _trayOrder = [];
  int? _tappedId;
  int? _wrongSlot;
  double _wrongT0 = 0;
  bool _oops = false;
  bool _ayahPlaying = false;
  int _litIndex = -1;
  int _stars = 0;
  bool _soundOn = true;
  bool _completed = false;

  _Msg _msg = _Msg.none;
  double _msgT0 = 0;

  int _correctDrops = 0;
  int _errors = 0;

  // Drag state — the prototype's pointer handlers.
  int? _dragId;
  int? _dragPointer;
  Offset _downPos = Offset.zero;
  DateTime _downAt = DateTime.now();
  bool _moved = false;
  Offset _dragDelta = Offset.zero;
  Rect _dragOrigin = Rect.zero;

  // The card snapping back after a miss (`transform .28s cubic-bezier`).
  int? _returnId;
  Offset _returnFrom = Offset.zero;
  Rect _returnOrigin = Rect.zero;
  double _returnT0 = 0;

  AyahBuilderSession get _session => widget.sessions[_sessionIdx];
  List<AyahBuilderWord> get _words => _session.words;
  int get _n => _words.length;

  @override
  void initState() {
    super.initState();
    _resetRound();
  }

  @override
  void dispose() {
    _clearTimers();
    _clock.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Timers & sound
  // -------------------------------------------------------------------------

  void _clearTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _later(int ms, VoidCallback fn) {
    _timers.add(
      Timer(Duration(milliseconds: ms), () {
        if (mounted) fn();
      }),
    );
  }

  /// The prototype's `sfx()` — it stands short synth tones in for the real
  /// word/ayah recordings. There is no audio engine in the app yet, so each
  /// cue is a system click plus a haptic tap, muted by the sound toggle.
  void _sfx(String kind) {
    if (!_soundOn) return;
    switch (kind) {
      case 'word':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
      case 'correct':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      case 'wrong':
        HapticFeedback.heavyImpact();
      case 'star':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
    }
  }

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  void _go(_Screen s) {
    _screen = s;
    _screenT0 = _now;
  }

  void _resetRound() {
    _placed = List.filled(_n, false);
    _placedT0 = List.filled(_n, 0);
    _trayOrder = _shuffleOrder(_n);
    _tappedId = null;
    _oops = false;
    _wrongSlot = null;
    _litIndex = -1;
    _ayahPlaying = false;
    _dragId = null;
    _returnId = null;
  }

  List<int> _shuffleOrder(int n) {
    final rnd = math.Random();
    final a = List<int>.generate(n, (i) => i);
    for (var pass = 0; pass < 6; pass++) {
      for (var i = n - 1; i > 0; i--) {
        final j = rnd.nextInt(i + 1);
        final t = a[i];
        a[i] = a[j];
        a[j] = t;
      }
      var shuffled = false;
      for (var i = 0; i < n; i++) {
        if (a[i] != i) shuffled = true;
      }
      if (n < 2 || shuffled) break;
    }
    return a;
  }

  void _onStart() => setState(() => _go(_Screen.instructions));
  void _onBack() => setState(() => _go(_Screen.start));

  void _onBeginListen() {
    setState(() => _go(_Screen.listen));
    _later(500, () {
      _playAyah(() {
        if (_screen == _Screen.listen) {
          setState(() {
            _trayOrder = _shuffleOrder(_n);
            _go(_Screen.puzzle);
          });
        }
      });
    });
  }

  void _onSkipToPuzzle() {
    _clearTimers();
    setState(() {
      _trayOrder = _shuffleOrder(_n);
      _ayahPlaying = false;
      _litIndex = -1;
      _go(_Screen.puzzle);
    });
  }

  void _playAyah([VoidCallback? done]) {
    if (_ayahPlaying) return;
    setState(() {
      _ayahPlaying = true;
      _litIndex = 0;
    });
    for (var i = 0; i < _n; i++) {
      _later(i * 620, () {
        setState(() => _litIndex = i);
        _sfx('word');
      });
    }
    _later(_n * 620 + 320, () {
      setState(() {
        _ayahPlaying = false;
        _litIndex = -1;
      });
      done?.call();
    });
  }

  void _tapWord(int id) {
    _sfx('word');
    setState(() => _tappedId = id);
    _later(950, () {
      if (_tappedId == id) setState(() => _tappedId = null);
    });
  }

  void _dropCorrect(int index) {
    _sfx('correct');
    _correctDrops += 1;
    setState(() {
      _placed[index] = true;
      _placedT0[index] = _now;
      _tappedId = index;
      _oops = false;
      _wrongSlot = null;
    });
    _later(800, () {
      if (_tappedId == index) setState(() => _tappedId = null);
    });
    if (_placed.every((p) => p)) _later(620, _finish);
  }

  void _finish() {
    setState(() {
      _ayahPlaying = true;
      _litIndex = 0;
    });
    for (var i = 0; i < _n; i++) {
      _later(i * 650, () {
        setState(() => _litIndex = i);
        _sfx('word');
      });
    }
    _later(_n * 650 + 420, () {
      _sfx('star');
      setState(() {
        _ayahPlaying = false;
        _litIndex = -1;
        _stars += 1;
        _go(_Screen.reward);
      });
    });
  }

  void _onReplay() {
    _clearTimers();
    setState(() {
      _resetRound();
      _go(_Screen.puzzle);
    });
  }

  void _onNextSession() {
    if (_completed) return;
    _completed = true;
    _clearTimers();
    final total = _correctDrops + _errors;
    widget.onComplete(
      widget.xp,
      total == 0 ? 100.0 : _correctDrops / total * 100.0,
      _errors,
    );
  }

  // -------------------------------------------------------------------------
  // Drag — the prototype's `onCardDown` pointer handlers.
  // -------------------------------------------------------------------------

  RenderBox? get _frameBox =>
      _frameKey.currentContext?.findRenderObject() as RenderBox?;

  Offset _toFrame(Offset global) => _frameBox?.globalToLocal(global) ?? global;

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final frame = _frameBox;
    if (box == null || frame == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: frame) & box.size;
  }

  void _onCardDown(int id, PointerDownEvent e) {
    if (_dragId != null) return;
    _dragId = id;
    _dragPointer = e.pointer;
    _downPos = _toFrame(e.position);
    _downAt = DateTime.now();
    _moved = false;
    _dragDelta = Offset.zero;
    _dragOrigin = _rectOf(_cardKeys[id]) ?? Rect.zero;
    if (_returnId == id) _returnId = null;
  }

  void _onCardMove(PointerMoveEvent e) {
    if (e.pointer != _dragPointer || _dragId == null) return;
    final d = _toFrame(e.position) - _downPos;
    if (!_moved && d.dx.abs() + d.dy.abs() > 7) _moved = true;
    if (_moved) setState(() => _dragDelta = d);
  }

  void _onCardUp(PointerEvent e) {
    if (e.pointer != _dragPointer || _dragId == null) return;
    final id = _dragId!;
    final moved = _moved;
    final delta = _dragDelta;
    _dragId = null;
    _dragPointer = null;
    _moved = false;

    if (!moved &&
        DateTime.now().difference(_downAt) <
            const Duration(milliseconds: 600)) {
      _tapWord(id);
      return;
    }

    final p = _toFrame(e.position);
    var hit = -1;
    for (var i = 0; i < _n; i++) {
      final r = _rectOf(_slotKeys[i]);
      if (r == null) continue;
      if (p.dx > r.left - 26 &&
          p.dx < r.right + 26 &&
          p.dy > r.top - 34 &&
          p.dy < r.bottom + 34) {
        hit = i;
        break;
      }
    }

    if (hit >= 0 && !_placed[hit] && hit == id) {
      _dropCorrect(hit);
      return;
    }

    setState(() {
      _returnId = id;
      _returnFrom = delta;
      _returnOrigin = _dragOrigin;
      _returnT0 = _now;
      _dragDelta = Offset.zero;
    });
    _later(300, () {
      if (_returnId == id) setState(() => _returnId = null);
    });
    if (hit >= 0) {
      _sfx('wrong');
      _errors += 1;
      setState(() {
        _oops = true;
        _wrongSlot = hit;
        _wrongT0 = _now;
      });
      _later(1300, () {
        setState(() {
          _oops = false;
          _wrongSlot = null;
        });
      });
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _now;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF070C24)),
            // The start screen brings its own painted courtyard scene.
            if (_screen == _Screen.start)
              Image.asset(_kStartBg, fit: BoxFit.cover)
            else ...[
              Image.asset(
                _kBg,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .38, .62, 1],
                    colors: [
                      Color(0x9E060C2C), // .62
                      Color(0x2E060C2C), // .18
                      Color(0x4D060C2C), // .30
                      Color(0xCC060C2C), // .80
                    ],
                  ),
                ),
              ),
            ],
            // The start screen's overlays are pinned to its painted scene,
            // so that frame covers the screen (cropping a sliver of edge)
            // instead of letterboxing inside a second copy of the backdrop.
            Positioned.fill(
              child: FittedBox(
                fit:
                    _screen == _Screen.start &&
                        MediaQuery.sizeOf(context).aspectRatio < _kW / _kH
                    ? BoxFit.cover
                    : BoxFit.contain,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  key: _frameKey,
                  width: _kW,
                  height: _kH,
                  child: DefaultTextStyle(
                    style: _baloo(14, 400, _cream),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (_screen != _Screen.start)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(painter: _AmbientPainter(t)),
                            ),
                          ),
                        Positioned.fill(child: _buildScreen(t)),
                        ?_buildFloatingCard(t),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScreen(double t) => switch (_screen) {
    _Screen.start => _buildStart(t),
    _Screen.instructions => _buildInstructions(t),
    _Screen.listen => _buildListen(t),
    _Screen.puzzle => _buildPuzzle(t),
    _Screen.reward => _buildReward(t),
  };

  /// `ab-rise` — slide up 14px and fade in.
  Widget _rise(double p, Widget child) {
    final u = _easeOut.transform(p);
    return Opacity(
      opacity: u,
      child: Transform.translate(offset: Offset(0, 14 * (1 - u)), child: child),
    );
  }

  /// `ab-pop` — scale .4 -> 1.12 -> 1 while fading in.
  Widget _pop(double p, Widget child) {
    final s = _kf(p, const [0, .6, 1], const [.4, 1.12, 1], _easeOut);
    final o = _kf(p, const [0, .6, 1], const [0, 1, 1], _easeOut);
    return Opacity(
      opacity: o,
      child: Transform.scale(scale: s, child: child),
    );
  }

  /// `ab-shake` — the wrong-slot wobble.
  Widget _shake(double p, Widget child) {
    const stops = [0.0, .2, .4, .6, .8, 1.0];
    final x = _kf(p, stops, const [0, -7, 7, -5, 5, 0], _easeInOut);
    final r = _kf(p, stops, const [0, -2, 2, -1, 1, 0], _easeInOut);
    return Transform.translate(
      offset: Offset(x, 0),
      child: Transform.rotate(angle: r * math.pi / 180, child: child),
    );
  }

  /// `ab-pulse` — a ring of [color] swelling out 10px and fading.
  List<BoxShadow> _pulse(
    double t,
    double dur,
    Color color, {
    bool withDrop = true,
  }) {
    final p = _loop(t, dur);
    final spread = _kf(p, const [0, .5, 1], const [0, 10, 0], _easeOut);
    final a = _kf(p, const [0, .5, 1], const [.55, 0, .55], _easeOut);
    return [
      BoxShadow(
        color: color.withValues(alpha: a),
        spreadRadius: spread,
      ),
      if (withDrop)
        const BoxShadow(
          color: Color(0x59000000),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
    ];
  }

  /// The 34px/42px glowing speaker disc used on the listen card and strip.
  Widget _speakerDisc(
    double t,
    double size,
    double icon,
    double dur,
    String svg,
  ) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EC9FF), Color(0xFF2B7FD4)],
        ),
        boxShadow: _pulse(t, dur, const Color(0xFF6EC9FF)),
      ),
      child: _svg(svg, icon),
    );
  }

  /// `ab-wave` — the equaliser bars beside the speaker.
  Widget _waveBars(
    double t,
    double barW,
    double h,
    double dur,
    double step,
    List<Color> colors,
    double gap,
  ) {
    return SizedBox(
      height: h,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < colors.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Transform.scale(
              scaleX: 1,
              scaleY: _kf(
                _loop(t, dur, i * step),
                const [0, .5, 1],
                const [.25, 1, .25],
                _easeInOut,
              ),
              child: Container(
                width: barW,
                height: h,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ghostButton({
    required VoidCallback onTap,
    required double height,
    double? width,
    required double radius,
    double borderAlpha = .32,
    double borderWidth = 1.5,
    required Widget child,
  }) {
    return _Press(
      onTap: onTap,
      builder: (pressed) => Transform.translate(
        offset: Offset(0, pressed ? 2 : 0),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: pressed ? .2 : .12),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _cr(borderAlpha), width: borderWidth),
          ),
          child: child,
        ),
      ),
    );
  }

  /// The gold "I'm ready" / "Next Session" button.
  Widget _goldButton(String label, VoidCallback onTap) {
    return _Press(
      onTap: onTap,
      builder: (pressed) => Transform.translate(
        offset: Offset(0, pressed ? 3 : 0),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFD962), _amberEdge],
            ),
            border: Border.all(color: _goldEdge, width: 2),
            boxShadow: [
              BoxShadow(color: _goldShade, offset: Offset(0, pressed ? 3 : 6)),
              if (!pressed)
                const BoxShadow(
                  color: Color(0x61000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: _baloo(20, 800, _brownInk)),
              const SizedBox(width: 9),
              _svg(_svgArrowDark, 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(
    Widget child, {
    required BorderRadius radius,
    EdgeInsets padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _cr(.95),
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _eyebrow(String text, {double size = 13, double ls = 2.2}) => Text(
    text.toUpperCase(),
    textAlign: TextAlign.center,
    style: _baloo(size, 600, _sky, ls: ls),
  );

  // ---- Start ---------------------------------------------------------------

  /// The title screen, built from the supplied start-screen artwork: the
  /// painted courtyard scene (the two children included), the Ayah Builder
  /// crest, the hanging "Session N" ribbon, the session's name plate, the Play
  /// button (which opens the how-to card, as in the prototype), and one empty
  /// word tile per word of this session's ayah on the floor below the Qur'an
  /// stand.
  ///
  /// Every piece sits where the reference image puts it, in the 402x874
  /// frame the scene art is drawn to.
  ///
  /// Each time the screen opens the pieces arrive in a staged entrance: the
  /// scene settles out of a slight zoom, the crest drops in, the ribbon falls
  /// and swings on its ropes, the name plate pops in, Play bounces up, and
  /// the word tiles land one by one.
  Widget _buildStart(double t) {
    final s = _session;
    final st = t - _screenT0;
    // Play only starts its idle bob once its entrance has finished.
    final bob =
        _kf(_loop(t, 2.8), const [0, .5, 1], const [0, -4, 0], _easeInOut) *
        _c01((st - 1.6) / .4);
    // The ribbon hangs from its ropes, so it swings about its top edge as it
    // lands — a damped sway that dies out over ~1s.
    final rp = _once(st, 1.1, .6);
    final ribbonDrop = -46 * (1 - Curves.easeOutCubic.transform(_c01(rp / .4)));
    final ribbonSwing = rp <= 0
        ? 0.0
        : 7 * math.exp(-5 * rp) * math.cos(rp * 11);
    return Stack(
      children: [
        Positioned.fill(
          child: _enter(
            _once(st, 1.0),
            Image.asset(_kStartBg, fit: BoxFit.fill),
            fromScale: 1.08,
            curve: Curves.easeOutCubic,
            fade: .5,
          ),
        ),
        Positioned(
          left: 60.5,
          top: 130,
          width: 280,
          height: 209.8,
          child: _enter(
            _once(st, .75, .2),
            Image.asset('$_kA/start_logo.png', fit: BoxFit.fill),
            dy: -24,
            fromScale: .7,
          ),
        ),
        Positioned(
          left: 94.5,
          top: 314,
          width: 214,
          height: 71.4,
          child: Opacity(
            opacity: Curves.easeOut.transform(_c01(rp / .25)),
            child: Transform.translate(
              offset: Offset(0, ribbonDrop),
              child: Transform.rotate(
                angle: ribbonSwing * math.pi / 180,
                alignment: Alignment.topCenter,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        '$_kA/start_ribbon.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, .02),
                      child: Text(
                        s.label,
                        style: _baloo(19, 800, const Color(0xFF1B2F7E)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 97,
          top: 360,
          width: 208,
          height: 69.4,
          child: _enter(
            _once(st, .5, .85),
            fromScale: .6,
            Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    '$_kA/start_name_plate.png',
                    fit: BoxFit.fill,
                  ),
                ),
                // The plate's cream panel spans 21%-79% of the art's width.
                Positioned(
                  left: 46,
                  right: 46,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        s.sessionName,
                        style: _baloo(19, 800, const Color(0xFF1E3AA8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 106,
          top: 556 + bob,
          width: 190,
          height: 63.3,
          child: _enter(
            _once(st, .6, 1.0),
            fromScale: .4,
            _Press(
              key: const ValueKey('ab-play'),
              onTap: _onStart,
              builder: (pressed) => Image.asset(
                '$_kA/${pressed ? 'start_play_down' : 'start_play_up'}.png',
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
        Positioned(left: 75.5, right: 76.5, top: 796, child: _startTiles(st)),
        if (widget.onExit != null)
          Positioned(
            left: 20,
            top: 48,
            child: _enter(
              _once(st, .4, 1.7),
              _ghostButton(
                onTap: widget.onExit!,
                width: 40,
                height: 40,
                radius: 20,
                child: _svg(_svgClose, 18),
              ),
              curve: Curves.easeOut,
            ),
          ),
      ],
    );
  }

  /// One start-screen piece's entrance at progress [p] (0..1): it fades in
  /// over the first [fade] of the way while sliding up from [dy] and growing
  /// from [fromScale], shaped by [curve].
  Widget _enter(
    double p,
    Widget child, {
    double dy = 0,
    double fromScale = 1,
    Curve curve = Curves.easeOutBack,
    double fade = .6,
  }) {
    final u = curve.transform(p);
    return Opacity(
      opacity: Curves.easeOut.transform(_c01(p / fade)),
      child: Transform.translate(
        offset: Offset(0, dy * (1 - u)),
        child: Transform.scale(
          scale: fromScale + (1 - fromScale) * u,
          child: child,
        ),
      ),
    );
  }

  /// One empty word tile per word of the ayah — the board the learner is
  /// about to fill.
  Widget _startTiles(double st) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 5.7;
        final w = math.min(58.0, (c.maxWidth - gap * (_n - 1)) / _n);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _n; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _enter(
                _once(st, .4, 1.55 + i * .08),
                dy: 18,
                fromScale: .85,
                Container(
                  width: w,
                  height: 52,
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFBEFD6), Color(0xFFEFDDB8)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD2B27A),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x5978551E), offset: Offset(0, 3)),
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const CustomPaint(
                    painter: _DashedRRect(
                      radius: 7,
                      color: Color(0xFFCDB283),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ---- Instructions --------------------------------------------------------

  Widget _buildInstructions(double t) {
    Widget step(int n, String text) => Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
          child: Text('$n', style: _baloo(18, 800, Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: _nunito(15, 700, _stepInk, height: 1.3)),
        ),
      ],
    );
    const divider = SizedBox(
      height: 1,
      child: ColoredBox(color: Color(0x1F122A55)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _eyebrow('How to play', size: 14, ls: 2),
          const SizedBox(height: 16),
          _rise(
            _once(t - _screenT0, .45),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF7FFF8E7), Color(0xF2FFF0CD)],
                ),
                border: Border.all(color: _amberEdge, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x6B000000),
                    blurRadius: 44,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                children: [
                  step(1, 'Listen to the full ayah first.'),
                  const SizedBox(height: 14),
                  divider,
                  const SizedBox(height: 14),
                  step(2, 'Tap a card to hear its word.'),
                  const SizedBox(height: 14),
                  divider,
                  const SizedBox(height: 14),
                  step(3, 'Drag the words into the correct order.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x336EC9FF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                ),
                border: Border.all(
                  color: _sky.withValues(alpha: .7),
                  width: 1.5,
                ),
              ),
              child: Text(
                "Let's build ${_session.short} together!",
                textAlign: TextAlign.center,
                style: _baloo(16, 700, _cream),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _ghostButton(
                onTap: _onBack,
                width: 64,
                height: 58,
                radius: 20,
                child: _svg(_svgBack, 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: _goldButton("I'm ready", _onBeginListen)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Listen --------------------------------------------------------------

  Widget _buildListen(double t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 96, 22, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _eyebrow('Listen first'),
          const SizedBox(height: 14),
          _rise(
            _once(t - _screenT0, .5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: _panelGradient,
                border: Border.all(color: const Color(0x806EC9FF), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x386EC9FF), blurRadius: 34),
                  BoxShadow(
                    color: Color(0x73000000),
                    blurRadius: 44,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _n; i++)
                        _listenWord(_words[i].text, _litIndex == i),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _speakerDisc(t, 42, 20, 1.6, _svgSpeakerWide),
                      const SizedBox(width: 12),
                      _waveBars(t, 4, 34, .9, .08, const [
                        Color(0xFF6EC9FF),
                        Color(0xFF8FD8FF),
                        Color(0xFF6EC9FF),
                        Color(0xFFB9E8FF),
                        Color(0xFF6EC9FF),
                        Color(0xFF8FD8FF),
                        Color(0xFF6EC9FF),
                        Color(0xFFB9E8FF),
                      ], 4),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _session.englishTranslation,
                    textAlign: TextAlign.center,
                    style: _nunito(14, 400, _cr(.85), height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'The full ayah plays automatically\nwhen the level opens.',
            textAlign: TextAlign.center,
            style: _nunito(13, 400, _cr(.7)),
          ),
          const Spacer(),
          _ghostButton(
            onTap: _onSkipToPuzzle,
            height: 56,
            radius: 20,
            child: Text('Start building', style: _baloo(18, 700, _cream)),
          ),
        ],
      ),
    );
  }

  Widget _listenWord(String text, bool lit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            text,
            textDirection: TextDirection.rtl,
            style: _arabic(34, _cream, 1.45),
          ),
          if (lit)
            Positioned(
              left: -4,
              right: -4,
              top: 2,
              bottom: 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: .45),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Puzzle --------------------------------------------------------------

  Widget _buildPuzzle(double t) {
    final placedCount = _placed.where((p) => p).length;
    final msg = _ayahPlaying
        ? _Msg.strip
        : _oops
        ? _Msg.oops
        : placedCount == _n - 1
        ? _Msg.last
        : placedCount < _n - 1
        ? _Msg.idle
        : _Msg.none;
    if (msg != _msg) {
      _msg = msg;
      _msgT0 = t;
    }
    final mt = t - _msgT0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 58, 18, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _puzzleTopBar(),
          const SizedBox(height: 14),
          Text(
            _session.sessionName,
            textAlign: TextAlign.center,
            style: _baloo(19, 800, _gold, ls: .3),
          ),
          const SizedBox(height: 1),
          Text(
            'Fill slot 1 on the left, then move right',
            textAlign: TextAlign.center,
            style: _nunito(12, 400, _cr(.7)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _slotsRow(t),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 78),
                    child: Center(child: _message(t, msg, mt)),
                  ),
                ],
              ),
            ),
          ),
          _trayRow(t),
        ],
      ),
    );
  }

  Widget _puzzleTopBar() {
    return Row(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: const Color(0x990A1440),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _gold.withValues(alpha: .5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _svg(_svgStar, 15),
              const SizedBox(width: 5),
              Text('$_stars', style: _baloo(15, 800, _gold)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Press(
            onTap: _playAyah,
            builder: (pressed) => Transform.translate(
              offset: Offset(0, pressed ? 2 : 0),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xF26EC9FF), Color(0xF22B7FD4)],
                  ),
                  border: Border.all(color: _cr(.45), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _svg(_svgPlaySmall, 11, 13),
                    const SizedBox(width: 7),
                    Text(
                      'Play Full Ayah',
                      style: _baloo(14, 800, const Color(0xFF062038), ls: .2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _soundOn = !_soundOn),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x990A1440),
              shape: BoxShape.circle,
              border: Border.all(color: _cr(.3)),
            ),
            child: _svg(_soundOn ? _svgSoundOn : _svgSoundOff, 17),
          ),
        ),
      ],
    );
  }

  Widget _slotsRow(double t) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = math.min(84.0, (c.maxWidth - 6 * (_n - 1)) / _n);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _n; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              SizedBox(
                key: _slotKeys[i],
                width: w,
                height: 96,
                child: _slot(t, i),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _slot(double t, int i) {
    final filled = _placed[i];
    final word = _words[i];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!filled)
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedRRect(
                radius: 16,
                color: _cr(.42),
                width: 2.5,
                fill: const Color(0x6B0A1440),
              ),
              child: Center(
                child: Text('${i + 1}', style: _baloo(30, 800, _cr(.34))),
              ),
            ),
          ),
        if (filled)
          Positioned.fill(
            child: _pop(
              _once(t - _placedT0[i], .34),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFFDF6), Color(0xFFFFF3D8)],
                        ),
                        border: Border.all(color: _green, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x733ED598), blurRadius: 16),
                          BoxShadow(
                            color: Color(0x4D000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _wordFace(
                        word,
                        21,
                        1.4,
                        11,
                        const Color(0xFF177A50),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -7,
                    right: -7,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFFDF6),
                          width: 2,
                        ),
                      ),
                      child: _svg(_svgCheck, 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_litIndex == i && filled)
          Positioned(
            left: -5,
            right: -5,
            top: -5,
            bottom: -5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: .7),
                      blurRadius: 26,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_wrongSlot == i)
          Positioned(
            left: -4,
            right: -4,
            top: -4,
            bottom: -4,
            child: IgnorePointer(
              child: _shake(
                _once(t - _wrongT0, .4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _red, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: .6),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The Arabic word over its transliteration — shared by slots and cards.
  Widget _wordFace(
    AyahBuilderWord w,
    double arSize,
    double arHeight,
    double trSize,
    Color trColor,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              w.text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: _arabic(arSize, _navyInk, arHeight),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          w.transliteration,
          textAlign: TextAlign.center,
          style: _nunito(trSize, 700, trColor, height: 1.1),
        ),
      ],
    );
  }

  Widget _message(double t, _Msg msg, double mt) {
    switch (msg) {
      case _Msg.strip:
        return _rise(_once(mt, .3), _ayahStrip(t));
      case _Msg.last:
        return _rise(
          _once(mt, .3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _cr(.96),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 26,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'One more word!\n'),
                  TextSpan(
                    text: 'Drag the final word to complete the ayah.',
                    style: _nunito(13, 600, _stepInk, height: 1.35),
                  ),
                ],
              ),
              style: _nunito(13, 800, _stepInk, height: 1.35),
            ),
          ),
        );
      case _Msg.oops:
        return _shake(
          _once(mt, .45),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _redDeep, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 26,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _svg(_svgCross, 13),
                ),
                const SizedBox(width: 10),
                Text('Oops! Try again!', style: _baloo(17, 800, Colors.white)),
              ],
            ),
          ),
        );
      case _Msg.idle:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0x9E070E2C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cr(.16)),
          ),
          child: Text(
            'Tap a card to hear the word.\nDrag it up into the right slot.',
            textAlign: TextAlign.center,
            style: _nunito(12.5, 400, _cr(.9), height: 1.5),
          ),
        );
      case _Msg.none:
        return const SizedBox.shrink();
    }
  }

  Widget _ayahStrip(double t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE0172A6E), Color(0xEB0A1440)],
        ),
        border: Border.all(color: const Color(0x736EC9FF), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x336EC9FF), blurRadius: 24)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _speakerDisc(t, 34, 16, 1.5, _svgSpeaker),
              const SizedBox(width: 10),
              _waveBars(t, 3, 26, .8, .07, const [
                Color(0xFF6EC9FF),
                Color(0xFF8FD8FF),
                Color(0xFF6EC9FF),
                Color(0xFFB9E8FF),
                Color(0xFF6EC9FF),
                Color(0xFF8FD8FF),
              ], 3),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _words.map((w) => w.text).join(' '),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: _arabic(22, _cream, 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _session.englishTranslation,
            textAlign: TextAlign.center,
            style: _nunito(12, 400, _cr(.8), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _trayRow(double t) {
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k < _trayOrder.length; k++) ...[
            if (k > 0) const SizedBox(width: 7),
            Expanded(child: _trayCard(t, _trayOrder[k])),
          ],
        ],
      ),
    );
  }

  Widget _trayCard(double t, int id) {
    if (_placed[id]) {
      return CustomPaint(
        painter: _DashedRRect(radius: 14, color: _cr(.18), width: 2),
      );
    }
    final hidden = (_dragId == id && _moved) || _returnId == id;
    return Listener(
      key: _cardKeys[id],
      onPointerDown: (e) => _onCardDown(id, e),
      onPointerMove: _onCardMove,
      onPointerUp: _onCardUp,
      onPointerCancel: _onCardUp,
      child: Opacity(opacity: hidden ? 0 : 1, child: _cardFace(t, id)),
    );
  }

  Widget _cardFace(double t, int id) {
    final tapped = _tappedId == id;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFDF6), Color(0xFFFFEFCF)],
              ),
              border: Border.all(color: _amberEdge, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x8096631A), offset: Offset(0, 7)),
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 26,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: _wordFace(_words[id], 24, 1.35, 10, const Color(0xFF0F5F72)),
          ),
        ),
        if (tapped) ...[
          Positioned(
            left: -3,
            right: -3,
            top: -3,
            bottom: -3,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFF6EC9FF), width: 3),
                  boxShadow: _pulse(t, 1.2, const Color(0xFF6EC9FF)),
                ),
              ),
            ),
          ),
          Positioned(
            top: -10,
            left: -10,
            child: IgnorePointer(
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6EC9FF), Color(0xFF2B7FD4)],
                  ),
                  border: Border.all(color: const Color(0xFFFFFDF6), width: 2),
                ),
                child: _svg(_svgSpeaker, 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The card being dragged (or snapping back), drawn above everything —
  /// the prototype's `z-index: 80` while it follows the finger.
  Widget? _buildFloatingCard(double t) {
    int id;
    Rect origin;
    Offset offset;
    double k; // 1 = fully lifted, 0 = resting
    if (_dragId != null && _moved) {
      id = _dragId!;
      origin = _dragOrigin;
      offset = _dragDelta;
      k = 1;
    } else if (_returnId != null) {
      id = _returnId!;
      origin = _returnOrigin;
      final u = _snapBack.transform(_once(t - _returnT0, .28));
      offset = _returnFrom * (1 - u);
      k = 1 - u;
    } else {
      return null;
    }
    if (_screen != _Screen.puzzle || origin == Rect.zero) return null;
    final dx = _returnId == id ? _returnFrom.dx : offset.dx;
    final rot = (dx * 0.05).clamp(-8.0, 8.0) * k;
    return Positioned.fromRect(
      rect: origin.shift(offset),
      child: IgnorePointer(
        child: Transform.rotate(
          angle: rot * math.pi / 180,
          child: Transform.scale(scale: 1 + .08 * k, child: _cardFace(t, id)),
        ),
      ),
    );
  }

  // ---- Reward --------------------------------------------------------------

  Widget _buildReward(double t) {
    final st = t - _screenT0;
    Widget star(double size, double delay, double glow) {
      final p = _once(st, .5, delay);
      final s = _kf(p, const [0, .65, 1], const [0, 1.25, 1], _easeOut);
      final r = _kf(p, const [0, .65, 1], const [-40, 8, 0], _easeOut);
      return Transform.rotate(
        angle: r * math.pi / 180,
        child: Transform.scale(
          scale: s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: glow, sigmaY: glow),
                child: Opacity(opacity: .85, child: _svg(_svgStar, size)),
              ),
              _svg(_svgStarBig, size),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 42),
      child: Column(
        children: [
          _pop(
            _once(st, .5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE79A), _amberEdge],
                ),
                border: Border.all(color: _goldEdge, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: _goldShade, offset: Offset(0, 8)),
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Text(
                "Masha'Allah!",
                style: _baloo(30, 800, _brownInk, ls: .4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              star(46, .15, 6),
              const SizedBox(width: 12),
              star(58, .3, 8),
              const SizedBox(width: 12),
              star(46, .45, 6),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You earned 1 star · $_stars total',
            style: _nunito(13, 700, _gold),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: _panelGradient,
              border: Border.all(color: _gold.withValues(alpha: .5), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 44,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _words.map((w) => w.text).join(' '),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: _arabic(30, _cream, 1.7),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final w in _words)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x382BB673),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x993ED598)),
                        ),
                        child: Text(
                          w.transliteration,
                          style: _nunito(11, 700, const Color(0xFF8FEFC2)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _session.englishTranslation,
                  textAlign: TextAlign.center,
                  style: _nunito(13.5, 400, _cr(.86), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _bubble(
                    Text(
                      _session.cheer,
                      style: _nunito(
                        12.5,
                        700,
                        const Color(0xFF112233),
                        height: 1.35,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    radius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 104,
                height: 124,
                child: Image.asset(_kMascotReward, fit: BoxFit.contain),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _ghostButton(
                onTap: _onReplay,
                width: 68,
                height: 58,
                radius: 20,
                child: _svg(_svgReplay, 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _goldButton(
                  _sessionIdx + 1 < widget.sessions.length
                      ? 'Next Session'
                      : 'Finish',
                  _onNextSession,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tappable surface that reports its pressed state — the prototype's
/// `style-active` rules.
class _Press extends StatefulWidget {
  const _Press({super.key, required this.onTap, required this.builder});

  final VoidCallback onTap;
  final Widget Function(bool pressed) builder;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: widget.builder(_down),
    );
  }
}

/// CSS `border: Npx dashed` on a rounded box, with an optional fill.
class _DashedRRect extends CustomPainter {
  const _DashedRRect({
    required this.radius,
    required this.color,
    required this.width,
    this.fill,
  });

  final double radius;
  final Color color;
  final double width;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      Radius.circular(radius - width / 2),
    );
    if (fill != null) canvas.drawRRect(rrect, Paint()..color = fill!);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final dash = width * 2.6;
    final gap = width * 2;
    for (final m in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) =>
      old.color != color || old.width != width || old.fill != fill;
}

/// The night scene's ambient layers, in the prototype's paint order: drifting
/// clouds, mist, water shimmer, lantern flicker, fireflies, shooting stars
/// and twinkling stars. [t] is the game clock in seconds.
class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.t);

  final double t;

  void _ellipseGlow(
    Canvas canvas,
    Rect box,
    Alignment at,
    double rFrac,
    Color color,
    double stop, {
    double opacity = 1,
  }) {
    final c = at.withinRect(box);
    final rx = box.width * rFrac;
    final ry = box.height * rFrac;
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, ry / rx, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    final col = color.withValues(alpha: color.a * opacity);
    canvas.drawRect(
      box,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          rx,
          [col, col.withValues(alpha: 0)],
          [0, stop],
          TileMode.clamp,
          m.storage,
        ),
    );
  }

  void _dot(
    Canvas canvas,
    Offset c,
    double r,
    Color core,
    Color glow,
    double blur,
    double spread,
    double opacity,
  ) {
    if (opacity <= 0) return;
    canvas.drawCircle(
      c,
      r + spread,
      Paint()
        ..color = glow.withValues(alpha: glow.a * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()..color = core.withValues(alpha: core.a * opacity),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Clouds — `ab-drift`, clipped to their 120px band.
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 118, _kW, 120));
    for (final c in const [
      (10.0, 190.0, 58.0, 58.0, 0.0, Color(0x57C4D8FF)),
      (52.0, 250.0, 70.0, 84.0, 30.0, Color(0x42A8C4FF)),
    ]) {
      final p = _loop(t, c.$4, -c.$5);
      final x = c.$2 * (-.12 + 1.24 * p);
      _ellipseGlow(
        canvas,
        Rect.fromLTWH(x, 118 + c.$1, c.$2, c.$3),
        const Alignment(0, .1),
        .6,
        c.$6,
        .72,
      );
    }
    canvas.restore();

    // Mist — `ab-mist`.
    {
      final p = _loop(t, 22);
      final o = _kf(p, const [0, .5, 1], const [.18, .38, .18], _easeInOut);
      final tx = _kf(p, const [0, .5, 1], const [-.04, .04, -.04], _easeInOut);
      final s = _kf(p, const [0, .5, 1], const [1.05, 1.12, 1.05], _easeInOut);
      canvas.save();
      canvas.translate(_kW / 2 + tx * _kW, 214 + 75);
      canvas.scale(s);
      _ellipseGlow(
        canvas,
        const Rect.fromLTWH(-_kW / 2, -75, _kW, 150),
        const Alignment(-.2, 0),
        .7,
        const Color(0x33B6CEFF),
        .7,
        opacity: o,
      );
      canvas.restore();
    }

    // Water shimmer — `ab-shimmer`, repeating fading lines.
    for (final w in const [
      (404.0, 120.0, 8.0, 3.0, Color(0x38FFE7A8), 6.5, 0.0),
      (452.0, 90.0, 11.0, 4.0, Color(0x2E96CDFF), 9.0, 3.0),
    ]) {
      final p = _loop(t, w.$6, -w.$7);
      final o = _kf(p, const [0, .5, 1], const [.12, .3, .12], _easeInOut);
      final sy = _kf(p, const [0, .5, 1], const [1, 1.25, 1], _easeInOut);
      final cy = w.$1 + w.$2 / 2;
      for (var y = 0.0; y < w.$2; y += w.$3) {
        final top = cy + (w.$1 + y - cy) * sy;
        final h = w.$4 * sy;
        final col = w.$5.withValues(alpha: w.$5.a * o);
        canvas.drawRect(
          Rect.fromLTWH(0, top, _kW, h),
          Paint()
            ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, top + h), [
              col,
              col.withValues(alpha: 0),
            ]),
        );
      }
    }

    // Lantern flicker — `ab-flicker`.
    for (final f in const [
      (44.0, 96.0, 26.0, Color(0xBFFFCE6E), 4.6, 0.0),
      (66.0, 150.0, 22.0, Color(0xB3FFC460), 5.8, 1.6),
      (330.0, 104.0, 26.0, Color(0xB8FFCE6E), 5.2, 2.9),
      (26.0, 566.0, 30.0, Color(0x99FFC460), 6.4, .8),
      (348.0, 574.0, 30.0, Color(0x99FFC460), 5.5, 3.7),
    ]) {
      final o = _kf(
        _loop(t, f.$5, -f.$6),
        const [0, .25, .42, .68, .84, 1],
        const [.55, .95, .62, 1, .7, .55],
        _easeInOut,
      );
      final r = f.$3 / 2;
      final c = Offset(f.$1 + r, f.$2 + r);
      final col = f.$4.withValues(alpha: f.$4.a * o);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r,
            [col, col.withValues(alpha: 0)],
            [0, .7],
          ),
      );
    }

    // Fireflies — `ab-firefly`.
    for (final f in const [
      (62.0, 640.0, 4.0, 8.0, Color(0x99FFDC82), 11.0, 0.0, Color(0xFFFFE9A8)),
      (214.0, 672.0, 3.0, 7.0, Color(0x80FFDC82), 13.0, 4.0, Color(0xFFFFE9A8)),
      (318.0, 620.0, 4.0, 8.0, Color(0x8CFFDC82), 15.0, 8.0, Color(0xFFFFE9A8)),
      (132.0, 700.0, 3.0, 7.0, Color(0x73FFDC82), 12.0, 6.5, Color(0xFFFFF3C4)),
    ]) {
      final p = _loop(t, f.$6, -f.$7);
      const tStops = [0.0, .5, 1.0];
      final x = _kf(p, tStops, const [0, 26, -8], _easeInOut);
      final y = _kf(p, tStops, const [0, -34, -72], _easeInOut);
      final o = _kf(
        p,
        const [0, .12, .5, .88, 1],
        const [0, .9, .55, .8, 0],
        _easeInOut,
      );
      final r = f.$3 / 2;
      _dot(
        canvas,
        Offset(f.$1 + r + x, f.$2 + r + y),
        r,
        f.$8,
        f.$5,
        f.$4,
        3,
        o,
      );
    }

    // Shooting stars — `ab-shoot`.
    for (final s in const [
      (-30.0, 60.0, 70.0, Color(0xE6FFFFFF), 17.0, 0.0),
      (40.0, 130.0, 54.0, Color(0xCCC8E4FF), 26.0, 11.0),
    ]) {
      final p = _loop(t, s.$5, -s.$6);
      const stops = [0.0, .06, .34, 1.0];
      final dx = _kf(p, stops, const [0, 33.5, 190, 190]);
      final dy = _kf(p, stops, const [0, 19.06, 108, 108]);
      final o = _kf(p, stops, const [0, 1, 0, 0]);
      if (o <= 0) continue;
      canvas.save();
      canvas.translate(s.$1 + s.$3 / 2 + dx, s.$2 + 1 + dy);
      canvas.rotate(28 * math.pi / 180);
      final rect = Rect.fromLTWH(-s.$3 / 2, -1, s.$3, 2);
      final col = s.$4.withValues(alpha: s.$4.a * o);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = ui.Gradient.linear(rect.centerLeft, rect.centerRight, [
            col.withValues(alpha: 0),
            col,
          ]),
      );
      canvas.restore();
    }

    // Twinkling stars — `ab-twinkle`.
    for (final s in const [
      (28.0, 120.0, 6.0, 10.0, 3.0, Color(0xCCFFE8A0), 3.2, 0.0),
      (300.0, 196.0, 5.0, 10.0, 3.0, Color(0xB3FFE8A0), 2.6, .7),
      (186.0, 86.0, 4.0, 8.0, 3.0, Color(0xB3FFE8A0), 4.0, 1.4),
      (74.0, 250.0, 4.0, 8.0, 3.0, Color(0x99FFE8A0), 3.6, .3),
      (126.0, 160.0, 3.0, 8.0, 2.0, Color(0x99FFE8A0), 2.9, 1.9),
      (342.0, 300.0, 5.0, 10.0, 3.0, Color(0x99FFE8A0), 3.4, 1.1),
    ]) {
      final p = _loop(t, s.$7, s.$8);
      final o = _kf(p, const [0, .5, 1], const [.25, 1, .25], _easeInOut);
      final sc = _kf(p, const [0, .5, 1], const [.8, 1.15, .8], _easeInOut);
      final r = s.$3 / 2;
      canvas.save();
      canvas.translate(s.$1 + r, s.$2 + r);
      canvas.scale(sc);
      _dot(
        canvas,
        Offset.zero,
        r,
        const Color(0xFFFFF3C4),
        s.$6,
        s.$4,
        s.$5,
        o,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.t != t;
}
