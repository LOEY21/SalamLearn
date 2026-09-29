import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import 'taharah_wudhu_audio.dart';

/// Taharah Adventure — ported 1:1 from the supplied "Taharah Adventure"
/// prototypes:
///
/// * [TaharahSession.cleanOrDirty] — Session 1, "Clean or Dirty?": drag six
///   habit cards into the Sparkling Clean or Dirty / Trash bin.
/// * [TaharahSession.wudhuPart1] — Session 2, Wudhu Part 1: tap the boy's
///   hands, mouth, nose, face and arms in order.
/// * [TaharahSession.wudhuPart2] — Session 3, Wudhu Part 2: left arm, head,
///   ears, right foot, left foot.
///
/// The prototypes are authored against a fixed 390x844 phone frame, so each
/// screen is laid out inside that virtual stage and scaled to fit, while the
/// painted backgrounds run on to the screen edges.
class TaharahAdventureGame extends StatelessWidget {
  const TaharahAdventureGame({
    super.key,
    required this.session,
    required this.xp,
    required this.onComplete,
    this.onEnding,
    this.onExit,
  });

  final TaharahSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Fired when the game's own ending screen appears (the lesson player's
  /// cue for its congratulations sound).
  final VoidCallback? onEnding;

  /// Leaves the lesson from the start screen's back button.
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) => switch (session) {
    TaharahSession.cleanOrDirty => _CleanOrDirty(
      xp: xp,
      onComplete: onComplete,
      onEnding: onEnding,
      onExit: onExit,
    ),
    TaharahSession.wudhuPart1 => _Wudhu(
      part: _kPart1,
      xp: xp,
      onComplete: onComplete,
      onEnding: onEnding,
      onExit: onExit,
    ),
    TaharahSession.wudhuPart2 => _Wudhu(
      part: _kPart2,
      xp: xp,
      onComplete: onComplete,
      onEnding: onEnding,
      onExit: onExit,
    ),
  };
}

// ---------------------------------------------------------------------------
// Stage, palette, type
// ---------------------------------------------------------------------------

const double _kW = 390;
const double _kH = 844;
const String _kA = 'assets/images/taharah';

const Color _cream = Color(0xFFFFFDF6);
const Color _brown = Color(0xFF8A5A24);
const Color _blue = Color(0xFF1F6FD0);
const Color _green = Color(0xFF2E9E4B);
const Color _greenTop = Color(0xFF46BF62);
const Color _greenDeep = Color(0xFF1F7436);
const Color _red = Color(0xFFD0442B);
const Color _redInk = Color(0xFFA3341F);
const Color _gold = Color(0xFFFFD97A);

Color _rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a);
TextStyle _baloo(
  double size,
  Color color, {
  double weight = 800,
  double? height,
  double ls = 0,
  List<Shadow>? shadows,
}) => TextStyle(
  fontFamily: 'Baloo2Var',
  fontSize: size,
  fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
  fontVariations: [ui.FontVariation.weight(weight)],
  color: color,
  height: height,
  letterSpacing: ls,
  shadows: shadows,
);

TextStyle _nunito(
  double size,
  Color color, {
  double weight = 700,
  double? height,
}) => TextStyle(
  fontFamily: 'NunitoVar',
  fontSize: size,
  fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
  fontVariations: [ui.FontVariation.weight(weight)],
  color: color,
  height: height,
);

/// The prototype's 390x844 frame, scaled to fit inside the safe area.
Widget _stage(Widget child, {Key? key}) => SafeArea(
  child: SizedBox.expand(
    child: FittedBox(
      child: SizedBox(key: key, width: _kW, height: _kH, child: child),
    ),
  ),
);

LinearGradient _vGrad(List<Color> colors, [List<double>? stops]) =>
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    );

/// CSS `filter: drop-shadow(0 dy blur color)` on a transparent PNG.
Widget _dropShadow(Widget img, double dy, double blur, Color color) => Stack(
  children: [
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
    img,
  ],
);

// ---------------------------------------------------------------------------
// Keyframes
// ---------------------------------------------------------------------------

/// Piecewise keyframe interpolation, [curve] applied per segment like CSS.
double _kf(
  double t,
  List<double> stops,
  List<double> vals, [
  Curve curve = Curves.ease,
]) {
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i]) {
      final u = ((t - stops[i - 1]) / (stops[i] - stops[i - 1])).clamp(
        0.0,
        1.0,
      );
      return ui.lerpDouble(vals[i - 1], vals[i], curve.transform(u))!;
    }
  }
  return vals.last;
}

/// One-shot animation that starts on mount (after [delay]) and holds its
/// first frame until then — CSS `animation-fill-mode: both`. Re-key to replay.
class _Once extends StatefulWidget {
  const _Once({
    super.key,
    required this.duration,
    required this.builder,
    this.delay = Duration.zero,
    this.child,
  });

  final Duration duration;
  final Duration delay;
  final Widget Function(double t, Widget? child) builder;
  final Widget? child;

  @override
  State<_Once> createState() => _OnceState();
}

class _OnceState extends State<_Once> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _delay = Timer(widget.delay, _c.forward);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) => widget.builder(_c.value, child),
  );
}

/// Infinite animation loop; [builder] gets 0..1 each [period].
class _Loop extends StatefulWidget {
  const _Loop({required this.period, required this.builder, this.child});

  final Duration period;
  final Widget Function(double t, Widget? child) builder;
  final Widget? child;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) => widget.builder(_c.value, child),
  );
}

/// `tapop` — scale .6 → 1.08 → 1 while fading in.
Widget _pop(
  Duration d,
  Widget child, {
  Key? key,
  Duration delay = Duration.zero,
}) => _Once(
  key: key,
  duration: d,
  delay: delay,
  child: child,
  builder: (t, c) => Opacity(
    opacity: Curves.ease.transform(t),
    child: Transform.scale(scale: _kf(t, [0, .6, 1], [.6, 1.08, 1]), child: c),
  ),
);

/// `tarise` — slide up 14px while fading in.
Widget _rise(
  Duration d,
  Widget child, {
  Key? key,
  Duration delay = Duration.zero,
}) => _Once(
  key: key,
  duration: d,
  delay: delay,
  child: child,
  builder: (t, c) {
    final e = Curves.ease.transform(t);
    return Opacity(
      opacity: e,
      child: Transform.translate(offset: Offset(0, 14 * (1 - e)), child: c),
    );
  },
);

/// `tashake` — horizontal wobble, [times] iterations.
Widget _shake(Duration d, Widget child, {Key? key, int times = 1}) => _Once(
  key: key,
  duration: d * times,
  child: child,
  builder: (t, c) {
    final u = t >= 1 ? 1.0 : (t * times) % 1;
    final dx = _kf(u, [0, .2, .4, .6, .8, 1], [0, -8, 8, -5, 5, 0]);
    return Transform.translate(offset: Offset(dx, 0), child: c);
  },
);

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// A button with the prototypes' chunky offset shadow that sinks on press.
class _Btn extends StatefulWidget {
  const _Btn({
    required this.child,
    required this.radius,
    this.onTap,
    this.gradient,
    this.shadows = const [],
    this.pressedShadows,
    this.pressDy = 0,
    this.width,
    this.height,
  });

  final Widget child;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final List<BoxShadow> shadows;
  final List<BoxShadow>? pressedShadows;
  final double pressDy;
  final double? width;
  final double? height;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
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
      child: Transform.translate(
        offset: Offset(0, _down ? widget.pressDy : 0),
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: _down
                ? (widget.pressedShadows ?? widget.shadows)
                : widget.shadows,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _Toast {
  const _Toast(this.text, this.icon, {required this.good});
  final String text;
  final String icon;
  final bool good;
}

/// Feedback card. Session 1 and the Wudhu sessions use slightly different
/// greens/reds, as in the prototypes.
Widget _toastCard(_Toast t, {Key? key, bool wudhu = false}) {
  final ok = t.good;
  final bg = ok
      ? Color(wudhu ? 0xFFE9F9EC : 0xFFEAFAEF)
      : Color(wudhu ? 0xFFFDECEB : 0xFFFDECEA);
  final border = ok
      ? (wudhu ? _green : const Color(0xFF7FD39A))
      : (wudhu ? _red : const Color(0xFFF0A79A));
  return _rise(
    const Duration(milliseconds: 280),
    key: key,
    Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(width: 3, color: border),
        boxShadow: [
          BoxShadow(
            color: _rgba(0, 0, 0, wudhu ? .3 : .28),
            offset: const Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(t.icon, style: const TextStyle(fontSize: 26, height: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.text,
              style: _baloo(18, ok ? _greenDeep : _redInk, height: 1.2),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dashed outline around an oval (radius null) or rounded rect.
Path _shapePath(Rect r, double? radius) => radius == null
    ? (Path()..addOval(r))
    : (Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))));

Path _dashed(Path src, double dash, double gap) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.width, this.radius});

  final Color color;
  final double width;
  final double? radius;

  @override
  void paint(Canvas canvas, Size size) {
    final inner = (Offset.zero & size).deflate(width / 2);
    canvas.drawPath(
      _dashed(
        _shapePath(inner, radius == null ? null : radius! - width / 2),
        width * 3,
        width * 2,
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

class _ShapeClip extends CustomClipper<Path> {
  const _ShapeClip(this.radius);
  final double? radius;

  @override
  Path getClip(Size size) => _shapePath(Offset.zero & size, radius);

  @override
  bool shouldReclip(_ShapeClip old) => old.radius != radius;
}

/// Solid-art bounds of the game's item (1024x1536) and bin (1346x1168)
/// images, so each can be fitted by what's visible rather than its canvas.
const Map<String, (Size, Rect)> _kArtBounds = {
  'wash_hands': (Size(1024, 1536), Rect.fromLTRB(180, 410, 849, 1089)),
  'brush_teeth': (Size(1024, 1536), Rect.fromLTRB(270, 358, 776, 1162)),
  'dirty_clothes': (Size(1024, 1536), Rect.fromLTRB(138, 456, 887, 1084)),
  'muddy_shoes': (Size(1024, 1536), Rect.fromLTRB(108, 494, 924, 966)),
  'throw_trash': (Size(1024, 1536), Rect.fromLTRB(36, 263, 992, 1163)),
  'cut_nails': (Size(1024, 1536), Rect.fromLTRB(251, 430, 792, 966)),
  'bin-clean': (Size(1346, 1168), Rect.fromLTRB(115, 77, 1228, 1122)),
  'bin-dirty': (Size(1346, 1168), Rect.fromLTRB(112, 73, 1231, 1121)),
};

/// Game art [name] placed so its visible part fits [target] (contain,
/// centred). Must sit directly in a Stack.
Widget _art(String name, Rect target) {
  final (canvas, bb) = _kArtBounds[name]!;
  final k = math.min(target.width / bb.width, target.height / bb.height);
  return Positioned(
    left: target.center.dx - bb.center.dx * k,
    top: target.center.dy - bb.center.dy * k,
    width: canvas.width * k,
    height: canvas.height * k,
    child: Image.asset('$_kA/$name.png', fit: BoxFit.fill),
  );
}

/// Red "drag it here" arrow for How to Play step 2: from the dirty shirt,
/// over the clean bin, down into the dirty one.
class _DragArrow extends CustomPainter {
  const _DragArrow();

  @override
  void paint(Canvas canvas, Size size) {
    const from = Offset(190, 58);
    const ctrl = Offset(395, -40);
    const to = Offset(545, 58);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
    final dir = (to - ctrl) / (to - ctrl).distance;
    final side = Offset(-dir.dy, dir.dx);
    final tip = to + dir * 34;
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((to + side * 26).dx, (to + side * 26).dy)
      ..lineTo((to - side * 26).dx, (to - side * 26).dy)
      ..close();
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke(const Color(0xFF7A0E0E), 26));
    canvas.drawPath(head, stroke(const Color(0xFF7A0E0E), 12));
    canvas.drawPath(path, stroke(const Color(0xFFE8262B), 16));
    canvas.drawPath(head, Paint()..color = const Color(0xFFE8262B));
  }

  @override
  bool shouldRepaint(_DragArrow old) => false;
}

/// The "Clean or Dirty?" title over the game screen: the two painted words
/// with a small live "or" tucked between them, plus a few sparkles.
class _GameLogo extends StatelessWidget {
  const _GameLogo();

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Image.asset('$_kA/game_word_clean.png', height: 110),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 44),
                child: _outlined(
                  'or',
                  _baloo(40, const Color(0xFF3DA0F5), height: 1),
                  const Color(0xFF0E3E8C),
                  9,
                ),
              ),
              Image.asset('$_kA/game_word_dirty.png', height: 112),
            ],
          ),
        ),
      ),
      for (final (x, y, sz) in [
        (-8.0, 96.0, 52.0),
        (26.0, 128.0, 30.0),
        (256.0, 110.0, 44.0),
      ])
        Positioned(
          left: x,
          top: y,
          child: _outlined(
            '✦',
            TextStyle(fontSize: sz, color: const Color(0xFFFFE27A), height: 1),
            const Color(0xFFC98A12),
            4,
          ),
        ),
    ],
  );
}

/// The Wudhu washroom with its painted plants swaying (shaders/wudhu_bg.frag):
/// the room with the leaves painted out (s2-bg_clean.png) stays still, and
/// the leaves alone (s2-bg_leaves.png) sway over it, bent per
/// s2-bg_plants.png. Laid out like
/// `Image.asset(fit: BoxFit.cover)`, which it shows until the shader is
/// ready or wherever shaders aren't available.
class _LiveWashroom extends StatefulWidget {
  const _LiveWashroom();

  @override
  State<_LiveWashroom> createState() => _LiveWashroomState();
}

class _LiveWashroomState extends State<_LiveWashroom>
    with SingleTickerProviderStateMixin {
  /// Shader program and images, loaded once and shared by every screen.
  static Future<(ui.FragmentProgram, ui.Image, ui.Image, ui.Image)>? _assets;

  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  ui.FragmentShader? _shader;
  ui.Image? _bg;
  ui.Image? _leaves;
  ui.Image? _plants;

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  static Future<(ui.FragmentProgram, ui.Image, ui.Image, ui.Image)>
  _load() async => (
    await ui.FragmentProgram.fromAsset('shaders/wudhu_bg.frag'),
    await _decode('$_kA/s2-bg_clean.png'),
    await _decode('$_kA/s2-bg_leaves.png'),
    await _decode('$_kA/s2-bg_plants.png'),
  );

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (e) => _time.value = e.inMicroseconds / Duration.microsecondsPerSecond,
    );
    (_assets ??= _load())
        .then((a) {
          if (!mounted) return;
          setState(() {
            _shader = a.$1.fragmentShader();
            _bg = a.$2;
            _leaves = a.$3;
            _plants = a.$4;
          });
          _ticker.start();
        })
        .catchError((Object _) {
          // Shaders unsupported here: the static art stays.
          _assets = null;
        });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) {
      return Image.asset('$_kA/s2-bg.png', fit: BoxFit.cover);
    }
    return CustomPaint(
      painter: _WashroomPainter(shader, _bg!, _leaves!, _plants!, _time),
      size: Size.infinite,
    );
  }
}

class _WashroomPainter extends CustomPainter {
  _WashroomPainter(this.shader, this.bg, this.leaves, this.plants, this.time)
    : super(repaint: time);
  final ui.FragmentShader shader;
  final ui.Image bg;
  final ui.Image leaves;
  final ui.Image plants;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, bg.width.toDouble())
      ..setFloat(3, bg.height.toDouble())
      ..setFloat(4, time.value)
      ..setImageSampler(0, bg)
      ..setImageSampler(1, leaves)
      ..setImageSampler(2, plants);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_WashroomPainter old) =>
      old.shader != shader || old.bg != bg;
}

/// The three streams in s2-bg.png, in its 853x1844 px: left and right edge
/// of the water where it leaves the spout, spout y, and where it lands.
const _kTaps = [
  (666.5, 677.5, 768.0, 847.0),
  (724.0, 735.0, 772.0, 870.0),
  (801.5, 813.5, 783.0, 897.0),
];

/// Running tap water: a rippling translucent stream with highlights racing
/// down it, rings spreading where it lands, splashing droplets and a bit of
/// foam. [t] loops 0..1 every 2.4s.
class _TapWater extends CustomPainter {
  const _TapWater(this.t, this.sc, this.origin);
  final double t;
  final double sc;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(sc);
    for (final (i, (x0, x1, top, bottom)) in _kTaps.indexed) {
      _stream(canvas, i, x0, x1, top, bottom);
    }
    canvas.restore();
  }

  void _stream(Canvas c, int i, double x0, double x1, double top, double bot) {
    final cx = (x0 + x1) / 2;
    final w = x1 - x0;
    final seed = i * .37;
    final tau = 2 * math.pi;

    // Body: slightly narrowing column whose edges ripple as it falls.
    final body = Path();
    const steps = 18;
    for (var k = 0; k <= steps; k++) {
      final y = top + (bot - top) * k / steps;
      final half = w / 2 * (1 - .18 * k / steps);
      final wob = math.sin(y * .22 - t * tau * 6 + seed * 10) * .9;
      k == 0
          ? body.moveTo(cx - half + wob, y)
          : body.lineTo(cx - half + wob, y);
    }
    for (var k = steps; k >= 0; k--) {
      final y = top + (bot - top) * k / steps;
      final half = w / 2 * (1 - .18 * k / steps);
      final wob = math.sin(y * .22 - t * tau * 6 + seed * 10 + 1.3) * .9;
      body.lineTo(cx + half + wob, y);
    }
    body.close();
    c.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x0, 0),
          Offset(x1, 0),
          [
            _rgba(150, 215, 255, .55),
            _rgba(235, 250, 255, .75),
            _rgba(120, 195, 250, .55),
          ],
          const [0, .45, 1],
        ),
    );

    // Highlights racing down the stream.
    for (var k = 0; k < 5; k++) {
      final ph = (t * 3.2 + k / 5 + seed) % 1;
      final y = top + ph * (bot - top);
      final len = 9 + 5 * math.sin(k * 2.1);
      final a = math.sin(ph * math.pi);
      final x = cx + (k.isEven ? -1.4 : 1.2);
      c.drawLine(
        Offset(x, y),
        Offset(x, math.min(bot, y + len)),
        Paint()
          ..color = _rgba(255, 255, 255, .85 * a)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    // Foam where it lands.
    final flick = .8 + .2 * math.sin(t * tau * 8 + seed * 7);
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, bot), width: 16 * flick, height: 5),
      Paint()
        ..color = _rgba(255, 255, 255, .7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Rings spreading across the basin water.
    for (var k = 0; k < 3; k++) {
      final ph = (t * 1.8 + k / 3 + seed) % 1;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(cx, bot + 1),
          width: 10 + 30 * ph,
          height: 3 + 7 * ph,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _rgba(255, 255, 255, .7 * (1 - ph)),
      );
    }

    // Droplets thrown up and falling back.
    for (var k = 0; k < 6; k++) {
      final ph = (t * 2.6 + k / 6 + seed * 1.7) % 1;
      final side = k.isEven ? 1.0 : -1.0;
      final spread = 5 + 4 * ((k * 7 + i * 3) % 5);
      final pos = Offset(
        cx + side * spread * ph,
        bot - 2 - 14 * ph + 26 * ph * ph,
      );
      c.drawCircle(
        pos,
        1.3 + .5 * (1 - ph),
        Paint()..color = _rgba(225, 245, 255, .9 * (1 - ph)),
      );
    }
  }

  @override
  bool shouldRepaint(_TapWater old) =>
      old.t != t || old.sc != sc || old.origin != origin;
}

/// A lantern cut out of s2_start_bg.png: its box in the art's 853x1844 px
/// and the top of its chain, which it swings from.
class _Lantern2 {
  const _Lantern2(this.asset, this.box, this.pivot, this.phase);
  final String asset;
  final Rect box;
  final Offset pivot;
  final double phase;
}

const _kHallLanterns = [
  _Lantern2(
    '$_kA/s2_lantern_l.png',
    Rect.fromLTWH(19, 0, 112, 285),
    Offset(76, 0),
    0,
  ),
  _Lantern2(
    '$_kA/s2_lantern_r.png',
    Rect.fromLTWH(722, 0, 112, 284),
    Offset(777, 0),
    2.2,
  ),
];

/// Session 2's start hallway (laid out like BoxFit.cover) with its two
/// lanterns swinging from their chains: a pendulum sway whose size drifts
/// with slow draughts, each lantern on its own beat, and a warm glow that
/// flickers with the flame and travels with the lantern.
class _LanternHall extends StatelessWidget {
  const _LanternHall();

  static const _art = Size(853, 1844);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final sc = math.max(
        box.maxWidth / _art.width,
        box.maxHeight / _art.height,
      );
      final dx = (box.maxWidth - _art.width * sc) / 2;
      final dy = (box.maxHeight - _art.height * sc) / 2;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('$_kA/s2_start_bg_clean.png', fit: BoxFit.cover),
          _Loop(
            period: const Duration(seconds: 24),
            builder: (t, _) {
              final sec = t * 24;
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (final l in _kHallLanterns) _lantern(l, sec, sc, dx, dy),
                ],
              );
            },
          ),
        ],
      );
    },
  );

  Widget _lantern(_Lantern2 l, double sec, double sc, double dx, double dy) {
    const tau = 2 * math.pi;
    // Pendulum (3s period, all rates divide the 24s loop) with a slow draught swelling and easing the
    // swing, plus a faint second harmonic so it never looks mechanical.
    final draught = .75 + .25 * math.sin(tau * sec / 12 + l.phase);
    final deg =
        draught *
        (4.2 * math.sin(tau * sec / 3.0 + l.phase) +
            .6 * math.sin(tau * sec / 1.5 + l.phase * 1.7));
    final flicker =
        .82 +
        .1 * math.sin(tau * sec * 1.75 + l.phase) +
        .08 * math.sin(tau * sec * 4.25 + l.phase * 2.3);
    final b = l.box;
    final pivot = Alignment(
      (l.pivot.dx - b.left) / b.width * 2 - 1,
      (l.pivot.dy - b.top) / b.height * 2 - 1,
    );
    return Positioned(
      left: dx + b.left * sc,
      top: dy + b.top * sc,
      width: b.width * sc,
      height: b.height * sc,
      child: Transform.rotate(
        angle: deg * math.pi / 180,
        alignment: pivot,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Warm light spilling from the glass, moving with the lantern.
            Positioned(
              left: -b.width * .55 * sc,
              top: b.height * .22 * sc,
              right: -b.width * .55 * sc,
              height: b.height * .72 * sc,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _rgba(255, 196, 90, .30 * flicker),
                        _rgba(255, 170, 60, 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: Image.asset(l.asset, fit: BoxFit.fill)),
          ],
        ),
      ),
    );
  }
}

/// Golden glowing ring around the body part to tap: a soft halo that
/// breathes, a bright gold rim, and a faint ring spreading outwards.
class _GlowRing extends CustomPainter {
  const _GlowRing(this.radius, this.t);
  final double? radius;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final breathe = .5 + .5 * math.sin(t * 2 * math.pi);
    canvas.drawPath(
      _shapePath(r, radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = _rgba(255, 214, 80, .35 + .3 * breathe)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      _shapePath(r.deflate(1.5), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFE27A),
    );
    final e = Curves.easeOut.transform(t);
    final grow = 10 * e;
    canvas.drawPath(
      _shapePath(r.inflate(grow), radius == null ? null : radius! + grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _rgba(255, 226, 122, .6 * (1 - e)),
    );
  }

  @override
  bool shouldRepaint(_GlowRing old) => old.t != t || old.radius != radius;
}

/// A dropped card in flight (see _flightView).
class _Flight {
  const _Flight(this.n, this.id, this.from, this.bin, {required this.accepted});
  final int n;
  final String id;
  final Offset from;
  final String bin;
  final bool accepted;
}

/// Puff out of a bin's mouth as a card lands: four-point sparkles for the
/// clean bin, dirt specks for the dirty one. Thrown up, pulled down, fading.
class _BurstPainter extends CustomPainter {
  const _BurstPainter(
    this.t,
    this.origin, {
    required this.clean,
    required this.seed,
  });

  final double t;
  final Offset origin;
  final bool clean;
  final int seed;

  static const _sparkle = [
    Color(0xFFFFFFFF),
    Color(0xFFFFE27A),
    Color(0xFF9FE3FF),
    Color(0xFF7DE38F),
  ];
  static const _dirt = [
    Color(0xFF6B3F1D),
    Color(0xFF8E5A2B),
    Color(0xFFA9885F),
    Color(0xFF5A4636),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rnd = math.Random(seed);
    final fade = 1 - Curves.easeIn.transform(t);
    for (var i = 0; i < 16; i++) {
      final ang = -math.pi * (.12 + .76 * rnd.nextDouble());
      final speed = 260 + 260 * rnd.nextDouble();
      final r = (clean ? 10 : 7) + rnd.nextDouble() * 10;
      final jitter = (rnd.nextDouble() - .5) * 60;
      final p =
          origin +
          Offset(
            math.cos(ang) * speed * t + jitter,
            math.sin(ang) * speed * t + 520 * t * t,
          );
      final paint = Paint()
        ..color = (clean ? _sparkle : _dirt)[i % 4].withValues(alpha: fade);
      if (clean) {
        final q = r * (1 - .4 * t);
        final path = Path()
          ..moveTo(p.dx, p.dy - q)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + q, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + q)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - q, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - q)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: p, width: r * 1.3, height: r),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// 4s lead-in to the sorting game: the washroom dims, "Get Ready!" rises,
/// then 3, 2, 1 and Go! punch in one after another before it all clears.
class _GetReady extends StatelessWidget {
  const _GetReady({super.key, this.bg = '$_kA/s1_start_bg.png'});

  /// Room shown dimmed behind the countdown.
  final String bg;

  static const _beats = [
    ('3', 700.0, 1600.0, Color(0xFFFFC21A)),
    ('2', 1600.0, 2500.0, Color(0xFF46BF62)),
    ('1', 2500.0, 3300.0, Color(0xFF3DA0F5)),
    ('Go!', 3300.0, 3950.0, Color(0xFFFF7A59)),
  ];

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    child: _Once(
      duration: const Duration(milliseconds: 4000),
      builder: (t, _) {
        final ms = t * 4000;
        final fade = ms < 450
            ? Curves.easeOut.transform(ms / 450)
            : ms > 3500
            ? 1 - Curves.easeIn.transform((ms - 3500) / 500)
            : 1.0;
        final title = Curves.easeOutBack.transform(
          ((ms - 250) / 500).clamp(0.0, 1.0),
        );
        Widget? beat;
        for (final (text, from, to, color) in _beats) {
          if (ms < from || ms >= to) continue;
          final u = (ms - from) / (to - from);
          final grow = Curves.easeOutBack.transform((u / .3).clamp(0.0, 1.0));
          final out = ((u - .75) / .25).clamp(0.0, 1.0);
          beat = Opacity(
            opacity: 1 - out,
            child: Transform.scale(
              scale: (.3 + .7 * grow) * (1 + .2 * out),
              child: _outlined(
                text,
                _baloo(text == 'Go!' ? 150 : 200, color, height: 1),
                const Color(0xFF0E2A4F),
                22,
              ),
            ),
          );
        }
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bg, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [_rgba(23, 50, 79, .72), _rgba(8, 18, 32, .9)],
                  ),
                ),
              ),
              _stage(
                Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 190,
                      child: Opacity(
                        opacity: title.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - title)),
                          child: Center(
                            child: _outlined(
                              'Get Ready!',
                              _baloo(46, Colors.white),
                              const Color(0xFF0E2A4F),
                              10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 290,
                      height: 300,
                      child: Center(child: beat ?? const SizedBox.shrink()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// One-shot confetti shower over the ending screen.
class _Confetti extends StatelessWidget {
  const _Confetti();

  @override
  Widget build(BuildContext context) => _Once(
    duration: const Duration(milliseconds: 3800),
    delay: const Duration(milliseconds: 300),
    builder: (t, _) =>
        CustomPaint(painter: _ConfettiPainter(t), size: Size.infinite),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.t);
  final double t;

  static const _colors = [
    Color(0xFFFFC21A),
    Color(0xFF46BF62),
    Color(0xFF3DA0F5),
    Color(0xFFFF7A59),
    Color(0xFFFF5FA2),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rnd = math.Random(7);
    for (var i = 0; i < 70; i++) {
      final x = rnd.nextDouble() * size.width;
      final delay = rnd.nextDouble() * .35;
      final speed = .75 + rnd.nextDouble() * .5;
      final phase = rnd.nextDouble() * math.pi * 2;
      final w = 6 + rnd.nextDouble() * 7;
      final color = _colors[i % _colors.length];
      final u = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (u <= 0) continue;
      final y = -30 + u * speed * (size.height + 60);
      final dx = math.sin(u * 7 + phase) * 22;
      final fade = u > .8 ? (1 - u) / .2 : 1.0;
      canvas.save();
      canvas.translate(x + dx, y);
      canvas.rotate(u * 9 + phase);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * .55),
        Paint()..color = color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// "Mumtaz!" on the blank How to Play plank (1396x452).
Widget _endSign() => FittedBox(
  child: SizedBox(
    width: 1396,
    height: 452,
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset('$_kA/how_title.png', fit: BoxFit.fill),
        ),
        Positioned(
          left: 250,
          right: 230,
          top: 100,
          bottom: 90,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _outlined(
                'Mumtaz!',
                _baloo(210, const Color(0xFFFFE31A), height: 1),
                const Color(0xFF5A1E08),
                28,
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);

/// The painted gold star; a missed star is the same art, greyed and faint.
Widget _endStar(bool earned) {
  final star = Image.asset('$_kA/end_star.png', fit: BoxFit.contain);
  if (earned) return star;
  return Opacity(
    opacity: .55,
    child: ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        .33, .5, .17, 0, 20, //
        .33, .5, .17, 0, 12, //
        .33, .5, .17, 0, 0, //
        0, 0, 0, 1, 0,
      ]),
      child: star,
    ),
  );
}

/// Game-style text with a solid outline behind the fill.
Widget _outlined(String text, TextStyle style, Color stroke, double width) {
  final outline = TextStyle(
    fontFamily: style.fontFamily,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontVariations: style.fontVariations,
    height: style.height,
    letterSpacing: style.letterSpacing,
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..color = stroke,
  );
  return Stack(
    children: [
      Text(text, style: outline),
      Text(text, style: style),
    ],
  );
}

/// Painted image button that swaps to its pressed art while held.
class _ImgBtn extends StatefulWidget {
  const _ImgBtn({
    super.key,
    required this.up,
    required this.down,
    required this.onTap,
    this.child,
  });

  final String up;
  final String down;
  final VoidCallback onTap;
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
      scale: _down ? .97 : 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_down ? widget.down : widget.up, fit: BoxFit.fill),
          ?widget.child,
        ],
      ),
    ),
  );
}

void _precache(BuildContext context, Iterable<String> assets) {
  for (final a in assets) {
    precacheImage(AssetImage(a), context);
  }
}

// ---------------------------------------------------------------------------
// Session 1 — Clean or Dirty?
// ---------------------------------------------------------------------------

class _SortCard {
  const _SortCard(this.id, this.label, this.isClean, this.msg);
  final String id;
  final String label;
  final bool isClean;
  final String msg;
  String get img => '$_kA/$id.png';
}

const List<_SortCard> _kCards = [
  _SortCard(
    'wash_hands',
    'Wash Hands',
    true,
    'Mumtaz! Washing hands is clean.',
  ),
  _SortCard(
    'brush_teeth',
    'Brush Teeth',
    true,
    'Mumtaz! Brushing teeth keeps us clean.',
  ),
  _SortCard(
    'dirty_clothes',
    'Dirty Clothes',
    false,
    'Mumtaz! Dirty clothes go in Dirty / Trash.',
  ),
  _SortCard(
    'throw_trash',
    'Throw Trash',
    true,
    'Mumtaz! Throwing trash away is clean.',
  ),
  _SortCard(
    'muddy_shoes',
    'Muddy Shoes',
    false,
    'Mumtaz! Muddy shoes belong in Dirty / Trash.',
  ),
  _SortCard(
    'cut_nails',
    'Cut Nails',
    true,
    'Mumtaz! Cutting nails keeps us clean.',
  ),
];

/// Main game stage: the game reference's 887x1774 frame.
const double _kGW = 887;
const double _kGH = 1774;

/// Game-stage px per prototype px, for widgets sized for the 390 frame.
const double _kGK = _kGW / _kW;

/// Card tray at its art's own 1256x1060 aspect, and its six slot frames
/// (in tray-art px).
const Rect _kTrayRect = Rect.fromLTWH(48.5, 390, 790, 790 * 1060 / 1256);
const double _kTrayK = 790 / 1256;
const List<Offset> _kSlotOrigins = [
  Offset(72, 163),
  Offset(448, 163),
  Offset(822, 163),
  Offset(72, 578),
  Offset(448, 578),
  Offset(822, 578),
];
const double _kSlotW = 362 * _kTrayK;
const double _kSlotH = 385 * _kTrayK;

Rect _slotRect(int i) => Rect.fromLTWH(
  _kTrayRect.left + _kSlotOrigins[i].dx * _kTrayK,
  _kTrayRect.top + _kSlotOrigins[i].dy * _kTrayK,
  _kSlotW,
  _kSlotH,
);

/// The painted buckets' rects on the game stage.
const Rect _kCleanBin = Rect.fromLTWH(50, 1330, 380, 357);
const Rect _kDirtyBin = Rect.fromLTWH(457, 1330, 380, 357);

enum _S1 { start, instruction, game, done }

class _CleanOrDirty extends StatefulWidget {
  const _CleanOrDirty({
    required this.xp,
    required this.onComplete,
    this.onEnding,
    this.onExit,
  });

  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Fired when the game's own ending screen appears (the lesson player's
  /// cue for its congratulations sound).
  final VoidCallback? onEnding;
  final VoidCallback? onExit;

  @override
  State<_CleanOrDirty> createState() => _CleanOrDirtyState();
}

class _CleanOrDirtyState extends State<_CleanOrDirty> {
  _S1 _screen = _S1.start;
  final TaharahWudhuAudio _audio = TaharahWudhuAudio();
  bool _sound = true;

  @override
  void initState() {
    super.initState();
    _audio.start();
  }

  void _toggleSound() {
    setState(() => _sound = !_sound);
    _audio.setEnabled(_sound);
  }

  /// Card id → true when sorted into the clean bin.
  final Map<String, bool> _sorted = {};

  String? _dragId;
  int? _dragPointer;
  Offset _dragFrom = Offset.zero;
  Offset _dragAt = Offset.zero;
  bool _moved = false;

  /// 'clean' / 'dirty' while a card hovers over a bin.
  String? _hover;

  _Toast? _toast;
  int _toastN = 0;
  String? _wrong;
  final Map<String, int> _shakes = {};
  int _errors = 0;
  Timer? _toastT, _doneT, _wrongT;

  /// The 4s "Get Ready!" countdown into the game (Let's Play, Play Again).
  bool _getReady = false;
  int _readyN = 0;
  Timer? _readyT, _readyEndT;

  void _startGame() {
    if (_getReady) return;
    setState(() {
      _getReady = true;
      _readyN++;
    });
    // The game swaps in under the countdown just before it clears, so the
    // cards' pop-in plays as the overlay fades.
    _readyT = Timer(const Duration(milliseconds: 3450), () {
      if (mounted) _newGame();
    });
    _readyEndT = Timer(const Duration(milliseconds: 4000), () {
      if (mounted) setState(() => _getReady = false);
    });
  }

  /// Cards in the air after a drop (into a bin, or back to their slot),
  /// the card hidden in its slot while it flies home, bin reactions and
  /// the puffs out of a bin's mouth.
  final List<_Flight> _flights = [];
  int _fxN = 0;
  String? _returning;
  final Map<String, int> _binHits = {'clean': 0, 'dirty': 0};
  final Map<String, int> _binNos = {'clean': 0, 'dirty': 0};
  final List<(String, int)> _bursts = [];
  final List<Timer> _fxTimers = [];

  final _stageKey = GlobalKey();

  void _after(int ms, VoidCallback fn) => _fxTimers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(fn);
    }),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache(context, [
      for (final n in [
        's1_start_bg',
        's1_logo',
        's1_caption',
        's1_badge',
        's1_girl',
        's1_boy',
        's1_play',
        's1_play_down',
        's1_back',
        's1_back_down',
        's1_tile_soap',
        's1_tile_check',
        's1_tile_star',
        'how_title',
        'how_drop',
        'how_panel',
        'game_tray',
        'game_meter',
        'game_hint',
        'game_word_clean',
        'game_word_dirty',
        'end_star',
        'end_again',
        'end_again_down',
        'end_continue',
        'end_continue_down',
        'end_girl_cheer',
        'end_boy_cheer',
        'end_girl_thumbs',
        'end_boy_thumbs',
      ])
        '$_kA/$n.png',
      '$_kA/bg.png',
      '$_kA/bin-clean.png',
      '$_kA/bin-dirty.png',
      for (final c in _kCards) c.img,
    ]);
  }

  @override
  void dispose() {
    _audio.dispose();
    _toastT?.cancel();
    _doneT?.cancel();
    _wrongT?.cancel();
    _readyT?.cancel();
    _readyEndT?.cancel();
    for (final t in _fxTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _go(_S1 s) => setState(() => _screen = s);

  void _newGame() {
    _doneT?.cancel();
    for (final t in _fxTimers) {
      t.cancel();
    }
    _fxTimers.clear();
    setState(() {
      _screen = _S1.game;
      _sorted.clear();
      _shakes.clear();
      _flights.clear();
      _bursts.clear();
      _returning = null;
      _toast = null;
      _errors = 0;
    });
  }

  void _finish() {
    final n = _kCards.length;
    widget.onComplete(widget.xp, n / (n + _errors) * 100.0, _errors);
  }

  Offset _toStage(Offset global) =>
      (_stageKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(
        global,
      );

  String? _binAt(Offset p) {
    bool hit(Rect r) =>
        Rect.fromLTRB(r.left, r.top - 70, r.right, r.bottom).contains(p);
    if (hit(_kCleanBin)) return 'clean';
    if (hit(_kDirtyBin)) return 'dirty';
    return null;
  }

  void _startDrag(_SortCard c, PointerDownEvent e) {
    if (_sorted.containsKey(c.id) || _dragId != null) return;
    final p = _toStage(e.position);
    setState(() {
      _dragId = c.id;
      _dragPointer = e.pointer;
      _dragFrom = p;
      _dragAt = p;
      _moved = false;
      _toast = null;
      _wrong = null;
    });
  }

  void _onMove(PointerMoveEvent e) {
    if (_dragId == null || e.pointer != _dragPointer) return;
    final p = _toStage(e.position);
    setState(() {
      _moved =
          _moved ||
          (p.dx - _dragFrom.dx).abs() > 10 ||
          (p.dy - _dragFrom.dy).abs() > 10;
      _dragAt = p;
      _hover = _moved ? _binAt(p) : null;
    });
  }

  void _onUp(PointerEvent e) {
    final id = _dragId;
    if (id == null || e.pointer != _dragPointer) return;
    final at = _toStage(e.position);
    final bin = _moved ? _binAt(at) : null;
    final moved = _moved;
    setState(() {
      _dragId = null;
      _dragPointer = null;
      _hover = null;
    });
    final card = _kCards.firstWhere((c) => c.id == id);
    if (bin != null) {
      _resolve(card, bin == 'clean', at);
    } else if (!moved) {
      _flash(_Toast(card.label, '♪', good: true));
    }
  }

  void _flash(_Toast t) {
    setState(() {
      _toast = t;
      _toastN++;
    });
    _toastT?.cancel();
    _toastT = Timer(
      const Duration(milliseconds: 2200),
      () => setState(() => _toast = null),
    );
  }

  void _resolve(_SortCard card, bool clean, Offset at) {
    final bin = clean ? 'clean' : 'dirty';
    final n = ++_fxN;
    if (clean == card.isClean) {
      // Arc over the bin, drop in behind the rim; the bin squashes as it
      // lands and puffs out sparkles (clean) or dirt (dirty).
      setState(() {
        _sorted[card.id] = clean;
        _flights.add(_Flight(n, card.id, at, bin, accepted: true));
      });
      _after(460, () {
        _binHits[bin] = _binHits[bin]! + 1;
        _bursts.add((bin, n));
      });
      _after(760, () => _flights.removeWhere((f) => f.n == n));
      _after(1300, () => _bursts.removeWhere((b) => b.$2 == n));
      _flash(_Toast(card.msg, '★', good: true));
      if (_sorted.length == _kCards.length) {
        _doneT?.cancel();
        _doneT = Timer(const Duration(milliseconds: 1500), () {
          setState(() {
            _screen = _S1.done;
            _toast = null;
          });
          widget.onEnding?.call();
        });
      }
    } else {
      final where = card.isClean ? 'Sparkling Clean' : 'Dirty / Trash';
      // The bin shakes "no" and the card springs back to its slot, then
      // wobbles there.
      setState(() {
        _errors++;
        _returning = card.id;
        _binNos[bin] = _binNos[bin]! + 1;
        _flights.add(_Flight(n, card.id, at, bin, accepted: false));
      });
      _after(480, () {
        _flights.removeWhere((f) => f.n == n);
        if (_returning == card.id) _returning = null;
        _wrong = card.id;
        _shakes[card.id] = (_shakes[card.id] ?? 0) + 1;
      });
      _flash(
        _Toast(
          'Oops! ${card.label} go in $where. Try again!',
          '😕',
          good: false,
        ),
      );
      _wrongT?.cancel();
      _wrongT = Timer(
        const Duration(milliseconds: 1080),
        () => setState(() => _wrong = null),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFEFE3CB),
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Screens cross-fade: the old one eases forward and fades out while the
        // new one settles in from a touch smaller.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 550),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          transitionBuilder: (child, anim) {
            final incoming = child.key == ValueKey(_screen);
            return IgnorePointer(
              ignoring: !incoming,
              child: FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(
                    begin: incoming ? .97 : 1.06,
                    end: 1.0,
                  ).animate(anim),
                  child: child,
                ),
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_screen),
            child: switch (_screen) {
              _S1.start => _buildStart(),
              _S1.instruction => _buildInstruction(),
              _S1.game => _buildGame(),
              _S1.done => _buildDone(),
            },
          ),
        ),
        if (_getReady) _GetReady(key: ValueKey('ready$_readyN')),
      ],
    ),
  );

  // ---- start ----

  /// Laid out in the reference comp's 851x1847 pixel space over the painted
  /// washroom, and scaled to fit inside the safe area.
  Widget _buildStart() {
    Widget at(double l, double t, double w, double h, Widget c) =>
        Positioned(left: l, top: t, width: w, height: h, child: c);
    Widget img(String name) => Image.asset('$_kA/$name.png', fit: BoxFit.fill);
    const brown = Color(0xFF3B1A0E);

    Widget tile(double left, String art, String label, int i) => at(
      left,
      1455,
      247,
      253,
      _rise(
        const Duration(milliseconds: 450),
        delay: Duration(milliseconds: 650 + 110 * i),
        Stack(
          fit: StackFit.expand,
          children: [
            img(art),
            Positioned(
              left: 14,
              right: 14,
              top: 150,
              bottom: 30,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _baloo(33, brown, height: 1.15),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/s1_start_bg.png', fit: BoxFit.cover),
        SafeArea(
          child: SizedBox.expand(
            child: FittedBox(
              child: SizedBox(
                width: 851,
                height: 1847,
                child: Stack(
                  children: [
                    at(328, 726, 496, 736, img('s1_boy')),
                    at(44, 737, 466, 721, img('s1_girl')),
                    at(
                      140,
                      136,
                      588,
                      464,
                      _pop(const Duration(milliseconds: 600), img('s1_logo')),
                    ),
                    at(
                      195,
                      594,
                      477,
                      109,
                      _rise(
                        const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 400),
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            img('s1_caption'),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(76, 0, 72, 6),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _outlined(
                                    'Clean or Dirty?',
                                    _baloo(46, const Color(0xFFFFF6E3)),
                                    const Color(0xFF4A2308),
                                    8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    at(
                      80,
                      1130,
                      690,
                      258,
                      _pop(
                        const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 500),
                        _Loop(
                          period: const Duration(milliseconds: 1800),
                          builder: (t, c) => Transform.scale(
                            scale: 1 + .025 * math.sin(t * 2 * math.pi),
                            child: c,
                          ),
                          child: _ImgBtn(
                            key: const ValueKey('ta-start'),
                            up: '$_kA/s1_play.png',
                            down: '$_kA/s1_play_down.png',
                            onTap: () => _go(_S1.instruction),
                            child: Align(
                              alignment: const Alignment(0, .52),
                              child: SizedBox(
                                width: 480,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _outlined(
                                    'Start Adventure',
                                    _baloo(64, Colors.white),
                                    const Color(0xFF0E5A14),
                                    10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    tile(38, 's1_tile_soap', 'Sort the items', 0),
                    tile(302, 's1_tile_check', 'Learn good\nhygiene habits', 1),
                    tile(565, 's1_tile_star', 'Be a Taharah\nHero!', 2),
                    if (widget.onExit != null)
                      at(
                        23,
                        35,
                        112,
                        88,
                        _ImgBtn(
                          up: '$_kA/s1_back.png',
                          down: '$_kA/s1_back_down.png',
                          onTap: widget.onExit!,
                        ),
                      ),
                    at(
                      513,
                      36,
                      320,
                      104,
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          img('s1_badge'),
                          Positioned(
                            left: 112,
                            right: 12,
                            top: 8,
                            bottom: 10,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Session 1',
                                    style: _baloo(31, brown, height: 1.05),
                                  ),
                                  Text(
                                    'Hygiene Basics',
                                    style: _baloo(
                                      25,
                                      brown,
                                      weight: 700,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

  // ---- how to play ----

  /// Same 851x1847 reference space and washroom as the start screen, so the
  /// cross-fade reads as one scene: the room dims, the sign drops in, the
  /// board settles and its three steps rise in turn.
  Widget _buildInstruction() {
    Widget at(double l, double t, double w, double h, Widget c) =>
        Positioned(left: l, top: t, width: w, height: h, child: c);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/s1_start_bg.png', fit: BoxFit.cover),
        _Once(
          duration: const Duration(milliseconds: 500),
          builder: (t, _) => ColoredBox(color: _rgba(20, 30, 45, .28 * t)),
        ),
        SafeArea(
          child: SizedBox.expand(
            child: FittedBox(
              child: SizedBox(
                width: 851,
                height: 1847,
                child: Stack(
                  children: [
                    at(
                      75,
                      105,
                      700,
                      226.6,
                      _Once(
                        duration: const Duration(milliseconds: 650),
                        delay: const Duration(milliseconds: 150),
                        child: _howTitle(),
                        builder: (t, c) => Opacity(
                          opacity: Curves.easeOut.transform(
                            (t * 2).clamp(0.0, 1.0),
                          ),
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              -90 * (1 - Curves.easeOutBack.transform(t)),
                            ),
                            child: c,
                          ),
                        ),
                      ),
                    ),
                    at(
                      35.5,
                      330,
                      780,
                      1130.6,
                      _Once(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 280),
                        child: FittedBox(child: _howPanel()),
                        builder: (t, c) {
                          final e = Curves.easeOutCubic.transform(t);
                          return Opacity(
                            opacity: e,
                            child: Transform.translate(
                              offset: Offset(0, 50 * (1 - e)),
                              child: Transform.scale(
                                scale: .92 + .08 * e,
                                child: c,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    at(
                      125.5,
                      1515,
                      600,
                      224,
                      _Once(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 5000),
                        builder: (t, c) => IgnorePointer(
                          ignoring: t == 0,
                          child: Opacity(
                            opacity: Curves.ease.transform(t),
                            child: Transform.scale(
                              scale: _kf(t, [0, .6, 1], [.6, 1.08, 1]),
                              child: c,
                            ),
                          ),
                        ),
                        child: _Loop(
                          period: const Duration(milliseconds: 1800),
                          builder: (t, c) => Transform.scale(
                            scale: 1 + .025 * math.sin(t * 2 * math.pi),
                            child: c,
                          ),
                          child: _ImgBtn(
                            key: const ValueKey('ta-howto-play'),
                            up: '$_kA/s1_play.png',
                            down: '$_kA/s1_play_down.png',
                            onTap: _startGame,
                            child: Align(
                              alignment: const Alignment(0, .52),
                              child: SizedBox(
                                width: 420,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _outlined(
                                    "Let's Play!",
                                    _baloo(60, Colors.white),
                                    const Color(0xFF0E5A14),
                                    10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    at(
                      23,
                      35,
                      112,
                      88,
                      _ImgBtn(
                        up: '$_kA/s1_back.png',
                        down: '$_kA/s1_back_down.png',
                        onTap: () => _go(_S1.start),
                      ),
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

  /// The "How to Play" sign: blank plank (1396x452), live lettering and the
  /// two water drops lifted from the reference.
  Widget _howTitle() => FittedBox(
    child: SizedBox(
      width: 1396,
      height: 452,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_kA/how_title.png', fit: BoxFit.fill),
          ),
          Positioned(
            left: 175,
            top: 243,
            width: 99,
            height: 113,
            child: Image.asset('$_kA/how_drop.png'),
          ),
          Positioned(
            left: 1128,
            top: 246,
            width: 99,
            height: 113,
            child: Image.asset('$_kA/how_drop.png'),
          ),
          Positioned(
            left: 250,
            right: 230,
            top: 100,
            bottom: 90,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _outlined(
                      'How to ',
                      _baloo(200, Colors.white, height: 1),
                      const Color(0xFF5A1E08),
                      26,
                    ),
                    _outlined(
                      'Play',
                      _baloo(200, const Color(0xFFFFE31A), height: 1),
                      const Color(0xFF5A1E08),
                      26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// The leafy board with its three step cards, in the reference board's own
  /// 939x1361 space. Illustrations are cut from the reference; boxes, badges
  /// and wording are live.
  Widget _howPanel() {
    const ink = Color(0xFF4A1405);
    const blue = Color(0xFF1D6FE8);
    Widget at(double l, double t, double w, double h, Widget c) =>
        Positioned(left: l, top: t, width: w, height: h, child: c);

    Widget box(List<Color> fill, Color border, {double r = 34}) => Container(
      decoration: BoxDecoration(
        gradient: _vGrad(fill),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border, width: 5),
      ),
    );

    Widget inner(List<Color> fill) => Container(
      decoration: BoxDecoration(
        gradient: _vGrad(fill),
        borderRadius: BorderRadius.circular(26),
      ),
    );

    Widget badge(int n) => Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _vGrad(const [Color(0xFFFFE45C), Color(0xFFF7B500)]),
        border: Border.all(color: const Color(0xFF8A3A00), width: 5),
        boxShadow: [
          BoxShadow(
            color: _rgba(120, 60, 0, .35),
            offset: const Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text('$n', style: _baloo(66, ink, height: 1)),
    );

    Widget words(List<List<(String, bool)>> lines, List<double> sizes) =>
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < lines.length; i++)
                Text.rich(
                  TextSpan(
                    children: [
                      for (final (s, hi) in lines[i])
                        TextSpan(
                          text: s,
                          style: _baloo(sizes[i], hi ? blue : ink, height: 1.1),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );

    /// Each step card rises in after the board has landed.
    Widget step(int i, Widget child) => _rise(
      const Duration(milliseconds: 450),
      delay: Duration(milliseconds: 620 + 140 * i),
      child,
    );

    return SizedBox(
      width: 939,
      height: 1361,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_kA/how_panel.png', fit: BoxFit.fill),
          ),
          Positioned.fill(
            child: step(
              0,
              Stack(
                children: [
                  at(
                    131,
                    139,
                    685,
                    300,
                    box(const [
                      Color(0xFFD9F4FE),
                      Color(0xFFB3E9FC),
                    ], const Color(0xFF37B6F0)),
                  ),
                  _art('wash_hands', const Rect.fromLTWH(158, 245, 150, 170)),
                  _art(
                    'dirty_clothes',
                    const Rect.fromLTWH(318, 250, 150, 160),
                  ),
                  _art('brush_teeth', const Rect.fromLTWH(478, 245, 150, 170)),
                  _art('muddy_shoes', const Rect.fromLTWH(638, 265, 150, 140)),
                  at(127, 150, 104, 104, badge(1)),
                  at(
                    240,
                    150,
                    560,
                    72,
                    Center(
                      child: words(
                        [
                          [('Look at the ', false), ('item.', true)],
                        ],
                        [46],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: step(
              1,
              Stack(
                children: [
                  at(
                    129,
                    462,
                    687,
                    384,
                    box(const [
                      Color(0xFFFEF5D6),
                      Color(0xFFFDEFC5),
                    ], const Color(0xFFF8C22A)),
                  ),
                  at(
                    146,
                    594,
                    645,
                    240,
                    inner(const [Color(0xFFFDEAB0), Color(0xFFFCE09A)]),
                  ),
                  _art(
                    'dirty_clothes',
                    const Rect.fromLTWH(165, 650, 175, 150),
                  ),
                  _art('bin-clean', const Rect.fromLTWH(385, 648, 180, 170)),
                  _art('bin-dirty', const Rect.fromLTWH(595, 648, 180, 170)),
                  at(
                    146,
                    594,
                    645,
                    240,
                    const CustomPaint(painter: _DragArrow()),
                  ),
                  at(127, 464, 104, 104, badge(2)),
                  at(
                    240,
                    468,
                    560,
                    116,
                    Center(
                      child: words(
                        [
                          [('Drag the item to the', false)],
                          [('correct bin.', true)],
                        ],
                        [42, 42],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: step(
              2,
              Stack(
                children: [
                  at(
                    129,
                    869,
                    687,
                    370,
                    box(const [
                      Color(0xFFE6FCDD),
                      Color(0xFFD0F7C3),
                    ], const Color(0xFF6EE265)),
                  ),
                  at(
                    148,
                    989,
                    640,
                    240,
                    inner(const [Color(0xFFD3FCC7), Color(0xFFC4F5B4)]),
                  ),
                  at(
                    148,
                    989,
                    640,
                    240,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _art(
                            'brush_teeth',
                            const Rect.fromLTWH(70, 4, 80, 110),
                          ),
                          _art(
                            'wash_hands',
                            const Rect.fromLTWH(140, 14, 130, 100),
                          ),
                          _art(
                            'dirty_clothes',
                            const Rect.fromLTWH(360, 14, 120, 95),
                          ),
                          _art(
                            'muddy_shoes',
                            const Rect.fromLTWH(470, 28, 110, 80),
                          ),
                          _art(
                            'bin-clean',
                            const Rect.fromLTWH(40, 62, 240, 205),
                          ),
                          _art(
                            'bin-dirty',
                            const Rect.fromLTWH(340, 62, 240, 205),
                          ),
                          for (final (x, y, sz) in [
                            (6.0, 30.0, 44.0),
                            (290.0, 14.0, 38.0),
                            (596.0, 30.0, 44.0),
                          ])
                            Positioned(
                              left: x,
                              top: y,
                              child: _outlined(
                                '✦',
                                TextStyle(
                                  fontSize: sz,
                                  color: const Color(0xFFFFC21A),
                                  height: 1,
                                ),
                                const Color(0xFF9A5A00),
                                5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  at(127, 870, 104, 104, badge(3)),
                  at(
                    240,
                    872,
                    570,
                    116,
                    Center(
                      child: words(
                        [
                          [('Sort all the items', false)],
                          [
                            ('until they are all in the ', false),
                            ('right bin!', true),
                          ],
                        ],
                        [42, 36],
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
  }

  // ---- game ----

  /// Laid out in the game reference's 887x1774 space over the washroom:
  /// back/sound buttons, the Clean or Dirty? lettering, the Cleanliness
  /// Meter, the six-slot card tray, the hint pill and the two bins.
  Widget _buildGame() {
    final count = _sorted.length;
    final dragging = _dragId != null && _moved;
    final cleanN = _sorted.values.where((v) => v).length;
    final dirtyN = _sorted.values.where((v) => !v).length;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/s1_start_bg.png', fit: BoxFit.cover),
        SafeArea(
          child: SizedBox.expand(
            child: FittedBox(
              child: SizedBox(
                key: _stageKey,
                width: _kGW,
                height: _kGH,
                child: Listener(
                  onPointerMove: _onMove,
                  onPointerUp: _onUp,
                  onPointerCancel: _onUp,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 32,
                        top: 55,
                        width: 116,
                        height: 105,
                        child: _roundButton(
                          Icons.arrow_back_ios_new_rounded,
                          const Color(0xFF7A4A1E),
                          52,
                          () => _go(_S1.start),
                        ),
                      ),
                      Positioned(
                        left: 740,
                        top: 55,
                        width: 116,
                        height: 105,
                        child: _roundButton(
                          _sound
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          _blue,
                          62,
                          _toggleSound,
                        ),
                      ),
                      const Positioned(
                        left: 170,
                        top: 95,
                        width: 550,
                        height: 150,
                        child: _GameLogo(),
                      ),
                      Positioned(
                        left: 73.5,
                        top: 262,
                        width: 740,
                        height: 118,
                        child: _gameMeter(count),
                      ),
                      Positioned.fromRect(
                        rect: _kTrayRect,
                        child: Image.asset(
                          '$_kA/game_tray.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      for (var i = 0; i < _kCards.length; i++)
                        Positioned.fromRect(
                          rect: _slotRect(i),
                          child: _trayCard(_kCards[i]),
                        ),
                      if (_toast == null)
                        Positioned(
                          left: 143,
                          top: 1142,
                          width: 600,
                          height: 98.5,
                          child: IgnorePointer(child: _gameHint()),
                        )
                      else
                        Positioned(
                          left: (_kGW - 358 * _kGK) / 2,
                          top: 1126,
                          width: 358,
                          child: Transform.scale(
                            scale: _kGK,
                            alignment: Alignment.topLeft,
                            child: _toastCard(
                              _toast!,
                              key: ValueKey('toast$_toastN'),
                            ),
                          ),
                        ),
                      _bin(
                        'clean',
                        _kCleanBin,
                        '$_kA/bin-clean.png',
                        _rgba(70, 191, 98, .45),
                        cleanN,
                        _green,
                        _greenDeep,
                      ),
                      _bin(
                        'dirty',
                        _kDirtyBin,
                        '$_kA/bin-dirty.png',
                        _rgba(208, 68, 43, .4),
                        dirtyN,
                        _red,
                        _redInk,
                      ),
                      for (final b in _bursts)
                        Positioned.fill(
                          key: ValueKey('burst${b.$2}'),
                          child: IgnorePointer(
                            child: _Once(
                              duration: const Duration(milliseconds: 800),
                              builder: (t, _) => CustomPaint(
                                painter: _BurstPainter(
                                  t,
                                  _binMouth(b.$1),
                                  clean: b.$1 == 'clean',
                                  seed: b.$2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      for (final f in _flights)
                        Positioned.fill(
                          key: ValueKey('flight${f.n}'),
                          child: IgnorePointer(child: _flightView(f)),
                        ),
                      if (dragging)
                        Positioned(
                          left: _dragAt.dx - 118,
                          top: _dragAt.dy - 118,
                          child: IgnorePointer(child: _ghost()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundButton(
    IconData icon,
    Color color,
    double size,
    VoidCallback? onTap,
  ) => _Btn(
    radius: 32,
    gradient: _vGrad(const [Color(0xFFFFFDF4), Color(0xFFF5E6C2)]),
    shadows: [
      const BoxShadow(color: Color(0xFFD9A93C), offset: Offset(0, 7)),
      BoxShadow(
        color: _rgba(0, 0, 0, .22),
        offset: const Offset(0, 12),
        blurRadius: 16,
      ),
    ],
    pressedShadows: const [
      BoxShadow(color: Color(0xFFD9A93C), offset: Offset(0, 3)),
    ],
    pressDy: 4,
    onTap: onTap,
    child: Icon(icon, color: color, size: size),
  );

  Widget _gameMeter(int filled) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('$_kA/game_meter.png', fit: BoxFit.fill),
      Positioned(
        left: 46,
        top: 0,
        bottom: 6,
        width: 320,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Cleanliness Meter',
              style: _baloo(40, const Color(0xFF173F8E)),
            ),
          ),
        ),
      ),
      for (var i = 0; i < _kCards.length; i++)
        Positioned(
          left: 383 + 56.0 * i,
          top: 36,
          width: 42,
          height: 42,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _vGrad(
                i < filled
                    ? const [_greenTop, _green]
                    : const [Color(0xFFCFE0EF), Color(0xFFE4EFF8)],
              ),
              border: Border.all(
                color: i < filled ? _greenDeep : const Color(0xFFBCD3E8),
                width: 2,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _gameHint() => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('$_kA/game_hint.png', fit: BoxFit.fill),
      Padding(
        padding: const EdgeInsets.fromLTRB(80, 0, 80, 6),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Drag a card down into a bin',
              style: _baloo(
                36,
                Colors.white,
                shadows: [
                  Shadow(
                    color: _rgba(10, 40, 110, .45),
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  /// A card sitting in its tray slot: soft blue halo, the item art, label.
  /// The slot frame itself is painted on the tray.
  Widget _trayCard(_SortCard c) {
    final sorted = _sorted.containsKey(c.id);
    final n = _shakes[c.id] ?? 0;
    final face = SizedBox(
      width: _kSlotW,
      height: _kSlotH,
      child: Stack(
        children: [
          Positioned(
            left: (_kSlotW - 164) / 2,
            top: 22,
            width: 164,
            height: 164,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD5EAFB),
                    const Color(0xFFD5EAFB).withAlpha(0),
                  ],
                  stops: const [.62, 1],
                ),
              ),
            ),
          ),
          _art(c.id, Rect.fromLTWH((_kSlotW - 150) / 2, 32, 150, 140)),
          Positioned(
            left: 12,
            right: 12,
            bottom: 26,
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(c.label, style: _baloo(31, const Color(0xFF4A2A10))),
            ),
          ),
        ],
      ),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: sorted || _returning == c.id
          ? 0
          : (_dragId == c.id && _moved ? .25 : 1),
      child: IgnorePointer(
        ignoring: sorted,
        child: Listener(
          key: ValueKey('ta-card-${c.id}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _startDrag(c, e),
          child: _wrong == c.id
              ? _shake(
                  const Duration(milliseconds: 500),
                  face,
                  key: ValueKey('shake-${c.id}-$n'),
                )
              : _pop(
                  const Duration(milliseconds: 350),
                  face,
                  key: ValueKey('pop-${c.id}-$n'),
                ),
        ),
      ),
    );
  }

  /// One bin: [visible] is the painted bucket's rect on the stage; the
  /// 1346x1168 canvas is sized around it.
  Widget _bin(
    String id,
    Rect visible,
    String art,
    Color glow,
    int count,
    Color ring,
    Color ink,
  ) {
    final on = _hover == id;
    final (canvas, bb) = _kArtBounds['bin-$id']!;
    final k = visible.width / bb.width;
    return Positioned(
      key: ValueKey('ta-bin-$id'),
      left: visible.left - bb.left * k,
      top: visible.top - bb.top * k,
      width: canvas.width * k,
      height: canvas.height * k,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: on ? 1.06 : 1,
        child: _binReact(
          id,
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: bb.left * k - 14,
                top: bb.top * k - 14,
                width: bb.width * k + 28,
                height: bb.height * k + 28,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: on ? glow : glow.withAlpha(0),
                    borderRadius: BorderRadius.circular(70),
                  ),
                ),
              ),
              Positioned.fill(
                child: _dropShadow(
                  Image.asset(art, fit: BoxFit.fill),
                  14,
                  18,
                  _rgba(0, 0, 0, .25),
                ),
              ),
              if (count > 0)
                Positioned(
                  left: bb.right * k - 110,
                  top: bb.top * k + 70,
                  child: _pop(
                    const Duration(milliseconds: 300),
                    Container(
                      constraints: const BoxConstraints(minWidth: 68),
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: ring, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: _rgba(0, 0, 0, .25),
                            offset: const Offset(0, 6),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Text('$count', style: _baloo(36, ink, height: 1)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Squash-and-stretch when a card lands, a "no" rock when it's refused.
  Widget _binReact(String id, Widget body) {
    final hits = _binHits[id]!;
    final nos = _binNos[id]!;
    if (hits > 0) {
      body = _Once(
        key: ValueKey('hit-$id-$hits'),
        duration: const Duration(milliseconds: 560),
        child: body,
        builder: (t, c) {
          const at = [0.0, .22, .5, .78, 1.0];
          final sy = _kf(t, at, [1, .9, 1.05, .985, 1]);
          final sx = _kf(t, at, [1, 1.07, .965, 1.01, 1]);
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(sx, sy, 1),
            child: c,
          );
        },
      );
    }
    if (nos > 0) {
      body = _Once(
        key: ValueKey('no-$id-$nos'),
        duration: const Duration(milliseconds: 480),
        child: body,
        builder: (t, c) => Transform.rotate(
          alignment: Alignment.bottomCenter,
          angle: _kf(t, [0, .2, .4, .6, .8, 1], [0, -.06, .05, -.035, .02, 0]),
          child: c,
        ),
      );
    }
    return body;
  }

  /// Where a card enters a bin: centre of the opening, at the front rim.
  Offset _binMouth(String bin) {
    final r = bin == 'clean' ? _kCleanBin : _kDirtyBin;
    return Offset(r.center.dx, r.top + 64);
  }

  /// A dropped card in the air. Accepted: arcs up over the bin while it
  /// shrinks and turns, then falls in, cut off at the rim. Refused: springs
  /// back to its slot.
  Widget _flightView(_Flight f) {
    final ghost = _ghost(f.id);
    Widget place(Offset c, double scale, double deg) => Positioned(
      left: c.dx - 118,
      top: c.dy - 118,
      child: Transform.rotate(
        angle: deg * math.pi / 180,
        child: Transform.scale(scale: scale, child: ghost),
      ),
    );
    if (!f.accepted) {
      final home = _slotRect(_kCards.indexWhere((c) => c.id == f.id)).center;
      return _Once(
        duration: const Duration(milliseconds: 480),
        builder: (t, _) {
          final e = Curves.easeOutBack.transform(t);
          return Stack(
            children: [
              place(
                Offset.lerp(f.from, home, e)! -
                    Offset(0, 60 * math.sin(math.pi * t)),
                ui.lerpDouble(1, .92, t)!,
                ui.lerpDouble(0, 4, t)!,
              ),
            ],
          );
        },
      );
    }
    final mouth = _binMouth(f.bin);
    final above = mouth - const Offset(0, 120);
    return _Once(
      duration: const Duration(milliseconds: 720),
      builder: (t, _) {
        if (t < .6) {
          final e = Curves.easeInOutSine.transform(t / .6);
          final p =
              Offset.lerp(f.from, above, e)! -
              Offset(0, 150 * math.sin(math.pi * e));
          return Stack(
            children: [
              place(p, ui.lerpDouble(1, .5, e)!, ui.lerpDouble(-4, 14, e)!),
            ],
          );
        }
        final g = Curves.easeIn.transform((t - .6) / .4);
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: mouth.dy,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    place(
                      above + Offset(0, 300 * g),
                      ui.lerpDouble(.5, .42, g)!,
                      ui.lerpDouble(14, 22, g)!,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _ghost([String? id]) {
    final c = _kCards.firstWhere((c) => c.id == (id ?? _dragId));
    return Transform.rotate(
      angle: -4 * math.pi / 180,
      child: Transform.scale(
        scale: 1.06,
        child: Container(
          width: 236,
          height: 236,
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: const Color(0xFFF2B53A), width: 7),
            boxShadow: [
              BoxShadow(
                color: _rgba(0, 0, 0, .35),
                offset: const Offset(0, 30),
                blurRadius: 50,
              ),
            ],
          ),
          child: Stack(
            children: [_art(c.id, const Rect.fromLTWH(28, 28, 166, 166))],
          ),
        ),
      ),
    );
  }

  // ---- ending ----

  /// Stars for the run: none missed → 3, up to two slips → 2, else 1.
  int get _stars => _errors == 0
      ? 3
      : _errors <= 2
      ? 2
      : 1;

  /// Congratulations + summary of the whole round, in the start screen's
  /// 851x1847 space: Mumtaz! sign, stars, cheering mascots, a board with
  /// the round's numbers and what went into each bin, then Play Again /
  /// Continue. Everything lands in sequence under a burst of confetti.
  Widget _buildDone() {
    Widget at(double l, double t, double w, double h, Widget c) =>
        Positioned(left: l, top: t, width: w, height: h, child: c);
    final n = _kCards.length;
    final accuracy = (n / (n + _errors) * 100).round();
    final great = _stars >= 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/s1_start_bg.png', fit: BoxFit.cover),
        ColoredBox(color: _rgba(20, 30, 45, .3)),
        SafeArea(
          child: SizedBox.expand(
            child: FittedBox(
              child: SizedBox(
                width: 851,
                height: 1847,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    at(
                      145,
                      30,
                      560,
                      181,
                      _Once(
                        duration: const Duration(milliseconds: 650),
                        delay: const Duration(milliseconds: 100),
                        child: _endSign(),
                        builder: (t, c) => Opacity(
                          opacity: Curves.easeOut.transform(
                            (t * 2).clamp(0.0, 1.0),
                          ),
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              -90 * (1 - Curves.easeOutBack.transform(t)),
                            ),
                            child: c,
                          ),
                        ),
                      ),
                    ),
                    at(
                      190,
                      208,
                      470,
                      70,
                      _rise(
                        const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 350),
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _outlined(
                              great
                                  ? "You're a Taharah Hero!"
                                  : 'Good try! Keep practising!',
                              _baloo(52, Colors.white),
                              const Color(0xFF5A1E08),
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    at(
                      75.5,
                      415,
                      700,
                      700 * 1361 / 939,
                      _Once(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 450),
                        child: FittedBox(child: _endBoard(accuracy)),
                        builder: (t, c) {
                          final e = Curves.easeOutCubic.transform(t);
                          return Opacity(
                            opacity: e,
                            child: Transform.translate(
                              offset: Offset(0, 60 * (1 - e)),
                              child: c,
                            ),
                          );
                        },
                      ),
                    ),
                    // Stars get their own row between the line and the board.
                    for (var i = 0; i < 3; i++)
                      at(
                        i == 1 ? 355 : 425 + 150.0 * (i - 1) - 55,
                        i == 1 ? 282 : 300,
                        i == 1 ? 140 : 110,
                        i == 1 ? 127 : 100,
                        _pop(
                          const Duration(milliseconds: 450),
                          delay: Duration(milliseconds: 950 + 220 * i),
                          _endStar(i < _stars),
                        ),
                      ),
                    // Mascots stand either side of the buttons at the board's
                    // lower corners, same height and ground line: cheering
                    // for a strong round, thumbs-up for a low one.
                    at(
                      -12,
                      1385,
                      260,
                      360,
                      _rise(
                        const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 1350),
                        Image.asset(
                          great
                              ? '$_kA/end_girl_cheer.png'
                              : '$_kA/end_girl_thumbs.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    at(
                      603,
                      1385,
                      260,
                      360,
                      _rise(
                        const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 1450),
                        Image.asset(
                          great
                              ? '$_kA/end_boy_cheer.png'
                              : '$_kA/end_boy_thumbs.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    at(
                      245.5,
                      1612,
                      360,
                      118,
                      _pop(
                        const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 1700),
                        _ImgBtn(
                          key: const ValueKey('ta-again'),
                          up: '$_kA/end_again.png',
                          down: '$_kA/end_again_down.png',
                          onTap: _startGame,
                        ),
                      ),
                    ),
                    at(
                      235.5,
                      1458,
                      380,
                      137,
                      _pop(
                        const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 1820),
                        _ImgBtn(
                          key: const ValueKey('ta-continue'),
                          up: '$_kA/end_continue.png',
                          down: '$_kA/end_continue_down.png',
                          onTap: _finish,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const IgnorePointer(child: _Confetti()),
      ],
    );
  }

  /// The leafy board (939x1361, same art as How to Play) holding the round's
  /// numbers, the two bins' contents and the lesson line.
  Widget _endBoard(int accuracy) {
    const ink = Color(0xFF4A1405);
    Widget at(double l, double t, double w, double h, Widget c) =>
        Positioned(left: l, top: t, width: w, height: h, child: c);
    Widget box(List<Color> fill, Color border) => Container(
      decoration: BoxDecoration(
        gradient: _vGrad(fill),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border, width: 5),
      ),
    );
    Widget land(int i, Widget child) => _rise(
      const Duration(milliseconds: 450),
      delay: Duration(milliseconds: 850 + 150 * i),
      child,
    );

    Widget stat(
      double left,
      String value,
      String label,
      List<Color> fill,
      Color border,
      Color valueInk,
    ) => at(
      left,
      140,
      213,
      190,
      Stack(
        fit: StackFit.expand,
        children: [
          box(fill, border),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: _baloo(84, valueInk, height: 1)),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: _baloo(38, ink, height: 1)),
              ),
            ],
          ),
        ],
      ),
    );

    Widget binRow(
      double top,
      double height,
      String title,
      String bin,
      bool clean,
      List<Color> fill,
      Color border,
      Color titleInk,
    ) {
      final items = _kCards.where((c) => c.isClean == clean).toList();
      const cell = 150.0;
      final rowW = items.length * cell;
      return at(
        131,
        top,
        685,
        height,
        Stack(
          fit: StackFit.expand,
          children: [
            box(fill, border),
            _art(bin, const Rect.fromLTWH(20, 22, 120, 112)),
            Positioned(
              left: 150,
              right: 20,
              top: 30,
              height: 90,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title, style: _baloo(52, titleInk)),
                ),
              ),
            ),
            for (var i = 0; i < items.length; i++)
              _art(
                items[i].id,
                Rect.fromLTWH(
                  (685 - rowW) / 2 + i * cell + 10,
                  height - 170,
                  cell - 20,
                  140,
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 939,
      height: 1361,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_kA/how_panel.png', fit: BoxFit.fill),
          ),
          Positioned.fill(
            child: land(
              0,
              Stack(
                children: [
                  stat(
                    131,
                    '${_kCards.length}/${_kCards.length}',
                    'Sorted',
                    const [Color(0xFFD9F4FE), Color(0xFFB3E9FC)],
                    const Color(0xFF37B6F0),
                    _blue,
                  ),
                  stat(
                    367,
                    '$_errors',
                    _errors == 1 ? 'Mistake' : 'Mistakes',
                    const [Color(0xFFFEF5D6), Color(0xFFFDEFC5)],
                    const Color(0xFFF8C22A),
                    const Color(0xFFC77A00),
                  ),
                  stat(
                    603,
                    '$accuracy%',
                    'Correct',
                    const [Color(0xFFE6FCDD), Color(0xFFD0F7C3)],
                    const Color(0xFF6EE265),
                    _greenDeep,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: land(
              1,
              Stack(
                children: [
                  binRow(
                    360,
                    330,
                    'Sparkling Clean',
                    'bin-clean',
                    true,
                    const [Color(0xFFE6FCDD), Color(0xFFD0F7C3)],
                    const Color(0xFF6EE265),
                    _greenDeep,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: land(
              2,
              Stack(
                children: [
                  binRow(
                    715,
                    300,
                    'Dirty / Trash',
                    'bin-dirty',
                    false,
                    const [Color(0xFFFFE9E4), Color(0xFFFDD8CF)],
                    const Color(0xFFF08A73),
                    _redInk,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: land(
              3,
              Stack(
                children: [
                  at(
                    131,
                    1040,
                    685,
                    190,
                    CustomPaint(
                      foregroundPainter: const _DashedBorder(
                        color: Color(0xFFE0C99A),
                        width: 5,
                        radius: 30,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _cream,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Clean habits make us healthy.\n'
                            'Taharah is part of our faith.',
                            textAlign: TextAlign.center,
                            style: _baloo(44, _brown, height: 1.3),
                          ),
                        ),
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
  }
}

// ---------------------------------------------------------------------------
// Sessions 2 & 3 — Wudhu Part 1 / Part 2
// ---------------------------------------------------------------------------

class _WStep {
  const _WStep(this.id, this.n, this.label, this.short, this.pose, this.ok);
  final String id;
  final int n;
  final String label;

  /// Body part named in the "Oops!" hint.
  final String short;
  final String pose;
  final String ok;
}

/// A tap zone or hint ring on the figure: a true circle of radius [r]
/// around ([cx], [cy]) in boy-stand.png's 1024x1536 canvas px. The figure
/// box keeps the canvas's aspect, so it stays perfectly round on screen.
class _Zone {
  const _Zone.circle(this.id, this.cx, this.cy, this.r);
  final String id;
  final double cx;
  final double cy;
  final double r;

  /// As a fraction of the figure box.
  Rect get rect => Rect.fromLTWH(
    (cx - r) / 1024,
    (cy - r) / 1536,
    2 * r / 1024,
    2 * r / 1536,
  );

  /// Oval (null) — see [_shapePath].
  double? get radius => null;
}

class _WPart {
  const _WPart({
    required this.sessionNo,
    required this.stage,
    required this.title,
    required this.range,
    required this.startBoy,
    required this.instructBoy,
    required this.goal,
    required this.instruction,
    required this.playLabel,
    required this.doneLine,
    required this.firstAsk,
    required this.lastAsk,
    required this.steps,
    required this.zones,
    required this.rings,
  });

  final int sessionNo;
  final int stage;
  final String title;
  final String range;
  final String startBoy;
  final String instructBoy;
  final String goal;
  final String instruction;
  final String playLabel;
  final String doneLine;
  final String firstAsk;
  final String lastAsk;
  final List<_WStep> steps;

  /// Tap zones, bottom-most first (the prototypes' z-index order).
  final List<_Zone> zones;
  final List<_Zone> rings;
}

const _kPart1 = _WPart(
  sessionNo: 2,
  stage: 5,
  title: 'Wudhu Part 1',
  range: 'Steps 1 to 5',
  startBoy: '$_kA/boy-cheer.png',
  instructBoy: '$_kA/boy-cheer2.png',
  goal: 'Learning goal: demonstrate the steps of wudhu in the correct order.',
  instruction:
      'Tap the body parts in the correct order to complete wudhu. There are 5 steps!',
  playLabel: 'Start Wudhu',
  doneLine: 'You learned Wudhu Part 1',
  firstAsk: 'What should I wash first?',
  lastAsk: "Last step! Let's do it.",
  steps: [
    _WStep(
      'hands',
      1,
      'Wash Hands',
      'hands',
      '$_kA/boy-hands.png',
      'Mumtaz! Hands washed.',
    ),
    _WStep(
      'mouth',
      2,
      'Rinse Mouth',
      'mouth',
      '$_kA/boy-mouth.png',
      'Mumtaz! Mouth rinsed.',
    ),
    _WStep(
      'nose',
      3,
      'Rinse Nose',
      'nose',
      '$_kA/boy-nose.png',
      'Mumtaz! Nose rinsed.',
    ),
    _WStep(
      'face',
      4,
      'Wash Face',
      'face',
      '$_kA/boy-face.png',
      'Mumtaz! Face washed.',
    ),
    _WStep(
      'right_arm',
      5,
      'Wash Right Arm',
      'right arm',
      '$_kA/boy-rightarm.png',
      'Mumtaz! Right arm washed. Part 1 complete!',
    ),
  ],
  // Circles measured on boy-stand.png (canvas px): face, his right forearm
  // (screen left, since he faces us), hands, nose, mouth. Later zones sit on
  // top, so nose/mouth win over the face.
  zones: [
    _Zone.circle('face', 497, 425, 190),
    _Zone.circle('right_arm', 282, 868, 80),
    _Zone.circle('hands', 257, 985, 86),
    _Zone.circle('hands', 749, 988, 86),
    _Zone.circle('nose', 488, 440, 36),
    _Zone.circle('mouth', 490, 508, 52),
  ],
  rings: [
    _Zone.circle('hands', 257, 985, 82),
    _Zone.circle('hands', 749, 988, 82),
    _Zone.circle('mouth', 490, 503, 62),
    _Zone.circle('nose', 488, 444, 38),
    _Zone.circle('face', 497, 425, 185),
    _Zone.circle('right_arm', 282, 868, 72),
  ],
);

// The prototype pairs "right foot" with boy-leftfoot.png and vice versa —
// the art is named from the viewer's side.
const _kPart2 = _WPart(
  sessionNo: 3,
  stage: 6,
  title: 'Wudhu Part 2',
  range: 'Steps 6 to 10',
  startBoy: '$_kA/boy-cheer4.png',
  instructBoy: '$_kA/boy-cheer2.png',
  goal: 'Learning goal: finish the wudhu sequence on the head and feet.',
  instruction: 'Finish your wudhu! Tap the last 5 parts in the correct order.',
  playLabel: 'Finish Wudhu',
  doneLine: 'Your wudhu is complete',
  firstAsk: 'What comes next in wudhu?',
  lastAsk: "Last step! Let's finish.",
  steps: [
    _WStep(
      'left_arm',
      6,
      'Wash Left Arm',
      'left arm',
      '$_kA/boy-arms.png',
      'Mumtaz! Left arm washed.',
    ),
    _WStep(
      'head',
      7,
      'Wipe Head',
      'head',
      '$_kA/boy-head.png',
      'Mumtaz! Head wiped.',
    ),
    _WStep(
      'ears',
      8,
      'Wipe Ears',
      'ears',
      '$_kA/boy-ears.png',
      'Mumtaz! Ears wiped.',
    ),
    _WStep(
      'right_foot',
      9,
      'Wash Right Foot',
      'right foot',
      '$_kA/boy-leftfoot.png',
      'Mumtaz! Right foot washed.',
    ),
    _WStep(
      'left_foot',
      10,
      'Wash Left Foot',
      'left foot',
      '$_kA/boy-rightfoot.png',
      'Mumtaz! Left foot washed. Wudhu complete!',
    ),
  ],
  // Circles measured on boy-stand.png (canvas px): forearm, head, ears,
  // feet. Sides follow the art as the prototype had them.
  zones: [
    _Zone.circle('left_arm', 725, 868, 80),
    _Zone.circle('head', 507, 175, 160),
    _Zone.circle('ears', 287, 445, 62),
    _Zone.circle('ears', 712, 452, 62),
    _Zone.circle('right_foot', 355, 1395, 115),
    _Zone.circle('left_foot', 670, 1395, 115),
  ],
  rings: [
    _Zone.circle('left_arm', 725, 868, 72),
    _Zone.circle('head', 507, 175, 155),
    _Zone.circle('ears', 287, 445, 60),
    _Zone.circle('ears', 712, 452, 60),
    _Zone.circle('right_foot', 355, 1395, 112),
    _Zone.circle('left_foot', 670, 1395, 112),
  ],
);

/// Figure box: `top: 150px; bottom: 108px; aspect-ratio: 1024 / 1536`.
const double _kFigH = _kH - 150 - 108;
const double _kFigW = _kFigH * 1024 / 1536;

enum _WScreen { start, instruct, play, done }

class _Wudhu extends StatefulWidget {
  const _Wudhu({
    required this.part,
    required this.xp,
    required this.onComplete,
    this.onEnding,
    this.onExit,
  });

  final _WPart part;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Fired when the game's own ending screen appears (the lesson player's
  /// cue for its congratulations sound).
  final VoidCallback? onEnding;
  final VoidCallback? onExit;

  @override
  State<_Wudhu> createState() => _WudhuState();
}

class _WudhuState extends State<_Wudhu> {
  _WScreen _screen = _WScreen.start;
  final TaharahWudhuAudio _audio = TaharahWudhuAudio();
  bool _sound = true;

  @override
  void initState() {
    super.initState();
    _audio.start();
  }

  void _toggleSound() {
    setState(() => _sound = !_sound);
    _audio.setEnabled(_sound);
  }

  int _idx = 0;
  String? _pose;
  _Toast? _toast;
  int _toastN = 0;
  int _shakeN = 0;

  /// The 4s "Get Ready!" countdown into the game (Start / Finish Wudhu).
  bool _getReady = false;
  int _readyN = 0;
  int _errors = 0;
  Timer? _toastT, _doneT, _poseT, _readyT, _readyEndT;

  _WPart get _p => widget.part;
  List<_WStep> get _steps => _p.steps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache(context, [
      '$_kA/s2-bg.png',
      '$_kA/s2_start_bg_clean.png',
      '$_kA/s2_lantern_l.png',
      '$_kA/s2_lantern_r.png',
      '$_kA/s2_logo.png',
      '$_kA/s2_boy.png',
      '$_kA/s2_play.png',
      '$_kA/s2_play_down.png',
      '$_kA/w_progress.png',
      '$_kA/w_hint.png',
      '$_kA/w_card.png',
      for (final b in ['back', 'music', 'home']) ...[
        '$_kA/w_btn_$b.png',
        '$_kA/w_btn_${b}_down.png',
      ],
      '$_kA/w_end_board.png',
      '$_kA/w_end_top.png',
      '$_kA/boy-stand.png',
      '$_kA/boy-celebrate.png',
      _p.instructBoy,
      for (final s in _steps) s.pose,
    ]);
  }

  @override
  void dispose() {
    _audio.dispose();
    for (final t in [_toastT, _doneT, _poseT, _readyT, _readyEndT]) {
      t?.cancel();
    }
    super.dispose();
  }

  void _reset() {
    _toastT?.cancel();
    _doneT?.cancel();
    _poseT?.cancel();
    _idx = 0;
    _pose = null;
    _toast = null;
    _errors = 0;
  }

  void _goStart() => setState(() {
    _reset();
    _screen = _WScreen.start;
  });

  void _goPlay() {
    if (_getReady) return;
    setState(() {
      _getReady = true;
      _readyN++;
    });
    // The game swaps in under the countdown just before it clears.
    _readyT = Timer(const Duration(milliseconds: 3450), () {
      if (!mounted) return;
      setState(() {
        _reset();
        _screen = _WScreen.play;
      });
    });
    _readyEndT = Timer(const Duration(milliseconds: 4000), () {
      if (mounted) setState(() => _getReady = false);
    });
  }

  void _finish() {
    final n = _steps.length;
    widget.onComplete(widget.xp, n / (n + _errors) * 100.0, _errors);
  }

  void _tap(String id) {
    if (_idx >= _steps.length) return;
    final step = _steps[_idx];
    _toastT?.cancel();
    if (id == step.id) {
      final done = _idx + 1 >= _steps.length;
      setState(() {
        _idx++;
        _pose = step.pose;
        _toast = _Toast(step.ok, '✅', good: true);
        _toastN++;
      });
      _toastT = Timer(
        const Duration(milliseconds: 5000),
        () => setState(() => _toast = null),
      );
      _poseT?.cancel();
      _poseT = Timer(
        const Duration(milliseconds: 5000),
        () => setState(() => _pose = null),
      );
      if (done) {
        _doneT?.cancel();
        _doneT = Timer(
          const Duration(milliseconds: 5200),
          () {
            setState(() => _screen = _WScreen.done);
            widget.onEnding?.call();
          },
        );
      }
    } else {
      setState(() {
        _toast = _Toast(
          "Oops! That's not correct. Try tapping the ${step.short}.",
          '⚠️',
          good: false,
        );
        _toastN++;
        _shakeN++;
        _errors++;
      });
      _toastT = Timer(
        const Duration(milliseconds: 2100),
        () => setState(() => _toast = null),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFE3CB),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Old screen eases forward and fades; the new one settles in.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 550),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            transitionBuilder: (child, anim) {
              final incoming = child.key == ValueKey(_screen);
              return IgnorePointer(
                ignoring: !incoming,
                child: FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(
                      begin: incoming ? .97 : 1.06,
                      end: 1.0,
                    ).animate(anim),
                    child: child,
                  ),
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_screen),
              child: switch (_screen) {
                _WScreen.start => _buildStart(),
                _WScreen.instruct => _buildInstruct(),
                _WScreen.play => _buildPlay(),
                _WScreen.done => _buildDone(),
              },
            ),
          ),
          if (_getReady)
            _GetReady(key: ValueKey('ready$_readyN'), bg: '$_kA/s2-bg.png'),
        ],
      ),
    );
  }

  // ---- start ----

  Widget _buildStart() {
    return _buildStartPart1();
  }

  /// Session 2's start screen, laid out in the reference comp's 851x1847
  /// space over the Wudhu Room hallway (signs painted in): title with its
  /// "Cleanliness & Wudhu" plank, the pointing boy, and the Play button
  /// with its rays and drifting bubbles.
  Widget _buildStartPart1() {
    Widget at(double l, double t, double w, double h, Widget c) =>
        Positioned(left: l, top: t, width: w, height: h, child: c);

    var bubbleN = 0;
    Widget bubble(double x, double y, double r, double phase) => Positioned(
      left: x - r,
      top: y - r,
      width: r * 2,
      height: r * 2,
      child: _Once(
        duration: const Duration(milliseconds: 600),
        delay: Duration(milliseconds: 1100 + 110 * bubbleN++),
        builder: (t, c) => Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.scale(
            scale: .4 + .6 * Curves.easeOutBack.transform(t),
            child: c,
          ),
        ),
        child: _Loop(
          period: Duration(milliseconds: 2600 + (phase * 900).round()),
          builder: (t, c) => Transform.translate(
            offset: Offset(0, -8 * math.sin((t + phase) * 2 * math.pi)),
            child: c,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-.35, -.4),
                colors: [
                  _rgba(255, 255, 255, .95),
                  _rgba(150, 215, 255, .75),
                  _rgba(60, 150, 235, .6),
                ],
                stops: const [0, .35, 1],
              ),
              border: Border.all(color: _rgba(255, 255, 255, .9), width: 3),
              boxShadow: [
                BoxShadow(color: _rgba(80, 170, 255, .35), blurRadius: 14),
              ],
            ),
          ),
        ),
      ),
    );

    Widget ray(double cx, double cy, double deg) => Positioned(
      left: cx - 16,
      top: cy - 28,
      width: 32,
      height: 56,
      child: Transform.rotate(
        angle: deg * math.pi / 180,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _vGrad(const [Color(0xFFFFE45C), Color(0xFFF7B500)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD08A00), width: 2),
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        _Once(
          duration: const Duration(milliseconds: 1400),
          builder: (t, c) => Transform.scale(
            scale: 1.08 - .08 * Curves.easeOutCubic.transform(t),
            child: c,
          ),
          child: const _LanternHall(),
        ),
        SafeArea(
          child: SizedBox.expand(
            child: FittedBox(
              child: SizedBox(
                width: 851,
                height: 1847,
                child: Stack(
                  children: [
                    at(
                      95,
                      112,
                      685,
                      368,
                      _Once(
                        duration: const Duration(milliseconds: 750),
                        delay: const Duration(milliseconds: 150),
                        builder: (t, c) => Opacity(
                          opacity: Curves.easeOut.transform(
                            (t * 2).clamp(0.0, 1.0),
                          ),
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              -140 * (1 - Curves.easeOutBack.transform(t)),
                            ),
                            child: c,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset('$_kA/s2_logo.png', fit: BoxFit.fill),
                            Align(
                              alignment: const Alignment(0, .7),
                              child: SizedBox(
                                width: 330,
                                height: 60,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Cleanliness & Wudhu',
                                    style: _baloo(38, const Color(0xFF5A2A0E)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Contact shadow under the boy's sandals.
                    at(
                      -10,
                      1338,
                      320,
                      56,
                      _Once(
                        duration: const Duration(milliseconds: 750),
                        delay: const Duration(milliseconds: 400),
                        builder: (t, c) {
                          final e = Curves.easeOutCubic.transform(t);
                          return Opacity(
                            opacity: e,
                            child: Transform.scale(
                              scaleX: .5 + .5 * e,
                              child: c,
                            ),
                          );
                        },
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    _rgba(60, 40, 20, .45),
                                    _rgba(60, 40, 20, .2),
                                    _rgba(60, 40, 20, 0),
                                  ],
                                  stops: const [0, .45, .72],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    at(
                      12,
                      748,
                      385,
                      625,
                      _Once(
                        duration: const Duration(milliseconds: 750),
                        delay: const Duration(milliseconds: 400),
                        builder: (t, c) {
                          final e = Curves.easeOutCubic.transform(t);
                          return Opacity(
                            opacity: e,
                            child: Transform.translate(
                              offset: Offset(-160 * (1 - e), 0),
                              child: c,
                            ),
                          );
                        },
                        child: _dropShadow(
                          Image.asset('$_kA/s2_boy.png', fit: BoxFit.fill),
                          14,
                          18,
                          _rgba(45, 30, 15, .35),
                        ),
                      ),
                    ),
                    at(
                      0,
                      1320,
                      851,
                      360,
                      _pop(
                        const Duration(milliseconds: 550),
                        delay: const Duration(milliseconds: 850),
                        _Loop(
                          period: const Duration(milliseconds: 1800),
                          builder: (t, c) => Transform.scale(
                            scale: 1 + .025 * math.sin(t * 2 * math.pi),
                            child: c,
                          ),
                          child: Stack(
                            children: [
                              ray(180, 112, -35),
                              ray(158, 164, -90),
                              ray(180, 216, -145),
                              ray(671, 112, 35),
                              ray(693, 164, 90),
                              ray(671, 216, 145),
                              at(
                                183,
                                32,
                                486,
                                288,
                                _ImgBtn(
                                  key: const ValueKey('ta-w-play'),
                                  up: '$_kA/s2_play.png',
                                  down: '$_kA/s2_play_down.png',
                                  onTap: () => setState(
                                    () => _screen = _WScreen.instruct,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    bubble(98, 1228, 16, 0),
                    bubble(96, 1410, 42, .3),
                    bubble(772, 1295, 32, .6),
                    bubble(730, 1433, 20, .15),
                    bubble(222, 1633, 22, .45),
                    bubble(635, 1660, 42, .8),
                    if (widget.onExit != null)
                      at(
                        26,
                        30,
                        104,
                        101,
                        _ImgBtn(
                          key: const ValueKey('ta-w-home'),
                          up: '$_kA/w_btn_home.png',
                          down: '$_kA/w_btn_home_down.png',
                          onTap: widget.onExit!,
                        ),
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

  // ---- instructions ----

  /// How to Play, in the washroom at full brightness: the instruction card
  /// with its sound button, the five step tiles, the boy standing on the
  /// painted floor spot, and the glossy Start button.
  /// Step tiles light up one after another from here (ms)…
  static const _kTourStart = 900;

  /// …each for this long…
  static const _kTourStep = 850;

  /// …and the Start button appears once the last one has had its turn.
  int get _tourEnd => _kTourStart + _kTourStep * _steps.length;

  Widget _buildInstruct() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _groundedBackdrop(),
        _stage(
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 74, 20, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _rise(const Duration(milliseconds: 450), _instructCard()),
                    const SizedBox(height: 16),
                    _stepTour(),
                    const Spacer(),
                    _startButton(),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _wIconButton(
                  'back',
                  _goStart,
                  key: const ValueKey('ta-w-howto-back'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The five step tiles: they rise in, then each one in turn swells, glows
  /// gold and lifts, walking the child through the order before play.
  Widget _stepTour() {
    final total = _tourEnd + 200;
    return _Once(
      duration: Duration(milliseconds: total),
      builder: (t, _) {
        final ms = t * total;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: _rise(
                    const Duration(milliseconds: 420),
                    delay: Duration(milliseconds: 180 + 90 * i),
                    _stepTile(
                      _steps[i],
                      glow: math.sin(
                        math.pi *
                            ((ms - _kTourStart - i * _kTourStep) / _kTourStep)
                                .clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _startButton() => _Once(
    duration: const Duration(milliseconds: 500),
    delay: Duration(milliseconds: _tourEnd),
    builder: (t, c) => IgnorePointer(
      ignoring: t == 0,
      child: Opacity(
        opacity: Curves.ease.transform(t),
        child: Transform.scale(
          scale: _kf(t, [0, .6, 1], [.6, 1.08, 1]),
          child: c,
        ),
      ),
    ),
    child: _glossyButton(_p.playLabel, _goPlay),
  );

  /// The washroom art laid out "cover", with the boy placed in the art's own
  /// 853x1844 pixel space so his feet always land on the painted floor spot,
  /// plus soft ceiling light washing down from the top.
  Widget _groundedBackdrop() {
    const art = Size(853, 1844);
    final boy = _p.instructBoy;
    // Visible bounds of the two How to Play boys in their 1024x1536 canvas.
    final bb = boy.endsWith('boy-cheer5.png')
        ? const Rect.fromLTRB(126, 59, 895, 1445)
        : const Rect.fromLTRB(95, 61, 795, 1460);
    // Centre of his feet; the raised fist and spark marks widen the art on
    // one side, so centring the bounds would push his body off-centre.
    final feetX = boy.endsWith('boy-cheer5.png') ? 504.0 : 507.5;
    const feet = Offset(426, 1492);
    const boyH = 640.0;
    final k = boyH / bb.height;
    return LayoutBuilder(
      builder: (context, box) {
        final s = math.max(
          box.maxWidth / art.width,
          box.maxHeight / art.height,
        );
        final dx = (box.maxWidth - art.width * s) / 2;
        final dy = (box.maxHeight - art.height * s) / 2;
        Rect r(double l, double t, double w, double h) =>
            Rect.fromLTWH(dx + l * s, dy + t * s, w * s, h * s);
        return Stack(
          fit: StackFit.expand,
          children: [
            const _LiveWashroom(),
            _ceilingLight(),
            _runningTaps(s, dx, dy),
            Positioned.fromRect(
              rect: r(feet.dx - 160, feet.dy - 30, 320, 60),
              child: _rise(
                const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 350),
                FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            _rgba(70, 50, 30, .42),
                            _rgba(70, 50, 30, .18),
                            _rgba(70, 50, 30, 0),
                          ],
                          stops: const [0, .45, .72],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: r(
                feet.dx - feetX * k,
                feet.dy - bb.bottom * k,
                1024 * k,
                1536 * k,
              ),
              child: _rise(
                const Duration(milliseconds: 550),
                delay: const Duration(milliseconds: 350),
                _dropShadow(
                  Image.asset(boy, fit: BoxFit.fill),
                  10 * s,
                  16 * s,
                  _rgba(45, 30, 15, .28),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _instructCard() => Container(
    padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
    decoration: _creamPanel(26),
    child: Row(
      children: [
        SizedBox(
          width: 66,
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (x, y, deg) in [(0.0, 4.0, -60.0), (8.0, -4.0, -30.0)])
                Positioned(
                  left: x,
                  top: y,
                  child: Transform.rotate(
                    angle: deg * math.pi / 180,
                    child: Container(
                      width: 4,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC21A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _Btn(
                  width: 54,
                  height: 54,
                  radius: 27,
                  gradient: _vGrad(const [
                    Color(0xFF5AAEFF),
                    Color(0xFF1565D8),
                  ]),
                  shadows: [
                    const BoxShadow(
                      color: Color(0xFF0E4FA8),
                      offset: Offset(0, 4),
                    ),
                    BoxShadow(
                      color: _rgba(20, 60, 140, .3),
                      offset: const Offset(0, 6),
                      blurRadius: 10,
                    ),
                  ],
                  pressedShadows: const [
                    BoxShadow(color: Color(0xFF0E4FA8), offset: Offset(0, 1)),
                  ],
                  pressDy: 3,
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _p.instruction,
            style: _baloo(18.5, const Color(0xFF1A4B9C), height: 1.25),
          ),
        ),
      ],
    ),
  );

  /// Cream board with a warm gold rim, as in the How to Play reference.
  BoxDecoration _creamPanel(double radius) => BoxDecoration(
    gradient: _vGrad(const [Color(0xFFFFFDF7), Color(0xFFFFF4DC)]),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFF2CB5E), width: 3),
    boxShadow: [
      BoxShadow(
        color: _rgba(120, 80, 20, .22),
        offset: const Offset(0, 6),
        blurRadius: 14,
      ),
    ],
  );

  Widget _stepTile(_WStep s, {double glow = 0}) => Transform.translate(
    offset: Offset(0, -6 * glow),
    child: Transform.scale(
      scale: 1 + .12 * glow,
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 9, 3, 9),
        decoration: _creamPanel(16).copyWith(
          border: Border.all(
            color: Color.lerp(
              const Color(0xFFF2CB5E),
              const Color(0xFFFFB300),
              glow,
            )!,
            width: 3 + 1.5 * glow,
          ),
          boxShadow: [
            BoxShadow(
              color: _rgba(120, 80, 20, .22),
              offset: const Offset(0, 6),
              blurRadius: 14,
            ),
            if (glow > 0)
              BoxShadow(
                color: _rgba(255, 200, 60, .75 * glow),
                blurRadius: 18 * glow,
                spreadRadius: 3 * glow,
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _vGrad(const [Color(0xFF3FCB5E), Color(0xFF1B8C38)]),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _rgba(20, 90, 40, .3),
                    offset: const Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Text('${s.n}', style: _baloo(14, Colors.white, height: 1)),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                s.label.replaceFirst(' ', '\n'),
                textAlign: TextAlign.center,
                style: _baloo(12.5, const Color(0xFF5B3A1A), height: 1.12),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Big glossy green pill, like the reference's Start Wudhu button.
  Widget _glossyButton(String label, VoidCallback onTap) => _Btn(
    height: 66,
    width: double.infinity,
    radius: 33,
    gradient: _vGrad(const [Color(0xFF5BE574), Color(0xFF22B043)]),
    shadows: [
      const BoxShadow(color: Color(0xFF137A2E), offset: Offset(0, 6)),
      BoxShadow(
        color: _rgba(0, 60, 20, .3),
        offset: const Offset(0, 12),
        blurRadius: 18,
      ),
    ],
    pressedShadows: const [
      BoxShadow(color: Color(0xFF137A2E), offset: Offset(0, 2)),
    ],
    pressDy: 4,
    onTap: onTap,
    child: SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 22,
            right: 22,
            top: 6,
            height: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _rgba(255, 255, 255, .32),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 20,
            child: Container(
              width: 7,
              height: 14,
              decoration: BoxDecoration(
                color: _rgba(255, 255, 255, .55),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          _outlined(
            label,
            _baloo(28, Colors.white, height: 1),
            const Color(0xFF137A2E),
            5,
          ),
        ],
      ),
    ),
  );

  // ---- play ----

  Widget _buildPlay() {
    final cur = _steps[math.min(_idx, _steps.length - 1)];
    final posing = _pose != null;
    return _Once(
      duration: const Duration(milliseconds: 500),
      builder: (t, child) {
        final e = const Cubic(.22, .9, .3, 1).transform(t);
        return Opacity(
          opacity: e,
          child: Transform.scale(scale: 1.04 - .04 * e, child: child),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _playBackdrop(),
          _stage(
            Stack(
              children: [
                _wHud(),
                _wProgress(),
                Positioned(
                  left: 14,
                  top: 122,
                  width: 170,
                  height: 104,
                  child: IgnorePointer(
                    ignoring: posing,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: posing ? 0 : 1,
                      child: _stepCard(cur),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 40,
                  child: _toast != null
                      ? _toastCard(
                          _toast!,
                          key: ValueKey('toast$_toastN'),
                          wudhu: true,
                        )
                      : IgnorePointer(child: Center(child: _wHint())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Washroom at full brightness with the boy standing on the painted floor
  /// spot, placed in the art's own 853x1844 space (like How to Play) and
  /// life-sized to the room.
  Widget _playBackdrop() {
    const art = Size(853, 1844);
    // boy-stand.png: solid bounds bottom 1475, feet centred at x 509.5,
    // 1432px tall; shown 960 art-px tall with his feet on the floor spot.
    const k = 960 / 1432;
    const left = 426 - 509.5 * k;
    const top = 1492 - 1475 * k;
    return LayoutBuilder(
      builder: (context, box) {
        final sc = math.max(
          box.maxWidth / art.width,
          box.maxHeight / art.height,
        );
        final dx = (box.maxWidth - art.width * sc) / 2;
        final dy = (box.maxHeight - art.height * sc) / 2;
        final w = 1024 * k * sc;
        final h = 1536 * k * sc;
        final figure = _figureBox(w, h);
        return Stack(
          fit: StackFit.expand,
          children: [
            const _LiveWashroom(),
            _ceilingLight(),
            _runningTaps(sc, dx, dy),
            Positioned(
              left: dx + left * sc,
              top: dy + top * sc,
              width: w,
              height: h,
              child: _toast != null && !_toast!.good
                  ? _shake(
                      const Duration(milliseconds: 400),
                      figure,
                      key: ValueKey('shake$_shakeN'),
                      times: _shakeN,
                    )
                  : figure,
            ),
          ],
        );
      },
    );
  }

  /// Live water over the three painted taps, in the washroom art's pixel
  /// space ([sc] px per art px, art offset [dx], [dy] on screen).
  Widget _runningTaps(double sc, double dx, double dy) => Positioned.fill(
    child: IgnorePointer(
      child: _Loop(
        period: const Duration(milliseconds: 2400),
        builder: (t, _) =>
            CustomPaint(painter: _TapWater(t, sc, Offset(dx, dy))),
      ),
    ),
  );

  /// Warm light blooming down from the ceiling.
  Widget _ceilingLight() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -1.15),
        radius: 1.25,
        colors: [
          _rgba(255, 250, 230, .55),
          _rgba(255, 244, 214, .18),
          _rgba(255, 244, 214, 0),
        ],
        stops: const [0, .45, 1],
      ),
    ),
  );

  /// Cream rounded image button (back / music / home) with its pressed art.
  Widget _wIconButton(String name, VoidCallback onTap, {Key? key}) => SizedBox(
    width: 48,
    height: 48,
    child: _ImgBtn(
      key: key,
      up: '$_kA/w_btn_$name.png',
      down: '$_kA/w_btn_${name}_down.png',
      onTap: onTap,
    ),
  );

  Widget _wHud() => Positioned(
    left: 0,
    right: 0,
    top: 0,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          _wIconButton('back', _goStart),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _outlined(
                  _p.title,
                  _baloo(27, Colors.white, height: 1),
                  const Color(0xFF123C86),
                  7,
                ),
              ),
            ),
          ),
          Opacity(
            opacity: _sound ? 1 : 0.45,
            child: _wIconButton('music', _toggleSound),
          ),
        ],
      ),
    ),
  );

  /// Cream progress pill (art pre-stretched to this 362x40 shape so its
  /// round ends keep their shape) with one dot per step: done, current,
  /// still to come.
  Widget _wProgress() => Positioned(
    left: 14,
    right: 14,
    top: 70,
    height: 40,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/w_progress.png', fit: BoxFit.fill),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 16, 2),
          child: Row(
            children: [
              Text(
                'Wudhu Progress',
                style: _baloo(14, const Color(0xFF173F8E)),
              ),
              const Spacer(),
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _vGrad(
                      i < _idx
                          ? const [Color(0xFF3F97F5), Color(0xFF1560C9)]
                          : i == _idx
                          ? const [Color(0xFF7CC0FF), Color(0xFF3A8BEA)]
                          : const [Color(0xFFD4E0EC), Color(0xFFE6EEF6)],
                    ),
                    border: Border.all(
                      color: i == _idx
                          ? Colors.white
                          : i < _idx
                          ? const Color(0xFF0F4FA8)
                          : const Color(0xFFC0D0E0),
                      width: i == _idx ? 2.5 : 1.5,
                    ),
                    boxShadow: i == _idx
                        ? [
                            BoxShadow(
                              color: _rgba(60, 140, 240, .5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _wHint() => SizedBox(
    width: 300,
    height: 44,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/w_hint.png', fit: BoxFit.fill),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 3),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Tap the glowing part on the boy',
                style: _baloo(
                  15.5,
                  Colors.white,
                  shadows: [
                    Shadow(
                      color: _rgba(10, 40, 110, .45),
                      offset: const Offset(0, 1.5),
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

  Widget _stepCard(_WStep cur) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('$_kA/w_card.png', fit: BoxFit.fill),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Step ${math.min(_idx + 1, _steps.length)} of ${_steps.length}',
              style: _baloo(13, _gold, height: 1.1),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                cur.label,
                style: _baloo(22, Colors.white, height: 1.1),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _idx == 0
                  ? _p.firstAsk
                  : _idx == _steps.length - 1
                  ? _p.lastAsk
                  : 'What should I wash next?',
              maxLines: 2,
              style: _nunito(12, _rgba(255, 255, 255, .92), height: 1.15),
            ),
          ],
        ),
      ),
    ],
  );

  /// The tappable boy, [w]x[h] on screen (his 1024x1536 canvas). Zone rects
  /// are fractions of the canvas; corner radii were authored for a
  /// [_kFigW]-wide figure and scale with it.
  Widget _figureBox(double w, double h) {
    final posing = _pose != null;
    final active = _idx < _steps.length ? _steps[_idx].id : null;
    final shadow = _rgba(60, 45, 25, .35);
    final f = w / _kFigW;
    double? rad(double? r) => r == null ? null : r * f;
    Rect px(Rect r) =>
        Rect.fromLTWH(r.left * w, r.top * h, r.width * w, r.height * h);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ground shadow: radial ellipse, farthest-corner, fading out by 70%.
        Positioned(
          left: w * .12,
          bottom: -h * .015,
          width: w * .76,
          height: h * .05,
          child: IgnorePointer(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: 100,
                height: 100,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: math.sqrt2 / 2,
                      colors: [_rgba(60, 45, 25, .42), _rgba(60, 45, 25, 0)],
                      stops: const [0, .7],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Standing <-> washing pose: the two cross-fade (both ways) while
        // the new one settles from a touch smaller with a soft overshoot,
        // scaled from his feet so he stays planted on the floor.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              reverseDuration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  alignment: Alignment.bottomCenter,
                  scale: Tween(begin: .94, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  ),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_pose ?? 'stand'),
                child: _dropShadow(
                  Image.asset(
                    _pose ?? '$_kA/boy-stand.png',
                    fit: BoxFit.contain,
                    width: w,
                    height: h,
                  ),
                  10,
                  8,
                  shadow,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _tap('__miss'),
          ),
        ),
        for (final (i, z) in _p.zones.indexed)
          Positioned.fromRect(
            key: ValueKey('ta-zone-${z.id}-$i'),
            rect: px(z.rect),
            child: ClipPath(
              clipper: _ShapeClip(rad(z.radius)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _tap(z.id),
              ),
            ),
          ),
        for (final r in _p.rings)
          Positioned.fromRect(
            rect: px(r.rect),
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: !posing && active == r.id ? 1 : 0,
                child: !posing && active == r.id
                    ? _Loop(
                        period: const Duration(milliseconds: 1400),
                        builder: (t, _) => CustomPaint(
                          painter: _GlowRing(rad(r.radius), t),
                          size: Size.infinite,
                        ),
                      )
                    : CustomPaint(
                        painter: _GlowRing(rad(r.radius), 0),
                        size: Size.infinite,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  // ---- ending ----

  /// Stars for the run: no wrong taps → 3, up to two → 2, else 1.
  int get _stars => _errors == 0
      ? 3
      : _errors <= 2
      ? 2
      : 1;

  /// Congratulations + summary: Mumtaz! banner, stars, the blue water board with
  /// the round's numbers and the five wudhu steps ticked off, the lesson
  /// line, Play Again / Continue, and confetti.
  Widget _buildDone() {
    Widget at(double l, double t, double w, double h, Widget c) =>
        Positioned(left: l, top: t, width: w, height: h, child: c);
    final n = _steps.length;
    final accuracy = (n / (n + _errors) * 100).round();
    final great = _stars >= 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/s2-bg.png', fit: BoxFit.cover),
        _ceilingLight(),
        ColoredBox(color: _rgba(20, 30, 45, .22)),
        SafeArea(
          child: SizedBox.expand(
            child: FittedBox(
              child: SizedBox(
                width: 851,
                height: 1847,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    at(
                      115.5,
                      30,
                      620,
                      171,
                      _Once(
                        duration: const Duration(milliseconds: 650),
                        delay: const Duration(milliseconds: 100),
                        child: _wEndSign(),
                        builder: (t, c) => Opacity(
                          opacity: Curves.easeOut.transform(
                            (t * 2).clamp(0.0, 1.0),
                          ),
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              -90 * (1 - Curves.easeOutBack.transform(t)),
                            ),
                            child: c,
                          ),
                        ),
                      ),
                    ),
                    at(
                      150,
                      208,
                      550,
                      70,
                      _rise(
                        const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 350),
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _outlined(
                              great
                                  ? '${_p.doneLine}!'
                                  : 'Good try! Keep practising!',
                              _baloo(52, Colors.white),
                              const Color(0xFF5A1E08),
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    at(
                      75.5,
                      415,
                      700,
                      700 * 1361 / 939,
                      _Once(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 450),
                        child: FittedBox(child: _endBoard(accuracy)),
                        builder: (t, c) {
                          final e = Curves.easeOutCubic.transform(t);
                          return Opacity(
                            opacity: e,
                            child: Transform.translate(
                              offset: Offset(0, 60 * (1 - e)),
                              child: c,
                            ),
                          );
                        },
                      ),
                    ),
                    for (var i = 0; i < 3; i++)
                      at(
                        i == 1 ? 355 : 425 + 150.0 * (i - 1) - 55,
                        i == 1 ? 282 : 300,
                        i == 1 ? 140 : 110,
                        i == 1 ? 127 : 100,
                        _pop(
                          const Duration(milliseconds: 450),
                          delay: Duration(milliseconds: 950 + 220 * i),
                          _endStar(i < _stars),
                        ),
                      ),
                    at(
                      235.5,
                      1458,
                      380,
                      137,
                      _pop(
                        const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 1700),
                        _ImgBtn(
                          key: const ValueKey('ta-continue'),
                          up: '$_kA/end_continue.png',
                          down: '$_kA/end_continue_down.png',
                          onTap: _finish,
                        ),
                      ),
                    ),
                    at(
                      245.5,
                      1612,
                      360,
                      118,
                      _pop(
                        const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 1820),
                        _ImgBtn(
                          key: const ValueKey('ta-again'),
                          up: '$_kA/end_again.png',
                          down: '$_kA/end_again_down.png',
                          onTap: _goPlay,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const IgnorePointer(child: _Confetti()),
      ],
    );
  }

  /// "Mumtaz!" on the blue water banner (807x223).
  Widget _wEndSign() => FittedBox(
    child: SizedBox(
      width: 807,
      height: 223,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_kA/w_end_top.png', fit: BoxFit.fill),
          ),
          Positioned(
            left: 170,
            right: 170,
            top: 42,
            bottom: 62,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _outlined(
                  'Mumtaz!',
                  _baloo(120, const Color(0xFFFFE31A), height: 1),
                  const Color(0xFF0E3E8C),
                  18,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// The summary board (939x1361): the round's numbers, the five steps done
  /// in order, and the lesson line.
  Widget _endBoard(int accuracy) {
    const ink = Color(0xFF4A1405);
    Widget at(double l, double t, double w, double h, Widget c) =>
        Positioned(left: l, top: t, width: w, height: h, child: c);
    Widget box(List<Color> fill, Color border) => Container(
      decoration: BoxDecoration(
        gradient: _vGrad(fill),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border, width: 5),
      ),
    );
    Widget land(int i, Widget child) => _rise(
      const Duration(milliseconds: 450),
      delay: Duration(milliseconds: 850 + 120 * i),
      child,
    );

    Widget stat(
      double left,
      String value,
      String label,
      List<Color> fill,
      Color border,
      Color valueInk,
    ) => at(
      left,
      140,
      213,
      190,
      Stack(
        fit: StackFit.expand,
        children: [
          box(fill, border),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: _baloo(84, valueInk, height: 1)),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: _baloo(38, ink, height: 1)),
              ),
            ],
          ),
        ],
      ),
    );

    Widget stepRow(int i) {
      final st = _steps[i];
      final top = 360.0 + i * 128;
      return at(
        131,
        top,
        685,
        114,
        land(
          i + 1,
          Stack(
            fit: StackFit.expand,
            children: [
              box(
                i.isEven
                    ? const [Color(0xFFE6FCDD), Color(0xFFD5F8C9)]
                    : const [Color(0xFFDDF2FE), Color(0xFFC9EBFD)],
                i.isEven ? const Color(0xFF6EE265) : const Color(0xFF5CC3F2),
              ),
              Positioned(
                left: 22,
                top: 17,
                width: 80,
                height: 80,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _vGrad(const [
                      Color(0xFF3FCB5E),
                      Color(0xFF1B8C38),
                    ]),
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: Text(
                    '${st.n}',
                    style: _baloo(44, Colors.white, height: 1),
                  ),
                ),
              ),
              Positioned(
                left: 124,
                right: 110,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(st.label, style: _baloo(50, ink)),
                  ),
                ),
              ),
              Positioned(
                right: 26,
                top: 22,
                width: 70,
                height: 70,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cream,
                    border: Border.all(color: _green, width: 5),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _green,
                    size: 50,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 939,
      height: 1361,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_kA/w_end_board.png', fit: BoxFit.fill),
          ),

          Positioned.fill(
            child: land(
              0,
              Stack(
                children: [
                  stat(
                    131,
                    '${_steps.length}/${_steps.length}',
                    'Steps',
                    const [Color(0xFFD9F4FE), Color(0xFFB3E9FC)],
                    const Color(0xFF37B6F0),
                    _blue,
                  ),
                  stat(
                    367,
                    '$_errors',
                    _errors == 1 ? 'Mistake' : 'Mistakes',
                    const [Color(0xFFFEF5D6), Color(0xFFFDEFC5)],
                    const Color(0xFFF8C22A),
                    const Color(0xFFC77A00),
                  ),
                  stat(
                    603,
                    '$accuracy%',
                    'Correct',
                    const [Color(0xFFE6FCDD), Color(0xFFD0F7C3)],
                    const Color(0xFF6EE265),
                    _greenDeep,
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < _steps.length; i++)
            Positioned.fill(child: Stack(children: [stepRow(i)])),
          Positioned.fill(
            child: land(
              6,
              Stack(
                children: [
                  at(
                    131,
                    1010,
                    685,
                    220,
                    CustomPaint(
                      foregroundPainter: const _DashedBorder(
                        color: Color(0xFFE0C99A),
                        width: 5,
                        radius: 30,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _cream,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _p.sessionNo == 2
                                ? 'Wudhu keeps us clean\nand ready for salah.'
                                : 'Your wudhu is complete —\nyou are ready for salah!',
                            textAlign: TextAlign.center,
                            style: _baloo(46, _brown, height: 1.3),
                          ),
                        ),
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
  }
}
