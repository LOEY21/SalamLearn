import 'package:salamlearn/logic/localization/app_translations.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import 'tutorial_anchors.dart';
import 'tutorial_step.dart';

/// Full-screen first-run tutorial: Amir walks the learner through the
/// Adventure Map's top bar, their own avatar, the Backpack tab, and the
/// current lesson node, one spotlighted beat at a time, then cheers and
/// dismisses itself.
///
/// Ported from the approved `dumps/mascot_tutorial_preview_mock.html`
/// motion preview — same beat sheet, same dim/spotlight/pop-in/pop-out
/// timings. Two motion rules from that approval carry over directly:
/// - Side changes (left/right/center) never slide the mascot across the
///   screen — that read as nauseating horizontal panning. Only entrance/
///   exit pop is animated; the side itself is an instant cut.
/// - Exit uses its own faster, accelerate-only curve, never the springy
///   entrance curve played in reverse.
class MascotTutorialOverlay extends ConsumerStatefulWidget {
  const MascotTutorialOverlay({
    super.key,
    required this.learnerName,
    required this.onFinished,
    this.isGirl = false,
  });

  final String learnerName;
  final VoidCallback onFinished;

  /// Picks the `assets/images/mascot/girl/` pose set and the "Amira" name
  /// tag instead of the boy's — driven by the learner's chosen avatar
  /// (`'girl_mascot'`), not a runtime image mirror of the boy set.
  final bool isGirl;

  /// Inserts the tutorial above everything (map, top bar, bottom nav) via
  /// the root [Overlay] — the Learner Hub's Scaffold puts its bottom nav
  /// and body in separate slots that never overlap, so this is the only
  /// way one overlay can dim/spotlight across both at once.
  static void show(
    BuildContext context, {
    required String learnerName,
    required VoidCallback onFinished,
    bool isGirl = false,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => MascotTutorialOverlay(
        learnerName: learnerName,
        isGirl: isGirl,
        onFinished: () {
          entry.remove();
          onFinished();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  @override
  ConsumerState<MascotTutorialOverlay> createState() =>
      _MascotTutorialOverlayState();
}

class _MascotTutorialOverlayState extends ConsumerState<MascotTutorialOverlay>
    with TickerProviderStateMixin {
  static const _springCurve = Cubic(0.34, 1.56, 0.64, 1.0);
  static const _accelerateCurve = Cubic(0.4, 0, 1, 1);
  static const _dimAlpha = 0.74;
  // Reserved fraction of screen height below the bubble's `top` for its
  // own content plus the nav bar beneath it — a low-docked mascot
  // (leftOfTarget, centered on the map avatar near the bottom of the
  // screen) could otherwise push the bubble's `top` low enough that its
  // full height ran into the very avatar/nav-bar area it's meant to leave
  // visible. Expressed as a fraction, not a fixed px budget, so it scales
  // sanely on small screens/windows instead of clamping the same ~300px
  // no matter how short the screen actually is.
  static const _bubbleBottomReserveFraction = 0.32;
  static const _mascotDefaultBottomFraction = 0.13;

  late final List<TutorialStep> _steps = buildTutorialSteps(
    widget.learnerName,
    isGirl: widget.isGirl,
  );

  int _stepIdx = 0;
  int _lineIdx = 0;
  bool _exiting = false;

  Rect? _displayedRect;
  double _displayedDimAlpha = 0;
  RectTween? _rectTween;
  Tween<double>? _alphaTween;

  /// Distance from the bottom of the screen to dock the mascot for the
  /// current step — recomputed per step in [_enterStep] from the real
  /// spotlighted rect, not a fixed screen fraction. The map avatar and
  /// current-node anchors sit wherever the map happens to be scrolled to,
  /// which is often the same lower-right area the mascot would otherwise
  /// default to — docking fixed there meant Amir stood directly on top of
  /// the very thing he was pointing at (same chibi-boy art style, so it
  /// read as one overlapping blob, not "mascot points at target").
  double _mascotBottom = 0;

  late final _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _ringPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  late final _mascotPop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final _mascotExit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final _bubblePop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final _bubbleExit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final _lineFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );

  Timer? _bubbleDelay;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _enterStep(isFirst: true),
    );
  }

  @override
  void dispose() {
    _bubbleDelay?.cancel();
    _autoDismiss?.cancel();
    _transition.dispose();
    _ringPulse.dispose();
    _mascotPop.dispose();
    _mascotExit.dispose();
    _bubblePop.dispose();
    _bubbleExit.dispose();
    _lineFade.dispose();
    super.dispose();
  }

  TutorialStep get _step => _steps[_stepIdx];

  Rect? _measure(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final overlayBox = context.findRenderObject() as RenderBox?;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & box.size;
  }

  void _enterStep({required bool isFirst}) {
    final anchors = ref.read(tutorialAnchorsProvider);
    final step = _step;
    final anchorKey = step.anchorOf?.call(anchors);
    final targetRect = anchorKey == null ? null : _padded(_measure(anchorKey));
    // One constant dark level for every step — a spotlight is only
    // legible against a background that's reliably dark, and varying it
    // (lighter for the ambient/no-anchor beats) read as the tutorial
    // randomly losing focus rather than a deliberate "just looking
    // around" moment.
    const targetAlpha = _dimAlpha;

    final screenSize = MediaQuery.of(context).size;
    final (boxHeight, _) = _mascotBoxSize(screenSize, step.dock);

    setState(() {
      _rectTween = RectTween(begin: _displayedRect, end: targetRect);
      _alphaTween = Tween<double>(begin: _displayedDimAlpha, end: targetAlpha);
      _displayedRect = targetRect;
      _displayedDimAlpha = targetAlpha;
      _lineIdx = 0;
      _mascotBottom = _mascotBottomFor(
        step.dock,
        targetRect,
        screenSize,
        boxHeight,
      );
    });
    _transition.forward(from: 0);

    _mascotPop.forward(from: 0);

    _bubblePop.value = 0;
    _bubbleDelay?.cancel();
    _bubbleDelay = Timer(Duration(milliseconds: isFirst ? 380 : 120), () {
      if (mounted) _bubblePop.forward();
    });

    _lineFade.value = 1;

    if (step.isFinal) {
      _autoDismiss?.cancel();
      _autoDismiss = Timer(const Duration(milliseconds: 2200), _finish);
    }
  }

  Rect? _padded(Rect? r) {
    if (r == null) return null;
    return r.inflate(10);
  }

  /// (height, width) of the mascot's box for this screen size — shared by
  /// [_enterStep]'s dock-position math and [_buildMascot]'s layout so the
  /// two never disagree about how tall the mascot actually is.
  ///
  (double, double) _mascotBoxSize(
    Size size, [
    MascotDock dock = MascotDock.auto,
  ]) {
    final boxHeight = math.min(size.height * 0.42, 360.0);
    return (boxHeight, boxHeight * 0.82);
  }

  /// How far up from the bottom of the screen to dock the mascot for a
  /// step. With no spotlighted anchor, it's the default near-bottom dock.
  /// With one:
  /// - [MascotDock.aboveTarget] hugs the anchor's top edge (a small fixed
  ///   gap) — used only for the Backpack tab and current map node, both
  ///   with plenty of room above them.
  /// - [MascotDock.auto] hugs the anchor's *bottom* edge instead — used
  ///   only by the streak/energy top-bar pills, which sit right at the
  ///   very top of the screen with essentially no room above them.
  ///   Hugging "above" there forced the mascot's whole ~40%-tall box into
  ///   a vertical band that necessarily included the pill itself, so his
  ///   head/shoulder painted right over it — and the pose is "point up"
  ///   toward the pill anyway, which only reads correctly standing below.
  /// - [MascotDock.leftOfTarget] centers vertically on the anchor instead
  ///   of hugging either edge — he's standing beside it, not above/below.
  ///
  /// Either hug uses a floor/ceiling that only guarantees "stay on
  /// screen" — never one tight enough to silently override the hug back
  /// toward the middle of the screen, which was the bug that made the
  /// Backpack/current-node beats read as floating far from their target.
  double _mascotBottomFor(
    MascotDock dock,
    Rect? targetRect,
    Size screenSize,
    double boxHeight,
  ) {
    if (targetRect == null) {
      return screenSize.height * _mascotDefaultBottomFraction;
    }

    const absoluteFloor = 24.0;
    final ceiling = screenSize.height - boxHeight - 12;
    final clampMax = math.max(absoluteFloor, ceiling);
    const gap = 14.0;

    switch (dock) {
      case MascotDock.leftOfTarget:
        final centeredOnTarget =
            screenSize.height - targetRect.center.dy - boxHeight / 2;
        return centeredOnTarget.clamp(absoluteFloor, clampMax);
      case MascotDock.aboveTarget:
        // Strong overlap so his feet visually plant on the target's top
        // edge — the pose art itself has transparent padding below the
        // feet inside its own box, so even a flush box-to-box touch still
        // reads as a gap; this pulls hard enough to cancel that out.
        final huggingAbove =
            screenSize.height - targetRect.top - boxHeight * 0.22;
        return huggingAbove.clamp(absoluteFloor, clampMax);
      case MascotDock.auto:
      case MascotDock.belowTarget:
        final huggingBelow =
            screenSize.height - boxHeight - targetRect.bottom - gap;
        return huggingBelow.clamp(absoluteFloor, clampMax);
    }
  }

  void _advance() {
    if (_exiting) return;
    final step = _step;
    if (_lineIdx < step.lines.length - 1) {
      _lineFade.reverse().whenComplete(() {
        if (!mounted) return;
        setState(() => _lineIdx++);
        _lineFade.forward();
      });
      return;
    }
    if (_stepIdx < _steps.length - 1) {
      setState(() => _stepIdx++);
      _enterStep(isFirst: false);
    }
  }

  void _finish() {
    if (_exiting) return;
    _exiting = true;
    _autoDismiss?.cancel();
    _mascotExit.forward(from: 0);
    _bubbleExit.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final step = _step;
    final showSkip = _stepIdx >= 1 && !step.isFinal && !_exiting;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_transition, _ringPulse]),
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_transition.value);
                final rect = _rectTween?.transform(t);
                final alpha = _alphaTween?.transform(t) ?? _dimAlpha;
                return CustomPaint(
                  size: Size.infinite,
                  painter: _SpotlightPainter(
                    rect: rect,
                    dimAlpha: alpha,
                    pulseT: _ringPulse.value,
                  ),
                );
              },
            ),
            _buildMascot(size, step),
            _buildBubble(size, step),
            if (showSkip)
              Positioned(
                right: 16,
                bottom: size.height * 0.135,
                child: GestureDetector(
                  onTap: _finish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('Skip ▸',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Where the mascot's box sits for this step — shared by [_buildMascot]
  /// (which paints it) and [_buildBubble] (which anchors beside it, so the
  /// message always reads as "coming from" the mascot no matter which dock
  /// mode placed him).
  double _mascotLeft(Size size, TutorialStep step, double boxWidth) {
    // Expressed as `left` only (not left-or-right) so the anchored branch
    // can do one consistent piece of arithmetic — hug whichever side of
    // the real target has room, instead of bleeding off a fixed screen
    // edge that can leave a wide, disconnected-looking gap from the
    // target itself.
    // The girl mascot's streak-pill beat reads as clipped when its box is
    // allowed to bleed off the right edge like the other poses — keep it
    // fully on-screen instead. Boy mascot keeps the original bleed.
    final edgeBleed = widget.isGirl && step.pose == MascotPose.pointUpLeft
        ? 0.0
        : -0.11;
    final leftEdge = boxWidth * edgeBleed;
    final rightEdge = size.width - boxWidth * (1 + edgeBleed);
    const gap = 16.0;

    final anchorRect = _displayedRect;
    if (step.side == MascotSide.center) {
      return (size.width - boxWidth) / 2;
    }
    if (anchorRect == null) {
      return step.side == MascotSide.left ? leftEdge : rightEdge;
    }
    switch (step.dock) {
      case MascotDock.aboveTarget:
        return (anchorRect.center.dx - boxWidth / 2).clamp(leftEdge, rightEdge);
      case MascotDock.belowTarget:
        // Only the girl mascot centers under the anchor here — boy mascot
        // keeps the original side-hug `auto` placement.
        if (!widget.isGirl) {
          final onRight = anchorRect.center.dx > size.width / 2;
          return onRight
              ? (anchorRect.left - boxWidth - gap).clamp(leftEdge, rightEdge)
              : (anchorRect.right + gap).clamp(leftEdge, rightEdge);
        }
        return (anchorRect.center.dx - boxWidth / 2).clamp(leftEdge, rightEdge);
      case MascotDock.leftOfTarget:
        return (anchorRect.left - boxWidth - gap).clamp(leftEdge, rightEdge);
      case MascotDock.auto:
        final onRight = anchorRect.center.dx > size.width / 2;
        return onRight
            ? (anchorRect.left - boxWidth - gap).clamp(leftEdge, rightEdge)
            : (anchorRect.right + gap).clamp(leftEdge, rightEdge);
    }
  }

  /// The mascot's current box in overlay coordinates.
  Rect _mascotRect(Size size, TutorialStep step) {
    final (boxHeight, boxWidth) = _mascotBoxSize(size, step.dock);
    final left = _mascotLeft(size, step, boxWidth);
    final top = size.height - _mascotBottom - boxHeight;
    return Rect.fromLTWH(left, top, boxWidth, boxHeight);
  }

  Widget _buildMascot(Size size, TutorialStep step) {
    final mascotRect = _mascotRect(size, step);

    return Positioned(
      left: mascotRect.left,
      bottom: _mascotBottom,
      width: mascotRect.width,
      height: mascotRect.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mascotPop, _mascotExit]),
        builder: (context, child) {
          final popT = _springCurve.transform(_mascotPop.value);
          final exitT = _accelerateCurve.transform(_mascotExit.value);

          final translateY = 40 * (1 - popT) + 26 * exitT;
          final scale = (0.85 + 0.15 * popT) * (1 - 0.18 * exitT);
          final opacity = popT.clamp(0.0, 1.0) * (1 - exitT);

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            step.pose.assetPath(widget.isGirl),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /// Always anchored beside the mascot's actual current box — not a fixed
  /// per-side screen position — so the bubble reads as coming from Amir
  /// no matter which [MascotDock] placed him for this step.
  Widget _buildBubble(Size size, TutorialStep step) {
    final mascotRect = _mascotRect(size, step);
    // Wider for the Noor Energy / streak pill beats (per approved sketch)
    // — every other beat keeps the original width.
    final isPillStep =
        step.pose == MascotPose.pointUp || step.pose == MascotPose.pointUpLeft;
    final isMapAvatarStep = step.dock == MascotDock.leftOfTarget;
    final isAboveTargetStep = step.dock == MascotDock.aboveTarget;
    final maxBubbleWidth =
        size.width *
        (isPillStep || isMapAvatarStep || isAboveTargetStep ? 0.8 : 0.58);
    final bottomClamp = size.height * (1 - _bubbleBottomReserveFraction);

    double? left, right, top, bottom;
    var bubbleLeft = false;
    if (step.side == MascotSide.center) {
      // Centered mascot (only the closing cheer beat) has no meaningful
      // "beside" — sit just above his head instead.
      left = size.width * 0.14;
      right = size.width * 0.14;
      // The cheer pose raises both fists well above his head, unlike the
      // standing poses — less overlap needed to clear it.
      bottom = (size.height - mascotRect.top - mascotRect.height * 0.06).clamp(
        size.height * _bubbleBottomReserveFraction,
        size.height - 12.0,
      );
    } else if (isAboveTargetStep) {
      // The bigger mascot box now leaves no clean spot "beside" him this
      // close to the bottom nav — every beside-mascot fraction either cut
      // into his art or collapsed to near-zero width. Sit directly above
      // his head instead, full width, clear of both him and the target
      // below.
      left = 16;
      right = 16;
      bottom = (size.height - mascotRect.top - mascotRect.height * 0.2).clamp(
        size.height * _bubbleBottomReserveFraction,
        size.height - 12.0,
      );
    } else {
      final anchorRect = _displayedRect;
      // `leftOfTarget` (map-avatar beat) stands the mascot beside the
      // anchor at the same vertical band it occupies — a `top`-anchored
      // bubble grows *downward* as its text wraps, so longer copy could
      // dip its bottom edge down into the very avatar card Amir is
      // pointing at. Anchor by `bottom` instead so it only ever grows
      // upward, away from the anchor, regardless of line count.
      if (step.dock == MascotDock.leftOfTarget && anchorRect != null) {
        bottom = (size.height - anchorRect.top + 16).clamp(
          size.height * _bubbleBottomReserveFraction,
          size.height - 12.0,
        );
      } else {
        var desiredTop = mascotRect.top + mascotRect.height * 0.05;
        // The `auto` dock (streak/energy pills) stands the mascot *below*
        // the anchor, but the naive "5% into the mascot's own box" offset
        // could still land above the pill's bottom edge on a short screen
        // (the pill is a fixed size; 5% of the mascot's box isn't) — pin
        // the bubble below the pill explicitly instead of just hoping the
        // mascot-relative offset clears it.
        if ((step.dock == MascotDock.auto ||
                step.dock == MascotDock.belowTarget) &&
            anchorRect != null) {
          // For the girl mascot's streak beat, sit right below the pill —
          // the mascot-relative offset otherwise wins the max() and leaves
          // a gap above the bubble. Boy mascot keeps the original max().
          desiredTop = widget.isGirl && step.pose == MascotPose.pointUpLeft
              ? anchorRect.bottom + 16
              : math.max(desiredTop, anchorRect.bottom + 16);
        }
        top = desiredTop.clamp(12.0, bottomClamp);
      }
      // The pointing-up poses reach diagonally toward the box's own edge
      // — the raised arm and fingertip sit much further out than the
      // present/wave poses do, so the usual slight bubble/mascot overlap
      // (meant to look like a connected speech bubble) instead cut the
      // bubble's edge right across the pointing hand. Those two poses get
      // a clean gap instead of an overlap; everything else keeps it.
      final isPointingUp =
          step.pose == MascotPose.pointUp ||
          step.pose == MascotPose.pointUpLeft;
      if (mascotRect.center.dx < size.width / 2) {
        left = isPillStep
            ? mascotRect.left + mascotRect.width * 0.85
            : isMapAvatarStep
            ? mascotRect.left + mascotRect.width * 0.55
            : isPointingUp
            ? mascotRect.right + 10
            : mascotRect.left + mascotRect.width * 0.78;
        right = 16;
      } else {
        right = isPillStep
            // The girl mascot's streak beat now stands fully on-screen (no
            // edge bleed) instead of hugging the right edge — stretch the
            // bubble a bit further into the space that freed up so the two
            // don't read as unbalanced. Boy mascot keeps the original gap.
            ? size.width -
                  (mascotRect.left +
                      mascotRect.width *
                          (widget.isGirl && step.pose == MascotPose.pointUpLeft
                              ? 0.20
                              : 0.15))
            : isPointingUp
            ? size.width - mascotRect.left + 10
            : size.width - (mascotRect.left + mascotRect.width * 0.22);
        left = 16;
        bubbleLeft = true;
      }
    }

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: AnimatedBuilder(
          animation: Listenable.merge([_bubblePop, _bubbleExit]),
          builder: (context, child) {
            final popT = _springCurve.transform(_bubblePop.value);
            final exitT = _accelerateCurve.transform(_bubbleExit.value);
            final scale = (0.7 + 0.3 * popT) * (1 - 0.15 * exitT);
            final opacity = popT.clamp(0.0, 1.0) * (1 - exitT);
            final dropY = 10 * exitT;

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, dropY),
                child: Transform.scale(
                  scale: scale,
                  alignment: bubbleLeft
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: child,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: bubbleLeft
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(20),
                        )
                      : const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(6),
                          bottomLeft: Radius.circular(20),
                        ),
                  border: Border.all(color: AppColors.gold, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.isGirl ? 'Amira' : 'Amir',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _lineFade,
                      builder: (context, _) {
                        final t = _lineFade.value;
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 6 * (1 - t)),
                            child: Text(
                              step.lines[_lineIdx],
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D2D2D),
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (!step.isFinal)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: _TapPulse(label: 'Tap to continue'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  final isActive = i == _stepIdx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pulsing "tap to continue" affordance in the bubble's bottom-right.
class _TapPulse extends StatefulWidget {
  const _TapPulse({required this.label});
  final String label;

  @override
  State<_TapPulse> createState() => _TapPulseState();
}

class _TapPulseState extends State<_TapPulse>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Opacity(
          opacity: 0.5 + 0.5 * t,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.touch_app_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Draws the full-screen dim with a rounded-rect cutout around [rect]
/// (`Path.combine`'s difference op — same trick the HTML preview did with
/// a giant `box-shadow` spread) plus a pulsing white ring around the hole.
/// When [rect] is null, it's a plain dim with no cutout.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.rect,
    required this.dimAlpha,
    required this.pulseT,
  });

  final Rect? rect;
  final double dimAlpha;
  final double pulseT;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: dimAlpha);

    if (rect == null) {
      canvas.drawRect(fullRect, dimPaint);
      return;
    }

    final rrect = RRect.fromRectAndRadius(rect!, const Radius.circular(20));
    final outer = Path()..addRect(fullRect);
    final inner = Path()..addRRect(rrect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      dimPaint,
    );

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5 + 0.5 * pulseT)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rrect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.dimAlpha != dimAlpha ||
      oldDelegate.pulseT != pulseT;
}
