import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

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
    this.onExit,
  });

  final TaharahSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Leaves the lesson from the start screen's back button.
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) => switch (session) {
    TaharahSession.cleanOrDirty => _CleanOrDirty(
      xp: xp,
      onComplete: onComplete,
      onExit: onExit,
    ),
    TaharahSession.wudhuPart1 => _Wudhu(
      part: _kPart1,
      xp: xp,
      onComplete: onComplete,
      onExit: onExit,
    ),
    TaharahSession.wudhuPart2 => _Wudhu(
      part: _kPart2,
      xp: xp,
      onComplete: onComplete,
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
const Color _tan = Color(0xFFE7D3A8);
const Color _tanShadow = Color(0xFFD8C49B);
const Color _brown = Color(0xFF8A5A24);
const Color _ink = Color(0xFF5B4322);
const Color _blue = Color(0xFF1F6FD0);
const Color _navy = Color(0xFF1A4B7E);
const Color _green = Color(0xFF2E9E4B);
const Color _greenTop = Color(0xFF46BF62);
const Color _greenDeep = Color(0xFF1F7436);
const Color _red = Color(0xFFD0442B);
const Color _redInk = Color(0xFFA3341F);
const Color _gold = Color(0xFFFFD97A);
const Color _dotOff = Color(0xFFE7EDF3);

Color _rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a);
Color _night(double a) => _rgba(10, 28, 48, a);

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

/// `background: url(..) center/cover` plus the prototype's tint overlay.
Widget _backdrop(String image, Gradient tint, {double tintOpacity = 1}) =>
    Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(image, fit: BoxFit.cover),
        Opacity(
          opacity: tintOpacity,
          child: DecoratedBox(decoration: BoxDecoration(gradient: tint)),
        ),
      ],
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

/// `<img style="max-height: Hpx; width: auto">` with a drop shadow.
Widget _figure(String asset, double maxH, double dy, double blur, Color c) =>
    ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: _dropShadow(Image.asset(asset, fit: BoxFit.contain), dy, blur, c),
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
Widget _pop(Duration d, Widget child, {Key? key}) => _Once(
  key: key,
  duration: d,
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

/// `tafloat` — bob up 6px and back.
Widget _float(Duration period, Widget child) => _Loop(
  period: period,
  child: child,
  builder: (t, c) => Transform.translate(
    offset: Offset(0, _kf(t, [0, .5, 1], [0, -6, 0], Curves.easeInOut)),
    child: c,
  ),
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
    this.color,
    this.gradient,
    this.shadows = const [],
    this.pressedShadows,
    this.pressDy = 0,
    this.pressScale = 1,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
  });

  final Widget child;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final List<BoxShadow> shadows;
  final List<BoxShadow>? pressedShadows;
  final double pressDy;
  final double pressScale;
  final EdgeInsets padding;
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
        child: Transform.scale(
          scale: _down ? widget.pressScale : 1,
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color,
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: _down
                  ? (widget.pressedShadows ?? widget.shadows)
                  : widget.shadows,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The 44x44 cream HUD buttons (‹ back, ♪ sound).
Widget _hudButton(
  String glyph,
  Color color,
  double size,
  VoidCallback? onTap,
) => _Btn(
  width: 44,
  height: 44,
  radius: 16,
  color: _cream,
  onTap: onTap,
  shadows: const [BoxShadow(color: _tanShadow, offset: Offset(0, 4))],
  pressedShadows: const [BoxShadow(color: _tanShadow, offset: Offset(0, 2))],
  pressDy: 2,
  child: Text(
    glyph,
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      height: 1,
    ),
  ),
);

Widget _hud(String title, VoidCallback onBack, VoidCallback? onSound) =>
    Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            _hudButton('‹', _brown, 20, onBack),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _baloo(
                  22,
                  _cream,
                  shadows: [
                    Shadow(
                      color: _rgba(0, 0, 0, .55),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _hudButton('♪', _blue, 18, onSound),
          ],
        ),
      ),
    );

/// The progress pill under the HUD: label plus a row of dots.
Widget _meter(String label, int total, int filled, Color on) => Positioned(
  left: 16,
  right: 16,
  top: 70,
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
    decoration: BoxDecoration(
      color: _rgba(255, 253, 246, .94),
      border: Border.all(color: _tan, width: 3),
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: _rgba(0, 0, 0, .12),
          offset: const Offset(0, 5),
          blurRadius: 12,
        ),
      ],
    ),
    child: Row(
      children: [
        Text(
          label,
          style: _baloo(14, const Color(0xFF4B5563), ls: .3),
          maxLines: 1,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < filled ? on : _dotOff,
                    ),
                    foregroundDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _vGrad(
                        [_rgba(0, 0, 0, .14), _rgba(0, 0, 0, 0)],
                        const [0, .3],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);

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

/// The navy "what to do" pill shown while no toast is up.
Widget _hintPill(String text, double shadowA, EdgeInsets padding) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: _rgba(26, 75, 126, .9),
    borderRadius: BorderRadius.circular(999),
    boxShadow: [
      BoxShadow(
        color: _rgba(0, 0, 0, shadowA),
        offset: const Offset(0, 4),
        blurRadius: 10,
      ),
    ],
  ),
  child: Text(text, style: _baloo(15, Colors.white, weight: 700)),
);

List<BoxShadow> _lip(Color c, double dy, [double? softDy, double? blur]) => [
  BoxShadow(color: c, offset: Offset(0, dy)),
  if (softDy != null)
    BoxShadow(
      color: _rgba(0, 0, 0, .3),
      offset: Offset(0, softDy),
      blurRadius: blur!,
    ),
];

/// Green full-width CTA shared by every screen.
Widget _greenButton(
  String label,
  VoidCallback onTap, {
  double fontSize = 24,
  double ls = 0,
  EdgeInsets padding = const EdgeInsets.fromLTRB(0, 18, 0, 21),
  double radius = 24,
  List<BoxShadow>? shadows,
  List<BoxShadow>? pressed,
  double pressDy = 3,
}) => _Btn(
  width: double.infinity,
  padding: padding,
  radius: radius,
  gradient: _vGrad(const [_greenTop, _green]),
  shadows: shadows ?? _lip(_greenDeep, 6, 12, 22),
  pressedShadows:
      pressed ??
      [
        const BoxShadow(color: _greenDeep, offset: Offset(0, 3)),
        BoxShadow(
          color: _rgba(0, 0, 0, .3),
          offset: const Offset(0, 8),
          blurRadius: 16,
        ),
      ],
  pressDy: pressDy,
  onTap: onTap,
  child: Text(label, style: _baloo(fontSize, Colors.white, ls: ls)),
);

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
  const _DashedBorder({
    required this.color,
    required this.width,
    this.radius,
    this.pulse,
  });

  final Color color;
  final double width;
  final double? radius;

  /// `taring` progress 0..1, or null when the ring isn't pulsing.
  final double? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (pulse != null) {
      final e = Curves.easeOut.transform(pulse!);
      // box-shadow: 0 0 0 4px white, 0 0 0 16px green — outside the box only.
      void band(double spread, Color c) {
        if (spread <= 0) return;
        final outer = _shapePath(
          r.inflate(spread),
          radius == null ? null : radius! + spread,
        );
        canvas.drawPath(
          Path.combine(PathOperation.difference, outer, _shapePath(r, radius)),
          Paint()..color = c,
        );
      }

      band(16 * e, _rgba(70, 191, 98, .5 * (1 - e)));
      band(4 * e, _rgba(255, 255, 255, .9 + .05 * e));
    }
    final inner = r.deflate(width / 2);
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
      old.pulse != pulse || old.color != color || old.radius != radius;
}

class _ShapeClip extends CustomClipper<Path> {
  const _ShapeClip(this.radius);
  final double? radius;

  @override
  Path getClip(Size size) => _shapePath(Offset.zero & size, radius);

  @override
  bool shouldReclip(_ShapeClip old) => old.radius != radius;
}

/// Back chip on the start screens, so the lesson can be left from there.
Widget _exitChip(VoidCallback onExit) => _hudButton('‹', _brown, 20, onExit);

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

/// Bins: two 168px columns (18px side padding, 18px gap), 6px glow padding
/// around the 1346x1168 art, 26px off the bottom.
const double _kBinW = 168;
const double _kBinH = 12 + 156 * 1168 / 1346;
const double _kBinTop = _kH - 26 - _kBinH;

enum _S1 { start, instruction, game, done, recap }

class _CleanOrDirty extends StatefulWidget {
  const _CleanOrDirty({
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  final VoidCallback? onExit;

  @override
  State<_CleanOrDirty> createState() => _CleanOrDirtyState();
}

class _CleanOrDirtyState extends State<_CleanOrDirty> {
  _S1 _screen = _S1.start;

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

  final _stageKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache(context, [
      '$_kA/start-screen.png',
      '$_kA/bg.png',
      '$_kA/bin-clean.png',
      '$_kA/bin-dirty.png',
      for (final c in _kCards) c.img,
    ]);
  }

  @override
  void dispose() {
    _toastT?.cancel();
    _doneT?.cancel();
    _wrongT?.cancel();
    super.dispose();
  }

  void _go(_S1 s) => setState(() => _screen = s);

  void _newGame() {
    _doneT?.cancel();
    setState(() {
      _screen = _S1.game;
      _sorted.clear();
      _shakes.clear();
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
    bool hit(double left) =>
        p.dx >= left &&
        p.dx <= left + _kBinW &&
        p.dy >= _kBinTop - 40 &&
        p.dy <= _kBinTop + _kBinH;
    if (hit(18)) return 'clean';
    if (hit(18 + _kBinW + 18)) return 'dirty';
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
          (p.dx - _dragFrom.dx).abs() > 5 ||
          (p.dy - _dragFrom.dy).abs() > 5;
      _dragAt = p;
      _hover = _moved ? _binAt(p) : null;
    });
  }

  void _onUp(PointerEvent e) {
    final id = _dragId;
    if (id == null || e.pointer != _dragPointer) return;
    final bin = _moved ? _binAt(_toStage(e.position)) : null;
    final moved = _moved;
    setState(() {
      _dragId = null;
      _dragPointer = null;
      _hover = null;
    });
    final card = _kCards.firstWhere((c) => c.id == id);
    if (bin != null) {
      _resolve(card, bin == 'clean');
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

  void _resolve(_SortCard card, bool clean) {
    if (clean == card.isClean) {
      setState(() => _sorted[card.id] = clean);
      _flash(_Toast(card.msg, '★', good: true));
      if (_sorted.length == _kCards.length) {
        _doneT?.cancel();
        _doneT = Timer(const Duration(milliseconds: 1500), () {
          setState(() {
            _screen = _S1.done;
            _toast = null;
          });
        });
      }
    } else {
      final where = card.isClean ? 'Sparkling Clean' : 'Dirty / Trash';
      setState(() {
        _errors++;
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
        const Duration(milliseconds: 600),
        () => setState(() => _wrong = null),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFEFE3CB),
    child: switch (_screen) {
      _S1.start => _buildStart(),
      _S1.instruction => _buildInstruction(),
      _S1.game => _buildGame(),
      _S1.done => _buildDone(),
      _S1.recap => _buildRecap(),
    },
  );

  // ---- start ----

  Widget _buildStart() {
    const art = Size(853, 1844);
    return ColoredBox(
      color: const Color(0xFFE9DCC4),
      child: LayoutBuilder(
        builder: (context, box) {
          final k = math.max(
            box.maxWidth / art.width,
            box.maxHeight / art.height,
          );
          final w = art.width * k;
          final h = art.height * k;
          final left = (box.maxWidth - w) / 2;
          final top = (box.maxHeight - h) / 2;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('$_kA/start-screen.png', fit: BoxFit.cover),
              Positioned(
                left: left + w * .2,
                top: top + h * .675,
                width: w * .6,
                height: h * .066,
                child: FittedBox(
                  child: _Btn(
                    width: _kW * .6,
                    height: _kH * .066,
                    radius: 0,
                    pressScale: .97,
                    onTap: () => _go(_S1.instruction),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          padding: const EdgeInsets.only(left: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _green,
                            boxShadow: [
                              BoxShadow(
                                color: _rgba(0, 0, 0, .3),
                                offset: const Offset(0, 3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          foregroundDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _vGrad(
                              [_rgba(0, 0, 0, 0), _rgba(0, 0, 0, .25)],
                              const [.9, .9],
                            ),
                          ),
                          child: const Text(
                            '▶',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'START',
                          style: _baloo(
                            36,
                            const Color(0xFFFFFAF0),
                            ls: 2,
                            height: 1,
                            shadows: [
                              const Shadow(
                                color: Color(0xFF7C4A1C),
                                offset: Offset(0, 3),
                              ),
                              Shadow(
                                color: _rgba(0, 0, 0, .35),
                                offset: const Offset(0, 6),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.onExit != null)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _exitChip(widget.onExit!),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---- instruction ----

  Widget _buildInstruction() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _backdrop(
          '$_kA/bg.png',
          _vGrad([_rgba(24, 44, 66, .35), _rgba(24, 44, 66, .6)]),
        ),
        _stage(
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 44, 26, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _rise(
                  const Duration(milliseconds: 450),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 7,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF144D94),
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'SESSION 1',
                          style: _baloo(15, Colors.white, weight: 700, ls: .5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Clean or\nDirty?',
                        textAlign: TextAlign.center,
                        style: _baloo(
                          40,
                          Colors.white,
                          height: 1.05,
                          shadows: [
                            const Shadow(
                              color: Color(0xFF14406E),
                              offset: Offset(0, 4),
                            ),
                            Shadow(
                              color: _rgba(0, 0, 0, .4),
                              offset: const Offset(0, 8),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                _rise(
                  const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 80),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                    decoration: BoxDecoration(
                      color: _cream,
                      border: Border.all(color: _tan, width: 4),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: _rgba(0, 0, 0, .28),
                          offset: const Offset(0, 12),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drag each card into the correct bin!',
                          style: _baloo(23, const Color(0xFFB45309)),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            style: _nunito(
                              16,
                              const Color(0xFF4B5563),
                              weight: 600,
                              height: 1.45,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Sort good clean habits into ',
                              ),
                              TextSpan(
                                text: 'Sparkling Clean',
                                style: _nunito(16, _green, weight: 800),
                              ),
                              const TextSpan(text: ', and dirty things into '),
                              TextSpan(
                                text: 'Dirty / Trash',
                                style: _nunito(16, _red, weight: 800),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomPaint(
                          painter: const _DashedLine(Color(0xFFEADFC4), 2),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFE8F3FF),
                                  ),
                                  child: const Text(
                                    '♪',
                                    style: TextStyle(
                                      color: _blue,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Tap any card to hear it read aloud',
                                  style: _nunito(14, const Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _float(
                      const Duration(milliseconds: 3400),
                      _figure(
                        '$_kA/throw_trash.png',
                        240,
                        12,
                        14,
                        _rgba(0, 0, 0, .3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _greenButton(
                  'PLAY ▶',
                  _newGame,
                  fontSize: 27,
                  ls: 1,
                  shadows: _lip(_greenDeep, 7, 14, 22),
                  pressed: _lip(_greenDeep, 3),
                  pressDy: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- game ----

  Widget _buildGame() {
    final count = _sorted.length;
    final dragging = _dragId != null && _moved;
    final cleanN = _sorted.values.where((v) => v).length;
    final dirtyN = _sorted.values.where((v) => !v).length;
    return Stack(
      fit: StackFit.expand,
      children: [
        _backdrop(
          '$_kA/bg.png',
          _vGrad([_night(.52), _night(.4), _night(.58)], const [0, .55, 1]),
        ),
        _stage(
          key: _stageKey,
          Listener(
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onUp,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _hud('Clean or Dirty?', () => _go(_S1.start), null),
                _meter('Cleanliness Meter', _kCards.length, count, _green),
                Positioned(left: 16, right: 16, top: 122, child: _tray()),
                if (_toast == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 430,
                    child: IgnorePointer(
                      child: Center(
                        child: _hintPill(
                          'Drag a card down into a bin',
                          .2,
                          const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 18,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 424,
                    child: _toastCard(_toast!, key: ValueKey('toast$_toastN')),
                  ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 26,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _bin(
                          'clean',
                          '$_kA/bin-clean.png',
                          _rgba(70, 191, 98, .45),
                          cleanN,
                          _green,
                          _greenDeep,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _bin(
                          'dirty',
                          '$_kA/bin-dirty.png',
                          _rgba(208, 68, 43, .4),
                          dirtyN,
                          _red,
                          _redInk,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dragging)
                  Positioned(
                    left: _dragAt.dx - 52,
                    top: _dragAt.dy - 52,
                    child: IgnorePointer(child: _ghost()),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tray() {
    Widget row(int from) => Row(
      children: [
        for (var i = from; i < from + 3; i++) ...[
          if (i > from) const SizedBox(width: 10),
          Expanded(child: _trayCard(_kCards[i])),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _rgba(255, 253, 246, .55),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _rgba(255, 255, 255, .7), width: 2),
        boxShadow: [
          BoxShadow(
            color: _rgba(0, 0, 0, .1),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(children: [row(0), const SizedBox(height: 10), row(3)]),
    );
  }

  Widget _trayCard(_SortCard c) {
    final sorted = _sorted.containsKey(c.id);
    final n = _shakes[c.id] ?? 0;
    final face = Container(
      height: 98,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tan, width: 2),
        boxShadow: const [BoxShadow(color: _tanShadow, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Expanded(child: Image.asset(c.img, fit: BoxFit.contain)),
          const SizedBox(height: 3),
          Text(
            c.label,
            textAlign: TextAlign.center,
            style: _nunito(10.5, _ink, weight: 800, height: 1.1),
          ),
        ],
      ),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: sorted ? 0 : (_dragId == c.id && _moved ? .25 : 1),
      child: IgnorePointer(
        ignoring: sorted,
        child: Listener(
          key: ValueKey('ta-card-${c.id}'),
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

  Widget _bin(
    String id,
    String art,
    Color glow,
    int count,
    Color ring,
    Color ink,
  ) {
    final on = _hover == id;
    return Center(
      key: ValueKey('ta-bin-$id'),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: on ? 1.08 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _kBinW,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: on ? glow : glow.withAlpha(0),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _dropShadow(Image.asset(art), 8, 10, _rgba(0, 0, 0, .28)),
              if (count > 0)
                Positioned(
                  right: _kBinW * .16 - 6,
                  top: _kBinH * .26 - 6,
                  child: _pop(
                    const Duration(milliseconds: 300),
                    Container(
                      constraints: const BoxConstraints(minWidth: 30),
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: ring, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _rgba(0, 0, 0, .25),
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text('$count', style: _baloo(16, ink, height: 1)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ghost() {
    final c = _kCards.firstWhere((c) => c.id == _dragId);
    return Transform.rotate(
      angle: -4 * math.pi / 180,
      child: Transform.scale(
        scale: 1.06,
        child: Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0B64C), width: 3),
            boxShadow: [
              BoxShadow(
                color: _rgba(0, 0, 0, .35),
                offset: const Offset(0, 16),
                blurRadius: 26,
              ),
            ],
          ),
          child: Image.asset(c.img, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // ---- done ----

  Widget _buildDone() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _backdrop(
          '$_kA/bg.png',
          _vGrad([_rgba(31, 111, 208, .5), _rgba(20, 64, 110, .72)]),
        ),
        _stage(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pop(
                  const Duration(milliseconds: 500),
                  Text(
                    'MUMTAZ!',
                    style: _baloo(
                      54,
                      const Color(0xFFFFD233),
                      ls: 1,
                      shadows: [
                        const Shadow(
                          color: Color(0xFFB4640D),
                          offset: Offset(0, 5),
                        ),
                        Shadow(
                          color: _rgba(0, 0, 0, .4),
                          offset: const Offset(0, 10),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _float(
                  const Duration(seconds: 3),
                  Container(
                    width: 132,
                    height: 132,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _vGrad(const [
                        Color(0xFFFFE07A),
                        Color(0xFFF0A91F),
                      ]),
                      boxShadow: [
                        const BoxShadow(
                          color: Color(0xFFB4640D),
                          offset: Offset(0, 10),
                        ),
                        BoxShadow(
                          color: _rgba(0, 0, 0, .35),
                          offset: const Offset(0, 18),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: const Text(
                      '★',
                      style: TextStyle(fontSize: 62, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 26,
                  ),
                  decoration: BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFCBB894), offset: Offset(0, 6)),
                    ],
                  ),
                  child: Text('Cleanliness Hero!', style: _baloo(24, _navy)),
                ),
                const SizedBox(height: 14),
                Text(
                  'You sorted all 6 cards.\nSession 1 complete.',
                  textAlign: TextAlign.center,
                  style: _nunito(17, const Color(0xFFEAF4FF), height: 1.5),
                ),
                const SizedBox(height: 30),
                _Btn(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(0, 18, 0, 21),
                  radius: 24,
                  gradient: _vGrad(const [
                    Color(0xFFFFD95E),
                    Color(0xFFF0A91F),
                  ]),
                  shadows: _lip(const Color(0xFFB4640D), 7, 14, 22),
                  pressedShadows: _lip(const Color(0xFFB4640D), 3),
                  pressDy: 4,
                  onTap: () => _go(_S1.recap),
                  child: Text(
                    'SEE WHAT YOU LEARNED',
                    style: _baloo(25, const Color(0xFF6B3A05)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- recap ----

  Widget _buildRecap() {
    Widget section(
      String title,
      Color head,
      Color border,
      Color ink,
      bool clean,
    ) {
      final items = _kCards.where((c) => c.isClean == clean).toList();
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: head,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                child: Text(title, style: _baloo(19, Colors.white)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var j = i; j < i + 2; j++) ...[
                            if (j > i) const SizedBox(width: 10),
                            Expanded(
                              child: j < items.length
                                  ? Row(
                                      children: [
                                        Image.asset(
                                          items[j].img,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            items[j].label,
                                            style: _nunito(
                                              14,
                                              ink,
                                              weight: 800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFFF6ECD6),
      child: _stage(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What You Learned',
                textAlign: TextAlign.center,
                style: _baloo(30, _navy),
              ),
              const SizedBox(height: 18),
              section(
                'Sparkling Clean',
                _green,
                const Color(0xFFBFE0C7),
                const Color(0xFF3F4B3F),
                true,
              ),
              const SizedBox(height: 14),
              section(
                'Dirty / Trash',
                _red,
                const Color(0xFFF0CFC7),
                const Color(0xFF4B3F3F),
                false,
              ),
              const SizedBox(height: 16),
              CustomPaint(
                foregroundPainter: const _DashedBorder(
                  color: Color(0xFFE0C99A),
                  width: 3,
                  radius: 20,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Clean habits make us healthy.\nTaharah is part of our faith.',
                    textAlign: TextAlign.center,
                    style: _baloo(18, _brown, height: 1.35),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 18),
              _greenButton(
                '↻ Play Again',
                _newGame,
                fontSize: 22,
                radius: 22,
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 19),
                shadows: _lip(_greenDeep, 6),
                pressed: _lip(_greenDeep, 3),
              ),
              const SizedBox(height: 10),
              _Btn(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 19),
                radius: 22,
                gradient: _vGrad(const [Color(0xFF4B95E6), _blue]),
                shadows: _lip(const Color(0xFF144D94), 6),
                pressedShadows: _lip(const Color(0xFF144D94), 3),
                pressDy: 3,
                onTap: _finish,
                child: Text(
                  '→ Next Session: Wudhu',
                  style: _baloo(22, Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLine extends CustomPainter {
  const _DashedLine(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final y = width / 2;
    canvas.drawPath(
      _dashed(
        Path()
          ..moveTo(0, y)
          ..lineTo(size.width, y),
        width * 3,
        width * 3,
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_DashedLine old) => false;
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

/// A tap zone or hint ring on the figure. [rect] is a fraction of the
/// figure box; [radius] null means `border-radius: 50%`.
class _Zone {
  const _Zone(this.id, this.rect, [this.radius]);
  final String id;
  final Rect rect;
  final double? radius;
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
      'arms',
      5,
      'Wash Arms',
      'arms',
      '$_kA/boy-arms.png',
      'Mumtaz! Arms washed. Part 1 complete!',
    ),
  ],
  zones: [
    _Zone('face', Rect.fromLTWH(.27, .12, .46, .24)),
    _Zone('arms', Rect.fromLTWH(.205, .535, .14, .095), 40),
    _Zone('arms', Rect.fromLTWH(.655, .535, .14, .095), 40),
    _Zone('hands', Rect.fromLTWH(.185, .605, .63, .09), 40),
    _Zone('nose', Rect.fromLTWH(.43, .24, .14, .05)),
    _Zone('mouth', Rect.fromLTWH(.41, .29, .18, .065), 999),
  ],
  rings: [
    _Zone('hands', Rect.fromLTWH(.19, .605, .12, .085)),
    _Zone('hands', Rect.fromLTWH(.68, .605, .12, .085)),
    _Zone('mouth', Rect.fromLTWH(.42, .288, .16, .065), 999),
    _Zone('nose', Rect.fromLTWH(.445, .238, .11, .05)),
    _Zone('face', Rect.fromLTWH(.275, .125, .45, .23)),
    _Zone('arms', Rect.fromLTWH(.215, .54, .12, .09), 40),
    _Zone('arms', Rect.fromLTWH(.665, .54, .12, .09), 40),
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
  instructBoy: '$_kA/boy-cheer5.png',
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
  zones: [
    _Zone('left_arm', Rect.fromLTWH(.65, .535, .14, .155), 40),
    _Zone('head', Rect.fromLTWH(.29, .035, .42, .14)),
    _Zone('ears', Rect.fromLTWH(.20, .18, .09, .07)),
    _Zone('ears', Rect.fromLTWH(.705, .18, .09, .07)),
    _Zone('right_foot', Rect.fromLTWH(.25, .845, .20, .11), 40),
    _Zone('left_foot', Rect.fromLTWH(.54, .845, .20, .11), 40),
  ],
  rings: [
    _Zone('left_arm', Rect.fromLTWH(.665, .545, .12, .14), 40),
    _Zone('head', Rect.fromLTWH(.30, .04, .40, .13)),
    _Zone('ears', Rect.fromLTWH(.21, .185, .07, .06)),
    _Zone('ears', Rect.fromLTWH(.715, .185, .07, .06)),
    _Zone('right_foot', Rect.fromLTWH(.26, .85, .18, .10), 40),
    _Zone('left_foot', Rect.fromLTWH(.55, .85, .18, .10), 40),
  ],
);

/// Figure box: `top: 150px; bottom: 108px; aspect-ratio: 1024 / 1536`.
const double _kFigTop = 150;
const double _kFigH = _kH - 150 - 108;
const double _kFigW = _kFigH * 1024 / 1536;

enum _WScreen { start, instruct, play, done }

class _Wudhu extends StatefulWidget {
  const _Wudhu({
    required this.part,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final _WPart part;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  final VoidCallback? onExit;

  @override
  State<_Wudhu> createState() => _WudhuState();
}

class _WudhuState extends State<_Wudhu> {
  _WScreen _screen = _WScreen.start;
  int _idx = 0;
  String? _pose;
  _Toast? _toast;
  int _toastN = 0;
  int _shakeN = 0;
  bool _wipe = false;
  int _wipeN = 0;
  int _errors = 0;
  Timer? _toastT, _doneT, _poseT, _wipeT, _wipeT2;

  _WPart get _p => widget.part;
  List<_WStep> get _steps => _p.steps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache(context, [
      '$_kA/s2-bg.png',
      '$_kA/boy-stand.png',
      '$_kA/boy-celebrate.png',
      _p.startBoy,
      _p.instructBoy,
      for (final s in _steps) s.pose,
    ]);
  }

  @override
  void dispose() {
    for (final t in [_toastT, _doneT, _poseT, _wipeT, _wipeT2]) {
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
    _wipeT?.cancel();
    setState(() {
      _wipe = true;
      _wipeN++;
    });
    _wipeT = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _reset();
        _screen = _WScreen.play;
      });
      _wipeT2 = Timer(
        const Duration(milliseconds: 340),
        () => setState(() => _wipe = false),
      );
    });
  }

  void _replay() => setState(() {
    _reset();
    _screen = _WScreen.play;
  });

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
          () => setState(() => _screen = _WScreen.done),
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
          switch (_screen) {
            _WScreen.start => _buildStart(),
            _WScreen.instruct => _buildInstruct(),
            _WScreen.play => _buildPlay(),
            _WScreen.done => _buildDone(),
          },
          if (_wipe) _buildWipe(),
        ],
      ),
    );
  }

  Widget _buildWipe() => LayoutBuilder(
    builder: (context, box) {
      // radial-gradient(circle at 50% 45%, ...) — farthest-corner radius.
      final r = math.sqrt(
        math.pow(box.maxWidth / 2, 2) + math.pow(box.maxHeight * .55, 2),
      );
      return AbsorbPointer(
        child: _Once(
          key: ValueKey('wipe$_wipeN'),
          duration: const Duration(milliseconds: 640),
          builder: (t, child) => Opacity(
            opacity: _kf(t, [0, .45, .6, 1], [0, 1, 1, 0]),
            child: child,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.1),
                radius: r / math.min(box.maxWidth, box.maxHeight),
                colors: const [Color(0xFF17324F), Color(0xFF0B1420)],
              ),
            ),
          ),
        ),
      );
    },
  );

  // ---- start ----

  Widget _buildStart() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _backdrop(
          '$_kA/s2-bg.png',
          _vGrad([_night(.62), _night(.48), _night(.7)], const [0, .45, 1]),
        ),
        _stage(
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 54, 26, 32),
                child: Column(
                  children: [
                    Text(
                      'Session ${_p.sessionNo} · Stage ${_p.stage}'
                          .toUpperCase(),
                      style: _baloo(15, _gold, ls: 2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _p.title.replaceFirst(' ', '\n'),
                      textAlign: TextAlign.center,
                      style: _baloo(
                        38,
                        _cream,
                        height: 1.05,
                        shadows: [
                          Shadow(
                            color: _rgba(0, 0, 0, .5),
                            offset: const Offset(0, 3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        color: _rgba(255, 253, 246, .94),
                        border: Border.all(color: _tan, width: 3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_p.range, style: _baloo(16, _brown)),
                    ),
                    Expanded(
                      child: Center(
                        child: _figure(
                          _p.startBoy,
                          330,
                          16,
                          18,
                          _rgba(0, 0, 0, .4),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _rgba(255, 253, 246, .94),
                        border: Border.all(color: _tan, width: 3),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        _p.goal,
                        textAlign: TextAlign.center,
                        style: _nunito(15, _ink, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _greenButton(
                      'Play',
                      () => setState(() => _screen = _WScreen.instruct),
                    ),
                  ],
                ),
              ),
              if (widget.onExit != null)
                Positioned(left: 16, top: 16, child: _exitChip(widget.onExit!)),
            ],
          ),
        ),
      ],
    );
  }

  // ---- instructions ----

  Widget _buildInstruct() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _backdrop('$_kA/s2-bg.png', _vGrad([_night(.6), _night(.68)])),
        _stage(
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 44, 26, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _rgba(255, 253, 246, .96),
                    border: Border.all(color: _tan, width: 3),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: _rgba(0, 0, 0, .28),
                        offset: const Offset(0, 10),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _blue,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF14508F),
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          '♪',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _p.instruction,
                          style: _baloo(19, _navy, height: 1.25),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _steps.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _stepTile(_steps[i])),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _figure(
                      _p.instructBoy,
                      300,
                      14,
                      16,
                      _rgba(0, 0, 0, .36),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _greenButton(_p.playLabel, _goPlay),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepTile(_WStep s) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    decoration: BoxDecoration(
      color: _rgba(255, 253, 246, .9),
      border: Border.all(color: _tan, width: 2),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _green,
          ),
          child: Text('${s.n}', style: _baloo(14, Colors.white, height: 1)),
        ),
        const SizedBox(height: 4),
        Text(
          s.label,
          textAlign: TextAlign.center,
          style: _nunito(10, _ink, weight: 800, height: 1.15),
        ),
      ],
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
          _backdrop(
            '$_kA/s2-bg.png',
            _vGrad([_night(.42), _night(.14), _night(.1)], const [0, .45, 1]),
            tintOpacity: .5,
          ),
          _stage(
            Stack(
              children: [
                _hud(_p.title, _goStart, () {}),
                _meter('Wudhu Progress', _steps.length, _idx, _greenTop),
                Positioned(
                  left: (_kW - _kFigW) / 2,
                  top: _kFigTop,
                  width: _kFigW,
                  height: _kFigH,
                  child: _toast != null && !_toast!.good
                      ? _shake(
                          const Duration(milliseconds: 400),
                          _figureBox(),
                          key: ValueKey('shake$_shakeN'),
                          times: _shakeN,
                        )
                      : _figureBox(),
                ),
                Positioned(
                  left: 16,
                  top: 122,
                  width: 148,
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
                  bottom: 44,
                  child: _toast != null
                      ? _toastCard(
                          _toast!,
                          key: ValueKey('toast$_toastN'),
                          wudhu: true,
                        )
                      : IgnorePointer(
                          child: Center(
                            child: _hintPill(
                              'Tap the glowing part on the boy',
                              .24,
                              const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 20,
                              ),
                            ),
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

  Widget _stepCard(_WStep cur) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: _rgba(31, 111, 208, .94),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: _rgba(0, 0, 0, .28),
          offset: const Offset(0, 6),
          blurRadius: 14,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${math.min(_idx + 1, _steps.length)} of ${_steps.length}',
          style: _baloo(13, _gold),
        ),
        Text(cur.label, style: _baloo(21, _cream, height: 1.1)),
        const SizedBox(height: 4),
        Text(
          _idx == 0
              ? _p.firstAsk
              : _idx == _steps.length - 1
              ? _p.lastAsk
              : 'What should I wash next?',
          style: _nunito(12, _rgba(255, 253, 246, .85)),
        ),
      ],
    ),
  );

  Widget _figureBox() {
    final posing = _pose != null;
    final active = _idx < _steps.length ? _steps[_idx].id : null;
    final shadow = _rgba(60, 45, 25, .35);
    Rect px(Rect f) => Rect.fromLTWH(
      f.left * _kFigW,
      f.top * _kFigH,
      f.width * _kFigW,
      f.height * _kFigH,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ground shadow: radial ellipse, farthest-corner, fading out by 70%.
        Positioned(
          left: _kFigW * .12,
          bottom: -_kFigH * .015,
          width: _kFigW * .76,
          height: _kFigH * .05,
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
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 340),
              opacity: posing ? 0 : 1,
              child: _dropShadow(
                Image.asset(
                  '$_kA/boy-stand.png',
                  fit: BoxFit.contain,
                  width: _kFigW,
                  height: _kFigH,
                ),
                10,
                8,
                shadow,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 340),
              opacity: posing ? 1 : 0,
              child: posing
                  ? _dropShadow(
                      Image.asset(
                        _pose!,
                        fit: BoxFit.contain,
                        width: _kFigW,
                        height: _kFigH,
                      ),
                      10,
                      8,
                      shadow,
                    )
                  : const SizedBox.shrink(),
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
              clipper: _ShapeClip(z.radius),
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
                          painter: _ring(r.radius, t),
                          size: Size.infinite,
                        ),
                      )
                    : CustomPaint(
                        painter: _ring(r.radius, null),
                        size: Size.infinite,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  _DashedBorder _ring(double? radius, double? pulse) => _DashedBorder(
    color: _rgba(255, 253, 246, .95),
    width: 3,
    radius: radius,
    pulse: pulse,
  );

  // ---- done ----

  Widget _buildDone() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _backdrop(
          '$_kA/s2-bg.png',
          _vGrad([_rgba(31, 111, 208, .62), _rgba(20, 64, 110, .76)]),
        ),
        _stage(
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 40, 26, 30),
            child: Column(
              children: [
                _pop(
                  const Duration(milliseconds: 400),
                  Text(
                    'Mumtaz!',
                    style: _baloo(
                      34,
                      _gold,
                      shadows: [
                        Shadow(
                          color: _rgba(0, 0, 0, .45),
                          offset: const Offset(0, 3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  _p.doneLine,
                  textAlign: TextAlign.center,
                  style: _baloo(20, _cream),
                ),
                const SizedBox(height: 8),
                _figure(
                  '$_kA/boy-celebrate.png',
                  210,
                  14,
                  16,
                  _rgba(0, 0, 0, .4),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _rgba(255, 253, 246, .96),
                    border: Border.all(color: _tan, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _steps.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _doneRow(_steps[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _greenButton(
                  'Play Again',
                  _replay,
                  fontSize: 21,
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 19),
                  shadows: _lip(_greenDeep, 5),
                  pressed: _lip(_greenDeep, 2),
                ),
                const SizedBox(height: 10),
                _Btn(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 17),
                  radius: 22,
                  gradient: _vGrad(const [_gold, Color(0xFFF0B64C)]),
                  shadows: _lip(const Color(0xFFC8912F), 5),
                  pressedShadows: _lip(const Color(0xFFC8912F), 2),
                  pressDy: 3,
                  onTap: _finish,
                  child: Text(
                    'Next Session →',
                    style: _baloo(19, const Color(0xFF6B4413)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _doneRow(_WStep s) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F1E2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _blue),
          child: Text('${s.n}', style: _baloo(14, Colors.white, height: 1)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(s.label, style: _nunito(15, _ink, weight: 800))),
        const Text(
          '✓',
          style: TextStyle(
            color: _green,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
