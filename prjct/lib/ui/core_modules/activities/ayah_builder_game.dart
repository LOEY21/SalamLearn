import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
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

/// Word card width: four cards fit one row of the 402-wide frame.
const double _kCardW = 84;
const String _kBg = 'assets/images/ayah_builder/bg_night_mosque.png';
const String _kA = 'assets/images/ayah_builder';
const String _kStartBg = '$_kA/start_bg.jpg';

const _cream = Color(0xFFFFF8E7);
const _gold = Color(0xFFFFD35C);
const _sky = Color(0xFF9FD6E8);
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
const _svgArrowDark =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#3A2306" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h13m-5-6 6 6-6 6"/></svg>';
const _svgSpeakerWide =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><path d="M11 5 6 9H3v6h3l5 4z" fill="#fff"/><path d="M15.5 9.2c1.3 1.4 1.3 4.2 0 5.6"/><path d="M18.3 6.5c2.6 2.8 2.6 8.2 0 11"/></svg>';
const _svgSpeaker =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><path d="M11 5 6 9H3v6h3l5 4z" fill="#fff"/><path d="M15.5 9.2c1.3 1.4 1.3 4.2 0 5.6"/></svg>';
const _svgStar =
    '<svg viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.1 6.6.9-4.8 4.7 1.2 6.6L12 17.6l-5.9 3.2 1.2-6.6L2.5 9.5l6.6-.9z" fill="#FFD35C"/></svg>';
const _svgCheck =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"><path d="m5 13 4 4 10-10"/></svg>';
const _svgCross =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#C93B3B" stroke-width="3.5" stroke-linecap="round"><path d="m6 6 12 12M18 6 6 18"/></svg>';

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
  // When the listen screen's ayah finished playing; Start building appears
  // only then.
  double? _listenDoneT;
  // When the reward screen started fading out for a replay.
  double? _exitT0;
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

  // The decoded backdrop plates and lantern sprites; until a scene's are all
  // in, its plain art stands in.
  final Map<String, ImageInfo> _art = {};

  @override
  void initState() {
    super.initState();
    _resetRound();
    for (final asset in [..._startScene.images, ..._gameScene.images]) {
      final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        stream.removeListener(listener);
        if (mounted) {
          setState(() => _art[asset] = info);
        } else {
          info.dispose();
        }
      });
      stream.addListener(listener);
    }
  }

  @override
  void dispose() {
    _clearTimers();
    _clock.dispose();
    for (final info in _art.values) {
      info.dispose();
    }
    super.dispose();
  }

  /// A scene's art, alive once decoded: [lights] paints its lantern glow and
  /// star twinkle instead of the art.
  Widget _scene(
    _Scene scene,
    double t, {
    required BoxFit fit,
    Alignment alignment = Alignment.center,
    bool lights = false,
  }) {
    if (!scene.images.every(_art.containsKey)) {
      return lights
          ? const SizedBox.shrink()
          : Image.asset(scene.asset, fit: fit, alignment: alignment);
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScenePainter(
          {for (final a in scene.images) a: _art[a]!.image},
          scene,
          t,
          fit: fit,
          alignment: alignment,
          lights: lights,
        ),
      ),
    );
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

  /// The back button on every screen past the start — returns to the start
  /// screen, abandoning the round in progress.
  void _onBack() {
    _clearTimers();
    setState(() {
      _resetRound();
      _go(_Screen.start);
    });
  }

  void _onBeginListen() {
    setState(() {
      _listenDoneT = null;
      _go(_Screen.listen);
    });
    _later(
      500,
      () => _playAyah(() {
        if (_screen == _Screen.listen) setState(() => _listenDoneT = _now);
      }),
    );
  }

  /// Plays the ayah again on the listen screen; the buttons step aside until
  /// it finishes.
  void _onReplayListen() {
    setState(() => _listenDoneT = null);
    _playAyah(() {
      if (_screen == _Screen.listen) setState(() => _listenDoneT = _now);
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

  /// Fades the reward screen out, then brings a fresh round of the puzzle in
  /// (the puzzle's own fade-in comes from [_screenTransition]).
  void _onReplay() {
    if (_exitT0 != null) return;
    _clearTimers();
    setState(() => _exitT0 = _now);
    _later(450, () {
      setState(() {
        _exitT0 = null;
        _resetRound();
        _go(_Screen.puzzle);
      });
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
              _scene(
                _gameScene,
                t,
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
              _scene(
                _gameScene,
                t,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                lights: true,
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
                        Positioned.fill(
                          child: _screenTransition(t, _buildScreen(t)),
                        ),
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

  /// The fade between screens: the reward screen shrinks and fades out when
  /// Replay is tapped, and the puzzle fades and settles in when it opens.
  Widget _screenTransition(double t, Widget screen) {
    var opacity = 1.0;
    var scale = 1.0;
    if (_exitT0 != null) {
      final e = Curves.easeInCubic.transform(_once(t - _exitT0!, .45));
      opacity = 1 - e;
      scale = 1 - .06 * e;
    } else if (_screen == _Screen.puzzle) {
      final u = Curves.easeOutCubic.transform(_once(t - _screenT0, .5));
      opacity = u;
      scale = .96 + .04 * u;
    }
    if (opacity >= 1 && scale >= 1) return screen;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(scale: scale, child: screen),
    );
  }

  Widget _buildScreen(double t) => switch (_screen) {
    _Screen.start => _buildStart(t),
    // The puzzle carries its back button in its own top bar.
    _Screen.puzzle => _buildPuzzle(t),
    _Screen.instructions => _withBack(_buildInstructions(t)),
    _Screen.listen => _withBack(_buildListen(t)),
    _Screen.reward => _withBack(_buildReward(t)),
  };

  Widget _withBack(Widget screen) => Stack(
    children: [
      Positioned.fill(child: screen),
      Positioned(left: 16, top: 48, child: _backButton(44)),
    ],
  );

  /// A round image button that swaps to its pressed art while held.
  Widget _imgButton(String name, double size, VoidCallback onTap, {Key? key}) =>
      SizedBox(
        width: size,
        height: size,
        child: _Press(
          key: key,
          onTap: onTap,
          builder: (pressed) => Image.asset(
            '$_kA/btn_${name}_${pressed ? 'down' : 'up'}.png',
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      );

  Widget _backButton(double size) =>
      _imgButton('back', size, _onBack, key: const ValueKey('ab-back'));

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
  /// crest, the hanging "Session N" ribbon, the session's name plate, the
  /// subtitle banner, and the Play button, which opens the how-to board.
  ///
  /// Every piece sits where the reference screen puts it, in the 402x874
  /// frame the scene art is drawn to.
  ///
  /// Each time the screen opens the pieces arrive in a staged entrance: the
  /// scene settles out of a slight zoom, the crest drops in, the ribbon falls
  /// and swings on its ropes, the name plate and subtitle pop in, Play
  /// bounces in and then stays put.
  Widget _buildStart(double t) {
    final s = _session;
    final st = t - _screenT0;
    // The ribbon hangs from its ropes behind the crest, so it swings about
    // its top edge as it lands — a damped sway — then keeps gently rocking
    // like a hanging sign.
    final rp = _once(st, 1.1, .6);
    final ribbonDrop = -46 * (1 - Curves.easeOutCubic.transform(_c01(rp / .4)));
    final ribbonSwing = rp <= 0
        ? 0.0
        : 7 * math.exp(-5 * rp) * math.cos(rp * 11) +
              1.6 * math.sin(t * 1.7) * _c01((st - 1.4) / .6);
    // Idle motion eases in once everything has arrived.
    final idle = _c01((st - 1.8) / .8);
    return Stack(
      children: [
        Positioned.fill(
          child: _enter(
            _once(st, 1.0),
            Stack(
              fit: StackFit.expand,
              children: [
                _scene(_startScene, t, fit: BoxFit.fill),
                _scene(_startScene, t, fit: BoxFit.fill, lights: true),
                IgnorePointer(
                  child: CustomPaint(painter: _StartScenePainter(t)),
                ),
              ],
            ),
            fromScale: 1.08,
            curve: Curves.easeOutCubic,
            fade: .5,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _StartFxPainter(t, st, behind: true)),
          ),
        ),
        Positioned(
          left: 92.2,
          top: 292,
          width: 216.6,
          height: 72.2,
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
          left: 47.9,
          top: 76.4,
          width: 308,
          height: 231,
          child: _enter(
            _once(st, .75, .2),
            Transform.scale(
              scale: 1 + .018 * math.sin(t * 1.5) * idle,
              child: _shine(
                t,
                4.5,
                1.2,
                Image.asset('$_kA/start_logo.png', fit: BoxFit.fill),
              ),
            ),
            dy: -24,
            fromScale: .7,
          ),
        ),
        Positioned(
          left: 95.4,
          top: 331,
          width: 210,
          height: 58,
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
                // The plate's cream panel spans 21%-79% of the art's width. It is
                // laid out a little flatter than its art, as the reference
                // screen draws it.
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
          left: 99,
          top: 356,
          width: 208,
          height: 69.3,
          child: _enter(
            _once(st, .45, 1.0),
            Image.asset('$_kA/start_subtitle.png', fit: BoxFit.fill),
            dy: 10,
            fromScale: .95,
            curve: Curves.easeOutCubic,
          ),
        ),
        Positioned(
          left: 87.1,
          top: 570.6,
          width: 226.8,
          height: 75.6,
          child: _enter(
            _once(st, .6, 1.2),
            fromScale: .4,
            _Press(
              key: const ValueKey('ab-play'),
              onTap: _onStart,
              builder: (pressed) => _shine(
                t,
                3.2,
                2.0,
                Image.asset(
                  '$_kA/${pressed ? 'start_play_down' : 'start_play_up'}.png',
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _StartFxPainter(t, st, behind: false)),
          ),
        ),
        if (widget.onExit != null)
          Positioned(
            left: 20,
            top: 48,
            child: _enter(
              _once(st, .4, 1.7),
              _imgButton(
                'home',
                46,
                widget.onExit!,
                key: const ValueKey('ab-home'),
              ),
              curve: Curves.easeOut,
            ),
          ),
      ],
    );
  }

  /// A glossy light band that sweeps across [child]'s opaque pixels every
  /// [period] seconds, starting [delay] seconds after the screen opens.
  Widget _shine(double t, double period, double delay, Widget child) {
    final st = t - _screenT0;
    if (st < delay) return child;
    final p = _loop(st - delay, period) * period / .9;
    if (p >= 1) return child;
    final x = -1.6 + 3.2 * Curves.easeInOut.transform(p);
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment(x - .5, -1),
        end: Alignment(x + .5, 1),
        colors: const [Color(0x00FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
        stops: const [.35, .5, .65],
      ).createShader(r),
      child: child,
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

  // ---- Instructions --------------------------------------------------------

  /// The how-to screen, built from the supplied "How to Play" board (its
  /// three illustrated steps are part of the art) with "Let's build ...
  /// together!" written into the board's empty bottom bar, and the I'm ready
  /// button beneath it.
  Widget _buildInstructions(double t) {
    final st = t - _screenT0;
    const panelLeft = 21.0;
    const panelTop = 150.0;
    const panelW = 360.0;
    const panelH = 460.8;
    return Stack(
      children: [
        Positioned(
          left: panelLeft,
          top: panelTop,
          width: panelW,
          height: panelH,
          child: _enter(
            _once(st, .6),
            dy: 24,
            fromScale: .92,
            Stack(
              children: [
                Positioned.fill(
                  child: Image.asset('$_kA/howto_panel.png', fit: BoxFit.fill),
                ),
                // The board's empty teal bar spans 11%-92% across and
                // 91%-98.6% down the art.
                Positioned(
                  left: panelW * .109,
                  width: panelW * (.922 - .109),
                  top: panelH * .910,
                  height: panelH * (.986 - .910),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Let's build ${_session.short} together!",
                        style: _baloo(
                          15,
                          800,
                          const Color(0xFFFFF1C9),
                          shadows: const [
                            Shadow(
                              color: Color(0x80000000),
                              offset: Offset(0, 1.5),
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
        ),
        Positioned(
          left: 51,
          top: panelTop + panelH + 22,
          width: 300,
          height: 66.8,
          child: _enter(
            _once(st, .5, .35),
            fromScale: .6,
            _Press(
              onTap: _onBeginListen,
              builder: (pressed) => Image.asset(
                '$_kA/btn_ready_${pressed ? 'down' : 'up'}.png',
                fit: BoxFit.fill,
                gaplessPlayback: true,
                semanticLabel: "I'm ready",
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Listen --------------------------------------------------------------

  /// The listen screen, built on the supplied arched panel: the ayah and
  /// speaker sit above the panel's gold divider, the auto-play note below
  /// it, and the Start building button art beneath the panel.
  Widget _buildListen(double t) {
    final st = t - _screenT0;
    // The speaker and equaliser only move while the ayah is playing.
    final wt = _ayahPlaying ? t : 0.0;
    const panelLeft = 19.0;
    const panelTop = 118.0;
    const panelW = 364.0;
    const panelH = 370.0;
    const innerW = panelW * .8;

    // Places [child] in the panel's inner column between two fractions of
    // its height, shrinking it only if it would not fit.
    Widget band(double top, double bottom, Widget child) => Positioned(
      left: (panelW - innerW) / 2,
      width: innerW,
      top: panelH * top,
      height: panelH * (bottom - top),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: innerW, child: child),
      ),
    );

    return Stack(
      children: [
        Positioned(left: 0, right: 0, top: 94, child: _eyebrow('Listen first')),
        Positioned(
          left: panelLeft,
          top: panelTop,
          width: panelW,
          height: panelH,
          child: _rise(
            _once(st, .5),
            Stack(
              children: [
                Positioned.fill(
                  child: Image.asset('$_kA/listen_panel.png', fit: BoxFit.fill),
                ),
                band(
                  .19,
                  .47,
                  Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _n; i++)
                        _listenWord(_words[i].text, _litIndex == i),
                    ],
                  ),
                ),
                band(
                  .47,
                  .60,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _speakerDisc(wt, 42, 20, 1.6, _svgSpeakerWide),
                      const SizedBox(width: 12),
                      _waveBars(wt, 4, 34, .9, .08, const [
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
                ),
                band(
                  .60,
                  .70,
                  Text(
                    _session.englishTranslation,
                    textAlign: TextAlign.center,
                    style: _nunito(14, 600, _cream, height: 1.4),
                  ),
                ),
                band(
                  .75,
                  .90,
                  Text(
                    'The full ayah plays automatically\nwhen the level opens.',
                    textAlign: TextAlign.center,
                    style: _nunito(13, 400, _cr(.7), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_listenDoneT != null)
          Positioned(
            left: 26,
            top: 761,
            width: 62,
            height: 61,
            child: _enter(
              _once(t - _listenDoneT!, .5),
              fromScale: .6,
              _Press(
                onTap: _onReplayListen,
                builder: (pressed) => Image.asset(
                  '$_kA/btn_replay_${pressed ? 'down' : 'up'}.png',
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  semanticLabel: 'Listen again',
                ),
              ),
            ),
          ),
        if (_listenDoneT != null)
          Positioned(
            left: 96,
            top: 760,
            width: 282,
            height: 63.4,
            child: _enter(
              _once(t - _listenDoneT!, .5),
              fromScale: .6,
              _Press(
                onTap: _onSkipToPuzzle,
                builder: (pressed) => Image.asset(
                  '$_kA/btn_start_building_${pressed ? 'down' : 'up'}.png',
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  semanticLabel: 'Start building',
                ),
              ),
            ),
          ),
      ],
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
        _backButton(38),
        const SizedBox(width: 6),
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
          child: SizedBox(
            height: 44,
            child: _Press(
              onTap: _playAyah,
              builder: (pressed) => Image.asset(
                '$_kA/btn_play_ayah_${pressed ? 'down' : 'up'}.png',
                fit: BoxFit.contain,
                gaplessPlayback: true,
                semanticLabel: 'Play Full Ayah',
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Sound off shows the pressed-in art, dimmed.
        SizedBox(
          width: 42,
          height: 42,
          child: _Press(
            onTap: () => setState(() => _soundOn = !_soundOn),
            builder: (pressed) => Opacity(
              opacity: _soundOn ? 1 : .55,
              child: Image.asset(
                '$_kA/btn_sound_${pressed || !_soundOn ? 'down' : 'up'}.png',
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Lays [count] cards out at the 4-word card size, splitting 5+ words
  /// into two centered rows (3 over 2) instead of squeezing one row.
  Widget _cardGrid(int count, double gap, Widget Function(int) item) {
    final perRow = count <= 4 ? count : (count / 2).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r * perRow < count; r++) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (
                var k = r * perRow;
                k < math.min(count, (r + 1) * perRow);
                k++
              ) ...[
                if (k > r * perRow) SizedBox(width: gap),
                SizedBox(width: _kCardW, height: 96, child: item(k)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _slotsRow(double t) => _cardGrid(
    _n,
    6,
    (i) => KeyedSubtree(key: _slotKeys[i], child: _slot(t, i)),
  );

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
                  Positioned.fill(child: _cardArt()),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(7, 8, 7, 12),
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
        // Traces the word card art's rounded rim while its word plays.
        if (_litIndex == i && filled)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(18, 22),
                  ),
                  border: Border.all(color: _gold, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: .7),
                      blurRadius: 18,
                      spreadRadius: 2,
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
  /// The stitched word card art.
  Widget _cardArt() => Image.asset(
    '$_kA/word_card.png',
    fit: BoxFit.fill,
    gaplessPlayback: true,
  );

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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            w.transliteration,
            maxLines: 1,
            style: _nunito(trSize, 700, trColor, height: 1.1),
          ),
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

  Widget _trayRow(double t) =>
      _cardGrid(_trayOrder.length, 7, (k) => _trayCard(t, _trayOrder[k]));

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
        Positioned.fill(child: _cardArt()),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 8, 7, 12),
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

  /// The end screen, laid out after the supplied "Masha'Allah!" reference:
  /// three stars over the ribbon banner, the built ayah panel, the two
  /// cheering kids around the cheer bubble, and replay / Next Session
  /// buttons, all over the same night backdrop as the game.
  /// The end screen, laid out after the supplied "Masha'Allah!" reference:
  /// three stars over the ribbon banner, the built ayah panel, the two
  /// cheering kids around the cheer bubble, and replay / Next Session
  /// buttons, all over the same night backdrop as the game.
  ///
  /// Entrance, in order: a warm glow and slow light rays open behind the
  /// banner as it drops in; the stars punch in one by one, each landing with
  /// a white flash and a sparkle burst; the star count, ayah panel and its
  /// word chips rise in; the kids slide in from the sides; the bubble pops;
  /// the buttons arrive last. Afterwards everything keeps a gentle idle:
  /// stars breathe their glow, the banner floats, the kids bounce and sway,
  /// Next Session softly pulses.
  Widget _buildReward(double t) {
    final st = t - _screenT0;
    // Idle motion eases in once the entrance is done, so nothing jumps.
    final idle = _c01((st - 2.2) / .8);

    Widget star(double size, double delay, double phase) {
      final p = _once(st, .55, delay);
      final s = _kf(p, const [0, .6, 1], const [0, 1.3, 1], _easeOut);
      final r = _kf(p, const [0, .6, 1], const [-50, 10, 0], _easeOut);
      final landed = _c01((st - delay - .33) / .45);
      // White flash as it lands, then a soft glint every few seconds.
      final glint = _kf(
        _loop(t, 3.2, phase),
        const [0, .08, .2, 1],
        const [0, .45, 0, 0],
      );
      final flash = (1 - landed) * (landed > 0 ? 1 : 0) + glint * idle;
      final breathe = .5 + .5 * math.sin(t * 2.4 + phase * 6);
      final img = Image.asset(
        '$_kA/reward_star.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
      return Transform.rotate(
        angle: r * math.pi / 180,
        child: Transform.scale(
          scale: s * (1 + .05 * breathe * idle),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1.35,
                child: Opacity(
                  opacity: _c01(landed * (.35 + .45 * breathe)),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                    child: img,
                  ),
                ),
              ),
              img,
              if (flash > 0)
                Opacity(
                  opacity: _c01(flash),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFFFFFFF),
                      BlendMode.srcATop,
                    ),
                    child: img,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget slideIn(double p, double dx, Widget child) {
      final u = Curves.easeOutBack.transform(p);
      return Opacity(
        opacity: Curves.easeOut.transform(_c01(p / .5)),
        child: Transform.translate(
          offset: Offset(dx * (1 - u), 0),
          child: child,
        ),
      );
    }

    final last = _sessionIdx + 1 >= widget.sessions.length;
    final bannerFloat = 2.5 * math.sin(t * 1.6) * idle;
    final girlHop = -6 * math.sin(t * 3.4).abs() * idle;
    final boySway = 2.2 * math.sin(t * 1.9) * idle;
    final nextPulse = 1 + .025 * math.sin(t * 3) * idle;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _RewardFxPainter(t, st, behind: true)),
          ),
        ),
        // The banner's cream panel keeps a band below its lettering for the
        // star count.
        Positioned(
          left: 31,
          top: 124 + bannerFloat,
          width: 340,
          height: 113,
          child: _enter(
            _once(st, .7, .05),
            dy: -70,
            fromScale: .55,
            fade: .35,
            Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    '$_kA/reward_banner.png',
                    fit: BoxFit.fill,
                    semanticLabel: "Masha'Allah!",
                  ),
                ),
                Positioned(
                  left: 90,
                  right: 90,
                  top: 113 * .70,
                  height: 113 * .16,
                  child: _rise(
                    _once(st, .5, 1.1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'You earned 1 star · $_stars total',
                        style: _baloo(14, 800, const Color(0xFF1B2F7E)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 76 + bannerFloat,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              star(50, .45, 0),
              const SizedBox(width: 4),
              star(66, .62, .33),
              const SizedBox(width: 4),
              star(50, .79, .66),
            ],
          ),
        ),
        Positioned(
          left: 36,
          right: 36,
          top: 252,
          child: _enter(
            _once(st, .6, .9),
            dy: 28,
            fromScale: .94,
            curve: Curves.easeOutCubic,
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: _panelGradient,
                border: Border.all(color: _gold, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(
                      alpha: .18 + .14 * math.sin(t * 2) * idle,
                    ),
                    blurRadius: 22,
                  ),
                  const BoxShadow(
                    color: Color(0x73000000),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _words.map((w) => w.text).join(' '),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: _arabic(28, _cream, 1.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _n; i++)
                        _pop(
                          _once(st, .4, 1.25 + .09 * i),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x382BB673),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x993ED598),
                              ),
                            ),
                            child: Text(
                              _words[i].transliteration,
                              style: _nunito(11.5, 700, _cream),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _rise(
                    _once(st, .5, 1.5),
                    Text(
                      _session.englishTranslation,
                      textAlign: TextAlign.center,
                      style: _nunito(13, 600, _cr(.9), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 470 + girlHop,
          width: 160,
          height: 232,
          child: slideIn(
            _once(st, .7, 1.35),
            -90,
            Image.asset('$_kA/reward_girl.png', fit: BoxFit.contain),
          ),
        ),
        Positioned(
          right: 10,
          top: 448,
          width: 160,
          height: 254,
          child: slideIn(
            _once(st, .7, 1.5),
            90,
            Transform.rotate(
              angle: boySway * math.pi / 180,
              alignment: Alignment.bottomCenter,
              child: Image.asset('$_kA/reward_boy.png', fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          left: 136,
          width: 130,
          top: 548 + 3 * math.sin(t * 1.4 + 1) * idle,
          child: _pop(
            _once(st, .45, 1.9),
            _bubble(
              Text(
                _session.cheer,
                textAlign: TextAlign.center,
                style: _nunito(11.5, 700, const Color(0xFF112233), height: 1.3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              radius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _RewardFxPainter(t, st, behind: false)),
          ),
        ),
        // Transition in from the finished puzzle: a warm flash that clears.
        if (st < .7)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color.fromRGBO(
                  255,
                  240,
                  200,
                  .6 * (1 - Curves.easeOutCubic.transform(_once(st, .7))),
                ),
              ),
            ),
          ),
        Positioned(
          left: 34,
          top: 744,
          width: 62,
          height: 61,
          child: _enter(
            _once(st, .55, 2.05),
            dy: 40,
            fromScale: .6,
            _Press(
              onTap: _onReplay,
              builder: (pressed) => Image.asset(
                '$_kA/btn_replay_${pressed ? 'down' : 'up'}.png',
                fit: BoxFit.fill,
                gaplessPlayback: true,
                semanticLabel: 'Replay',
              ),
            ),
          ),
        ),
        Positioned(
          left: 106,
          top: 741,
          width: 262,
          height: 70,
          child: _enter(
            _once(st, .55, 2.15),
            dy: 40,
            fromScale: .6,
            Transform.scale(
              scale: nextPulse,
              child: last
                  ? Center(child: _goldButton('Finish', _onNextSession))
                  : _Press(
                      onTap: _onNextSession,
                      builder: (pressed) => Image.asset(
                        '$_kA/btn_next_${pressed ? 'down' : 'up'}.png',
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        semanticLabel: 'Next Session',
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The end screen's light effects. Behind the banner ([behind]): a warm glow
/// and slowly turning light rays around the stars. In front: a sparkle burst
/// as each star lands, then scattered twinkles. [t] is the game clock and
/// [st] the time since the screen opened, both in seconds.
class _RewardFxPainter extends CustomPainter {
  _RewardFxPainter(this.t, this.st, {required this.behind});

  final double t;
  final double st;
  final bool behind;

  static const _center = Offset(201, 118);
  // Each star's centre and landing time, matching _buildReward's star row.
  static const _stars = [
    (Offset(139, 121), .78),
    (Offset(201, 109), .95),
    (Offset(263, 121), 1.12),
  ];
  static const _twinkles = [
    Offset(40, 96),
    Offset(84, 60),
    Offset(330, 70),
    Offset(372, 118),
    Offset(22, 200),
    Offset(386, 230),
    Offset(60, 420),
    Offset(350, 410),
    Offset(120, 250),
    Offset(290, 256),
    Offset(30, 640),
    Offset(376, 600),
    Offset(200, 700),
  ];

  static Path _sparkle(Offset c, double r) {
    final w = r * .28;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (behind) {
      final open = Curves.easeOutCubic.transform(_c01((st - .2) / .9));
      if (open <= 0) return;
      final breathe = .85 + .15 * math.sin(t * 1.8);
      canvas.drawCircle(
        _center,
        190,
        Paint()
          ..shader = ui.Gradient.radial(_center, 190, [
            Color.fromRGBO(255, 214, 110, .42 * open * breathe),
            const Color(0x00FFD66E),
          ]),
      );
      // Light rays: 14 soft wedges, slowly turning.
      canvas.save();
      canvas.translate(_center.dx, _center.dy);
      canvas.rotate(t * .12);
      final len = 230 * open;
      final ray = Paint()
        ..shader = ui.Gradient.radial(Offset.zero, len, [
          Color.fromRGBO(255, 232, 160, .30 * open * breathe),
          const Color(0x00FFE8A0),
        ]);
      for (var i = 0; i < 14; i++) {
        final a = i * 2 * math.pi / 14;
        const half = .085;
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(len * math.cos(a - half), len * math.sin(a - half))
            ..lineTo(len * math.cos(a + half), len * math.sin(a + half))
            ..close(),
          ray,
        );
      }
      canvas.restore();
      return;
    }

    // Landing bursts: 10 sparkles fly out from each star and fade.
    for (final (c, at) in _stars) {
      final p = _c01((st - at) / .9);
      if (p <= 0 || p >= 1) continue;
      final u = Curves.easeOutCubic.transform(p);
      final fade = 1 - Curves.easeIn.transform(p);
      canvas.drawCircle(
        c,
        14 + 46 * u,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * fade
          ..color = Color.fromRGBO(255, 236, 170, .7 * fade),
      );
      for (var i = 0; i < 10; i++) {
        final a = i * 2 * math.pi / 10 + at;
        final d = 18 + 58 * u * (i.isEven ? 1 : .75);
        canvas.drawPath(
          _sparkle(c + Offset(math.cos(a), math.sin(a)) * d, 5.5 * fade + 1),
          Paint()..color = Color.fromRGBO(255, 244, 200, fade),
        );
      }
    }

    // Twinkles: small four-point stars that fade in and out, each on its
    // own beat, once the stars have landed.
    final on = _c01((st - 1.2) / .8);
    if (on <= 0) return;
    for (var i = 0; i < _twinkles.length; i++) {
      final ph = _loop(t, 2.6 + (i % 4) * .5, i * .37);
      final a = math.pow(math.sin(ph * math.pi), 3).toDouble() * on;
      if (a <= .02) continue;
      final c = _twinkles[i];
      final r = 3.5 + (i % 3) * 1.6;
      canvas.drawCircle(
        c,
        r * 1.8,
        Paint()
          ..color = Color.fromRGBO(255, 226, 140, .35 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        _sparkle(c, r * (.7 + .3 * a)),
        Paint()..color = Color.fromRGBO(255, 248, 220, a),
      );
    }
  }

  @override
  bool shouldRepaint(_RewardFxPainter old) =>
      old.t != t || old.st != st || old.behind != behind;
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
/// clouds, mist, water shimmer, fireflies and meteors. [t] is the game clock
/// in seconds.
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

    // Meteors across the upper sky. The lantern glow and the art's own
    // stars twinkling are painted with the scene (see [_ScenePainter]).
    _paintMeteors(
      canvas,
      t,
      const Rect.fromLTWH(30, 20, 340, 150),
      const Rect.fromLTWH(0, 0, _kW, 340),
      every: 6,
      seed: 11,
    );
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.t != t;
}

/// The start screen's living night: the painted scene's own stars twinkle
/// and fireflies drift and blink through the garden (the lanterns' glow is
/// painted with the scene, see [_ScenePainter]). Positions are
/// read off `start_bg.jpg` in the 402x874 frame; [t] is the game clock in
/// seconds.
class _StartScenePainter extends CustomPainter {
  _StartScenePainter(this.t);

  final double t;

  // The art's stars — (x, y, size): sparkle-sized ones get a four-point
  // glint, the rest a soft glow.
  static const _stars = [
    (188.0, 41.6, 1.0),
    (147.0, 46.3, .5),
    (221.1, 37.3, .4),
    (246.1, 54.8, .8),
    (105.8, 96.4, 1.0),
    (162.5, 89.3, .5),
    (257.0, 95.9, .5),
    (131.3, 122.8, .5),
    (247.5, 130.8, 1.0),
    (208.3, 130.8, .4),
    (324.0, 146.0, .9),
    (190.8, 155.4, .6),
    (286.7, 166.7, .5),
    (150.7, 185.2, .5),
    (233.8, 185.6, .4),
    (273.0, 203.6, .7),
    (240.9, 215.4, .4),
    (180.9, 246.6, .8),
    (222.0, 245.2, .5),
    (182.8, 321.7, .5),
  ];

  // Fireflies — each wanders around a home spot on its own slow loop.
  static final _flies = () {
    final rnd = math.Random(7);
    const homes = [
      (70.0, 420.0),
      (330.0, 410.0),
      (150.0, 455.0),
      (255.0, 470.0),
      (200.0, 520.0),
      (40.0, 560.0),
      (365.0, 575.0),
      (60.0, 730.0),
      (345.0, 745.0),
      (110.0, 800.0),
      (300.0, 815.0),
      (200.0, 690.0),
    ];
    return [
      for (final h in homes)
        (
          x: h.$1,
          y: h.$2,
          ax: 14 + rnd.nextDouble() * 16,
          ay: 10 + rnd.nextDouble() * 14,
          wx: .25 + rnd.nextDouble() * .3,
          wy: .3 + rnd.nextDouble() * .35,
          wb: 1.1 + rnd.nextDouble() * 1.4,
          ph: rnd.nextDouble() * math.pi * 2,
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _kW, size.height / _kH);

    // Stars — each scintillating on its own uneven rhythm.
    for (var i = 0; i < _stars.length; i++) {
      final (x, y, s) = _stars[i];
      _twinkleStar(canvas, Offset(x, y), s, t, i, 1);
    }

    // Fireflies — drifting, blinking points of warm green-gold light.
    for (final f in _flies) {
      final x =
          f.x +
          f.ax * math.sin(t * f.wx + f.ph) +
          5 * math.sin(t * f.wx * 2.7 + f.ph * 1.3);
      final y =
          f.y +
          f.ay * math.cos(t * f.wy + f.ph * .7) +
          4 * math.sin(t * f.wy * 3.1 + f.ph);
      final b = math.pow(math.max(0.0, math.sin(t * f.wb + f.ph)), 2);
      final k = .15 + .85 * b;
      final c = Offset(x, y);
      canvas.drawCircle(
        c,
        7,
        Paint()
          ..color = const Color(0xFFE8FF8A).withValues(alpha: .45 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        c,
        1.6,
        Paint()..color = const Color(0xFFFFFDE0).withValues(alpha: k),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_StartScenePainter old) => old.t != t;
}

/// The start screen's extra light. Behind the pieces ([behind]): a warm halo
/// with slowly turning rays around the crest, a soft glow under Play, and
/// the odd meteor. In front: a sparkle burst as the crest lands
/// and as Play arrives. [t] is the game clock and [st] the time since the
/// screen opened, in seconds; positions are in the 402x874 frame.
class _StartFxPainter extends CustomPainter {
  _StartFxPainter(this.t, this.st, {required this.behind});

  final double t;
  final double st;
  final bool behind;

  static const _crest = Offset(202, 190);
  static const _play = Offset(200.5, 608);

  static Path _sparkle(Offset c, double r) {
    final w = r * .28;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
  }

  void _burst(Canvas canvas, Offset c, double at, double reach, int n) {
    final p = _c01((st - at) / 1.0);
    if (p <= 0 || p >= 1) return;
    final u = Curves.easeOutCubic.transform(p);
    final fade = 1 - Curves.easeIn.transform(p);
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n + .3;
      final d = reach * (.35 + .65 * u) * (i.isEven ? 1 : .8);
      canvas.drawPath(
        _sparkle(c + Offset(math.cos(a), math.sin(a) * .7) * d, 6 * fade + 1),
        Paint()..color = Color.fromRGBO(255, 244, 200, fade),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _kW, size.height / _kH);
    if (behind) {
      final open = Curves.easeOutCubic.transform(_c01((st - .5) / 1.0));
      if (open > 0) {
        final breathe = .8 + .2 * math.sin(t * 1.5);
        canvas.drawCircle(
          _crest,
          200,
          Paint()
            ..shader = ui.Gradient.radial(_crest, 200, [
              Color.fromRGBO(255, 210, 110, .38 * open * breathe),
              const Color(0x00FFD26E),
            ]),
        );
        canvas.save();
        canvas.translate(_crest.dx, _crest.dy);
        canvas.rotate(t * .1);
        final len = 240 * open;
        final ray = Paint()
          ..shader = ui.Gradient.radial(Offset.zero, len, [
            Color.fromRGBO(255, 232, 160, .22 * open * breathe),
            const Color(0x00FFE8A0),
          ]);
        for (var i = 0; i < 16; i++) {
          final a = i * 2 * math.pi / 16;
          const half = .07;
          canvas.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(len * math.cos(a - half), len * math.sin(a - half))
              ..lineTo(len * math.cos(a + half), len * math.sin(a + half))
              ..close(),
            ray,
          );
        }
        canvas.restore();
      }

      // Soft pulsing glow under Play once it has arrived.
      final pg = _c01((st - 1.8) / .6) * (.6 + .4 * math.sin(t * 2.6));
      if (pg > 0) {
        final m = Matrix4.identity()
          ..translateByDouble(_play.dx, _play.dy, 0, 1)
          ..scaleByDouble(1, .45, 1, 1)
          ..translateByDouble(-_play.dx, -_play.dy, 0, 1);
        canvas.drawRect(
          Rect.fromCenter(center: _play, width: 360, height: 140),
          Paint()
            ..shader = ui.Gradient.radial(
              _play,
              170,
              [Color.fromRGBO(255, 214, 100, .5 * pg), const Color(0x00FFD664)],
              null,
              TileMode.clamp,
              m.storage,
            ),
        );
      }

      // Meteors streak through the sky inside the arch now and then.
      if (st > 2) {
        _paintMeteors(
          canvas,
          t,
          const Rect.fromLTWH(110, 40, 180, 90),
          const Rect.fromLTRB(40, 25, 362, 330),
          every: 5,
          seed: 3,
        );
      }
    } else {
      _burst(canvas, _crest, .75, 170, 14);
      _burst(canvas, _play, 1.55, 140, 10);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StartFxPainter old) =>
      old.t != t || old.st != st || old.behind != behind;
}

// ---------------------------------------------------------------------------
// Living backdrops — the painted lanterns swing and the palms sway in the
// breeze by bending the background art itself on a mesh, so nothing painted
// is duplicated or ghosted. All rig positions are in the art's own pixels.
// ---------------------------------------------------------------------------

double _smooth(double x) {
  final u = _c01(x);
  return u * u * (3 - 2 * u);
}

Offset _rot(Offset v, Offset c, double a) {
  final d = v - c;
  final cs = math.cos(a);
  final sn = math.sin(a);
  return c + Offset(d.dx * cs - d.dy * sn, d.dx * sn + d.dy * cs);
}

/// The night breeze at art column [x]: a gusting sway, mostly leaning one
/// way with a softer swing back, reaching points further right a beat later.
double _breeze(double t, double x) {
  final u = t - x * .003;
  final gust = .6 + .4 * math.sin(u * .19 + 1.1);
  return gust * (.35 + .4 * math.sin(u * .8) + .25 * math.sin(u * 1.7 + 1.3));
}

/// A lantern hanging on a chain from [pivot], cut out of the art as its own
/// [sprite] (drawn at [origin]) with the art behind it painted in, so it
/// swings clear of the wall and sky. The chain meets the lantern at [joint].
/// It swings [amp] degrees on its own [period], nudged by the breeze, and
/// the body trails the chain a little like a real double pendulum.
class _Lantern {
  const _Lantern({
    required this.sprite,
    required this.origin,
    required this.pivot,
    required this.joint,
    required this.glow,
    required this.glowR,
    required this.period,
    required this.amp,
    required this.phase,
  });

  final String sprite;
  final Offset origin;
  final Offset pivot;
  final Offset joint;
  final Offset glow;
  final double glowR;
  final double period;
  final double amp;
  final double phase;

  double angle(double t) {
    final w = 2 * math.pi / period;
    final swing =
        math.sin(t * w + phase) * (.7 + .3 * math.sin(t * .23 + phase));
    return amp * (swing + .3 * _breeze(t, pivot.dx)) * math.pi / 180;
  }

  double lag(double t) =>
      -amp *
      .3 *
      math.sin(t * 2 * math.pi / period + phase - 1.3) *
      math.pi /
      180;

  /// Where the point [v] on the lantern moves to, given the chain angle [a]
  /// and the body's trailing [lag].
  Offset move(Offset v, double a, double lag) {
    final p = _rot(v, pivot, a);
    return v.dy > joint.dy ? _rot(p, _rot(joint, pivot, a), lag) : p;
  }

  /// The sprite in two pieces — chain and body — each on its own swing,
  /// shifted by [carry] when it hangs from a swaying frond.
  void paint(
    Canvas canvas,
    ui.Image image,
    double a,
    double lag,
    Offset carry,
  ) {
    final j = _rot(joint, pivot, a);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final body in [false, true]) {
      canvas.save();
      canvas.translate(carry.dx, carry.dy);
      if (body) {
        canvas.translate(j.dx, j.dy);
        canvas.rotate(lag);
        canvas.translate(-j.dx, -j.dy);
      }
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(a);
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.clipRect(
        body
            ? Rect.fromLTRB(-1e4, joint.dy, 1e4, 1e4)
            : Rect.fromLTRB(-1e4, -1e4, 1e4, joint.dy + .5),
      );
      canvas.drawImage(image, origin, paint);
      canvas.restore();
    }
  }
}

/// A palm rooted at [base] with its crown at [crown]: the trunk bends more
/// the higher it goes and the fronds flutter on top. Only the art inside
/// [box] moves, fading in over [feather] from its edges.
class _Palm {
  const _Palm({
    required this.base,
    required this.crown,
    required this.box,
    required this.amp,
    required this.flutter,
    this.feather = 22,
  });

  final Offset base;
  final Offset crown;
  final Rect box;
  final double amp;
  final double flutter;
  final double feather;

  Offset shift(Offset v, double t) {
    final m =
        _smooth((v.dx - box.left) / feather) *
        _smooth((box.right - v.dx) / feather) *
        _smooth((v.dy - box.top) / feather) *
        _smooth((box.bottom - v.dy) / feather);
    if (m <= 0) return Offset.zero;
    final reach = (crown - base).distance;
    final h = ((v - base).distance / reach).clamp(0.0, 1.6);
    final bend = amp * _breeze(t, crown.dx) * h * h;
    final r = _c01((v - crown).distance / reach);
    final a = math.atan2(v.dy - crown.dy, v.dx - crown.dx);
    final f =
        flutter *
        r *
        _smooth((h - .7) / .3) *
        (math.sin(t * 3.1 + a * 2.3 + r * 2.2) +
            .4 * math.sin(t * 5.3 + a * 3.7 + crown.dx));
    return Offset(bend + f * .4, f) * m;
  }
}

/// One piece of background art and everything alive in it.
class _Scene {
  const _Scene({
    required this.asset,
    required this.plate,
    required this.size,
    this.lanterns = const [],
    this.palms = const [],
    this.lamps = const [],
    this.stars = const [],
    this.bigStars = const [],
  });

  // The art, and the same art with its lanterns painted out.
  final String asset;
  final String plate;
  final Size size;
  final List<_Lantern> lanterns;
  final List<_Palm> palms;
  // Standing lanterns that only flicker: centre and glow radius.
  final List<(Offset, double)> lamps;
  // The art's small stars (x, y, brightness 0..1) and its big painted ones.
  final List<(double, double, double)> stars;
  final List<Offset> bigStars;

  List<String> get images => [plate, for (final l in lanterns) l.sprite];

  Offset palmShift(Offset v, double t) {
    var d = Offset.zero;
    for (final p in palms) {
      d += p.shift(v, t);
    }
    return d;
  }
}

const _startScene = _Scene(
  asset: _kStartBg,
  plate: '$_kA/start_bg_plate.jpg',
  size: Size(851, 1847),
  lanterns: [
    _Lantern(
      sprite: '$_kA/lantern_start_left.png',
      origin: Offset(72, 0),
      pivot: Offset(122, -10),
      joint: Offset(122, 150),
      glow: Offset(121, 262),
      glowR: 95,
      period: 3.1,
      amp: 2.3,
      phase: 0,
    ),
    _Lantern(
      sprite: '$_kA/lantern_start_right.png',
      origin: Offset(748, 39),
      pivot: Offset(792, 40),
      joint: Offset(792, 178),
      glow: Offset(793, 290),
      glowR: 90,
      period: 3.3,
      amp: 2.1,
      phase: 1.9,
    ),
  ],
  palms: [
    _Palm(
      base: Offset(62, 800),
      crown: Offset(78, 530),
      box: Rect.fromLTRB(54, 390, 205, 790),
      amp: 6,
      flutter: 3,
      feather: 26,
    ),
    _Palm(
      base: Offset(106, 812),
      crown: Offset(108, 728),
      box: Rect.fromLTRB(84, 640, 190, 800),
      amp: 3.5,
      flutter: 2.5,
      feather: 20,
    ),
    _Palm(
      base: Offset(782, 800),
      crown: Offset(765, 605),
      box: Rect.fromLTRB(635, 440, 827, 790),
      amp: 7,
      flutter: 3,
      feather: 26,
    ),
    _Palm(
      base: Offset(765, 810),
      crown: Offset(760, 745),
      box: Rect.fromLTRB(680, 668, 792, 800),
      amp: 3.5,
      flutter: 2.5,
      feather: 18,
    ),
    _Palm(
      base: Offset(665, 905),
      crown: Offset(665, 852),
      box: Rect.fromLTRB(600, 795, 728, 888),
      amp: 2.5,
      flutter: 1.8,
      feather: 16,
    ),
  ],
);

const _gameScene = _Scene(
  asset: _kBg,
  plate: '$_kA/bg_night_mosque_plate.jpg',
  size: Size(853, 1844),
  lanterns: [
    // The two lanterns on the left share a frond, so they sway together.
    _Lantern(
      sprite: '$_kA/lantern_game_left.png',
      origin: Offset(20, 65),
      pivot: Offset(62, 68),
      joint: Offset(62, 152),
      glow: Offset(60, 250),
      glowR: 80,
      period: 2.7,
      amp: 3,
      phase: 0,
    ),
    _Lantern(
      sprite: '$_kA/lantern_game_left_small.png',
      origin: Offset(87, 141),
      pivot: Offset(112, 145),
      joint: Offset(112, 310),
      glow: Offset(112, 368),
      glowR: 55,
      period: 2.7,
      amp: 3,
      phase: 0.3,
    ),
    _Lantern(
      sprite: '$_kA/lantern_game_right.png',
      origin: Offset(768, 124),
      pivot: Offset(801, 128),
      joint: Offset(801, 232),
      glow: Offset(801, 310),
      glowR: 70,
      period: 2.5,
      amp: 2.8,
      phase: 2.2,
    ),
  ],
  palms: [
    _Palm(
      base: Offset(-40, 280),
      crown: Offset(62, 58),
      box: Rect.fromLTRB(-100, -100, 228, 232),
      amp: 8,
      flutter: 4,
      feather: 28,
    ),
    _Palm(
      base: Offset(900, 260),
      crown: Offset(850, 38),
      box: Rect.fromLTRB(695, -100, 953, 212),
      amp: 7,
      flutter: 3.5,
      feather: 24,
    ),
    _Palm(
      base: Offset(-15, 1010),
      crown: Offset(14, 836),
      box: Rect.fromLTRB(-100, 752, 112, 1000),
      amp: 6,
      flutter: 3,
    ),
    _Palm(
      base: Offset(872, 1100),
      crown: Offset(842, 812),
      box: Rect.fromLTRB(742, 752, 953, 1000),
      amp: 6,
      flutter: 3,
    ),
    _Palm(
      base: Offset(822, 1065),
      crown: Offset(815, 973),
      box: Rect.fromLTRB(770, 938, 953, 1048),
      amp: 3,
      flutter: 2,
      feather: 16,
    ),
    _Palm(
      base: Offset(252, 1075),
      crown: Offset(257, 1008),
      box: Rect.fromLTRB(222, 978, 294, 1062),
      amp: 2.5,
      flutter: 1.6,
      feather: 14,
    ),
  ],
  lamps: [(Offset(47, 1190), 60), (Offset(807, 1190), 60)],
  stars: [
    (600, 52.5, 1),
    (813, 598, 1),
    (213.6, 519.6, 1),
    (468.5, 71.5, .7),
    (16.5, 569.5, .7),
    (676, 636, .7),
    (654.8, 22.5, .7),
    (519, 27, .7),
    (311, 445, .7),
    (599, 258, .45),
    (338, 142, .45),
    (560, 189.5, .45),
    (555, 215.5, .45),
    (690, 49.6, .45),
    (435, 265, .45),
    (525.7, 361, .45),
    (642.7, 523, .45),
    (378, 227, .45),
    (510, 296.5, .45),
    (458.5, 332, .45),
    (331, 23, .45),
    (359, 78, .45),
    (239, 102, .45),
    (640, 286, .45),
    (163, 435, .45),
    (408, 19, .3),
    (581.5, 101.5, .3),
    (234.5, 150.5, .3),
    (306.5, 185.5, .3),
    (324.5, 276.5, .3),
    (309.8, 325, .3),
    (342.5, 403.5, .3),
    (443.5, 434.5, .3),
    (51.5, 571.5, .3),
    (570, 145, .3),
    (475, 189, .3),
    (667, 261, .3),
    (365, 333, .3),
    (478, 398, .3),
    (347, 560, .3),
    (103, 580, .3),
    (416, 659, .3),
    (541, 699, .3),
  ],
  bigStars: [
    Offset(762, 695),
    Offset(54, 626),
    Offset(232, 224),
    Offset(593, 450),
    Offset(518, 137),
    Offset(261, 34),
    Offset(696, 317),
  ],
);

/// A grid over a scene's art, [step] art pixels apart. Only the cells near a
/// palm are drawn, and only their corners ([live]) are ever moved.
class _Mesh {
  _Mesh(_Scene s) {
    const step = 14.0;
    final cols = (s.size.width / step).ceil();
    final rows = (s.size.height / step).ceil();
    final w = cols + 1;
    base = Float32List(w * (rows + 1) * 2);
    for (var j = 0; j <= rows; j++) {
      for (var i = 0; i <= cols; i++) {
        final k = (j * w + i) * 2;
        base[k] = math.min(i * step, s.size.width);
        base[k + 1] = math.min(j * step, s.size.height);
      }
    }
    final zones = [for (final p in s.palms) p.box];
    final idx = <int>[];
    final live = <int>{};
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final cell = Rect.fromLTWH(i * step, j * step, step, step);
        if (!zones.any(cell.overlaps)) continue;
        final a = j * w + i;
        idx.addAll([a, a + 1, a + w, a + 1, a + w + 1, a + w]);
        live.addAll([a, a + 1, a + w, a + w + 1]);
      }
    }
    indices = Uint16List.fromList(idx);
    this.live = live.toList();
  }

  late final Float32List base;
  late final Uint16List indices;
  late final List<int> live;

  static final _cache = <String, _Mesh>{};
  static _Mesh of(_Scene s) => _cache[s.asset] ??= _Mesh(s);
}

/// Paints a scene's art fitted like an [Image] with [fit] and [alignment]:
/// the art itself with its palms swaying and lanterns swinging, or — with
/// [lights] — the glow of its lanterns and the twinkle of its stars, to lay
/// over whatever shading sits on top of the art.
class _ScenePainter extends CustomPainter {
  _ScenePainter(
    this.images,
    this.scene,
    this.t, {
    required this.fit,
    this.alignment = Alignment.center,
    this.lights = false,
  });

  // The scene's plate and lantern sprites, by asset.
  final Map<String, ui.Image> images;
  final _Scene scene;
  final double t;
  final BoxFit fit;
  final Alignment alignment;
  final bool lights;

  @override
  void paint(Canvas canvas, Size size) {
    final art = scene.size;
    final fs = applyBoxFit(fit, art, size);
    final src = alignment.inscribe(fs.source, Offset.zero & art);
    final dst = alignment.inscribe(fs.destination, Offset.zero & size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / src.width, dst.height / src.height);
    canvas.translate(-src.left, -src.top);
    lights ? _paintLights(canvas) : _paintArt(canvas);
    canvas.restore();
  }

  /// Each lantern's chain angle, body lag and how far the frond it hangs
  /// from has carried its pivot.
  List<(double, double, Offset)> _poses() => [
    for (final l in scene.lanterns)
      (l.angle(t), l.lag(t), scene.palmShift(l.pivot, t)),
  ];

  void _paintArt(Canvas canvas) {
    final image = images[scene.plate]!;
    final full = Size(image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(
      image,
      Offset.zero & full,
      Offset.zero & scene.size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final mesh = _Mesh.of(scene);
    final pos = Float32List.fromList(mesh.base);
    for (final k in mesh.live) {
      final v = Offset(mesh.base[k * 2], mesh.base[k * 2 + 1]);
      final d = scene.palmShift(v, t);
      pos[k * 2] += d.dx;
      pos[k * 2 + 1] += d.dy;
    }
    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      pos,
      textureCoordinates: mesh.base,
      indices: mesh.indices,
    );
    canvas.drawVertices(
      vertices,
      BlendMode.srcOver,
      Paint()
        ..shader = ImageShader(
          image,
          TileMode.clamp,
          TileMode.clamp,
          (Matrix4.identity()..scaleByDouble(
                scene.size.width / full.width,
                scene.size.height / full.height,
                1,
                1,
              ))
              .storage,
          filterQuality: FilterQuality.medium,
        ),
    );
    vertices.dispose();
    final poses = _poses();
    for (var i = 0; i < scene.lanterns.length; i++) {
      final l = scene.lanterns[i];
      final (a, lag, carry) = poses[i];
      l.paint(canvas, images[l.sprite]!, a, lag, carry);
    }
  }

  void _glow(Canvas canvas, Offset c, double r, double k) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c, r, [
          const Color(0xFFFFC862).withValues(alpha: .38 * k),
          const Color(0xFFFFC862).withValues(alpha: 0),
        ])
        ..blendMode = BlendMode.plus,
    );
    canvas.drawCircle(
      c,
      r * .28,
      Paint()
        ..color = const Color(0xFFFFF1C2).withValues(alpha: .4 * k)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .14)
        ..blendMode = BlendMode.plus,
    );
  }

  /// A candle's light: a slow breath with an uneven, quick flicker on top.
  double _flame(double ph) {
    final breath = .5 + .5 * math.sin(t * 1.3 + ph);
    final flick =
        .1 * math.sin(t * 11.7 + ph * 3) * math.sin(t * 6.1 + ph) +
        .06 * math.sin(t * 23 + ph * 5);
    return (.55 + .35 * breath + flick).clamp(0.0, 1.0);
  }

  void _paintLights(Canvas canvas) {
    final poses = _poses();
    for (var i = 0; i < scene.lanterns.length; i++) {
      final l = scene.lanterns[i];
      final (a, lag, carry) = poses[i];
      _glow(canvas, l.move(l.glow, a, lag) + carry, l.glowR, _flame(i * 1.9));
    }
    for (var i = 0; i < scene.lamps.length; i++) {
      final (c, r) = scene.lamps[i];
      _glow(canvas, c, r, _flame(4 + i * 2.3));
    }
    for (var i = 0; i < scene.bigStars.length; i++) {
      final c = scene.bigStars[i];
      final k = _scintillate(t * .6, i + 40);
      canvas.drawCircle(
        c,
        30,
        Paint()
          ..shader = ui.Gradient.radial(c, 30, [
            const Color(0xFFFFE48A).withValues(alpha: .3 * k),
            const Color(0x00FFE48A),
          ])
          ..blendMode = BlendMode.plus,
      );
    }
    for (var i = 0; i < scene.stars.length; i++) {
      final (x, y, s) = scene.stars[i];
      _twinkleStar(canvas, Offset(x, y), s, t, i, 2.1);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.t != t || old.images != images || old.lights != lights;
}

/// How bright star [i] looks at [t], 0..1: starlight through moving air
/// wanders quickly and unevenly, with a rare brief flare.
double _scintillate(double t, int i) {
  final a = i * 1.7;
  final s =
      .55 +
      .2 * math.sin(t * (1.1 + (i % 5) * .23) + a) +
      .15 * math.sin(t * (4.7 + (i % 3) * .9) + a * 2.3) +
      .1 * math.sin(t * (9.3 + (i % 4) * 1.3) + a * .7);
  final flare = math.pow(math.max(0.0, math.sin(t * .29 + a * 3.1)), 40);
  return _c01(s + .45 * flare);
}

/// A star at [c] twinkling: a soft halo, thin diffraction spikes on the
/// brighter ones ([s] is its size 0..1) and a bright core, its colour
/// flashing faintly between warm and cool. [unit] scales it to the canvas.
void _twinkleStar(
  Canvas canvas,
  Offset c,
  double s,
  double t,
  int i,
  double unit,
) {
  final k = _scintillate(t, i);
  final col = Color.lerp(
    const Color(0xFFCFE3FF),
    const Color(0xFFFFF3C4),
    .5 + .5 * math.sin(t * 2.3 + i * 2.1),
  )!;
  canvas.drawCircle(
    c,
    (2 + 5 * s) * (.6 + .6 * k) * unit,
    Paint()
      ..color = col.withValues(alpha: .45 * k)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (1.5 + 3 * s) * unit)
      ..blendMode = BlendMode.plus,
  );
  if (s >= .6) {
    final len = (4 + 9 * s) * k * k * unit;
    for (final d in [Offset(len, 0), Offset(0, len)]) {
      canvas.drawLine(
        c - d,
        c + d,
        Paint()
          ..strokeWidth = .8 * unit
          ..shader = ui.Gradient.linear(
            c - d,
            c + d,
            [
              col.withValues(alpha: 0),
              col.withValues(alpha: .9 * k),
              col.withValues(alpha: 0),
            ],
            const [0, .5, 1],
          ),
      );
    }
  }
  canvas.drawCircle(
    c,
    (.5 + .7 * s) * unit,
    Paint()..color = Colors.white.withValues(alpha: .5 + .5 * k),
  );
}

/// Meteors at random moments: every [every] seconds one may streak from
/// somewhere in [spawn] — fast, bright at the head with a tapering tail,
/// leaving a faint train that lingers a moment. Drawn inside [clip].
void _paintMeteors(
  Canvas canvas,
  double t,
  Rect spawn,
  Rect clip, {
  required double every,
  required int seed,
}) {
  canvas.save();
  canvas.clipRect(clip);
  final slot = (t / every).floor();
  for (var n = slot - 1; n <= slot; n++) {
    final rnd = math.Random(n * 7919 + seed);
    if (rnd.nextDouble() > .6) continue;
    final start = n * every + rnd.nextDouble() * (every - 1.5);
    final dur = .45 + rnd.nextDouble() * .45;
    final e = t - start;
    if (e < 0 || e > dur + .9) continue;
    final from = Offset(
      spawn.left + rnd.nextDouble() * spawn.width,
      spawn.top + rnd.nextDouble() * spawn.height,
    );
    final ang = (18 + rnd.nextDouble() * 24) * math.pi / 180;
    final dir = Offset(
      math.cos(ang) * (rnd.nextBool() ? 1 : -1),
      math.sin(ang),
    );
    final dist = 90 + rnd.nextDouble() * 110;
    final mag = .6 + rnd.nextDouble() * .4;
    final u = _c01(e / dur);
    final head = from + dir * (dist * u);
    // The faint train it leaves along the path, lingering after it's gone.
    final train = e <= dur ? .16 : .16 * (1 - (e - dur) / .9);
    if (train > 0 && u > 0) {
      canvas.drawLine(
        from,
        head,
        Paint()
          ..strokeWidth = .9
          ..shader = ui.Gradient.linear(from, head, [
            const Color(0x00BFD9FF),
            Color.fromRGBO(191, 217, 255, train * mag),
          ]),
      );
    }
    if (e > dur) continue;
    final b = math.sin(math.pi * math.pow(u, .7)) * mag;
    final tail = head - dir * (dist * .45 * math.min(1, u * 2.5));
    final perp = Offset(-dir.dy, dir.dx) * (1.1 + .8 * mag);
    canvas.drawPath(
      Path()
        ..moveTo(tail.dx, tail.dy)
        ..lineTo(head.dx + perp.dx, head.dy + perp.dy)
        ..lineTo(head.dx - perp.dx, head.dy - perp.dy)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(tail, head, [
          const Color(0x00CFE6FF),
          Color.fromRGBO(235, 245, 255, .95 * b),
        ])
        ..blendMode = BlendMode.plus,
    );
    canvas.drawCircle(
      head,
      3.2,
      Paint()
        ..color = Color.fromRGBO(210, 235, 255, .7 * b)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..blendMode = BlendMode.plus,
    );
    canvas.drawCircle(
      head,
      1.2,
      Paint()..color = Color.fromRGBO(255, 255, 255, b),
    );
  }
  canvas.restore();
}
