import 'dart:async';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';
import 'mock_icons.dart';

/// One entry in a [TopTabBar].
class TopTabItem {
  const TopTabItem({required this.iconPath, required this.label, this.badge = false});

  /// Raw SVG path markup (see [MockIcons]) — matches the artifact 1:1
  /// instead of approximating with a Material icon.
  final String iconPath;
  final String label;

  /// Small dot shown top-right of the icon (e.g. unread/needs-attention).
  final bool badge;
}

/// Top-of-screen tab strip with a sliding underline indicator — replaces
/// the old bottom nav (phone) / side rail (wide) pair with one nav that
/// works at every width, per the approved top-tab redesign mock.
class TopTabBar extends StatelessWidget {
  const TopTabBar({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<TopTabItem> items;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.creamBorder)),
      ),
      // LayoutBuilder must wrap the Stack (not sit inside it) — Positioned
      // / AnimatedPositioned parent data only applies to widgets that are
      // *direct* children of Stack. LayoutBuilder is itself a RenderObject,
      // so nesting it inside the Stack and returning AnimatedPositioned
      // from its builder silently breaks the positioning: Stack treats the
      // LayoutBuilder as a plain non-positioned child and stretches it to
      // fill the whole row, which is why the indicator used to render as a
      // full-width bar instead of a per-tab sliding underline.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / items.length;
          return Stack(
            children: [
              Row(
                children: [
                  for (final (i, item) in items.indexed)
                    Expanded(
                      child: _TopTab(
                        item: item,
                        active: i == activeIndex,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                left: tabWidth * activeIndex,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopTab extends StatefulWidget {
  const _TopTab({required this.item, required this.active, required this.onTap});

  final TopTabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TopTab> createState() => _TopTabState();
}

/// Quick tap shouldn't trigger the hold-loop — matches the approved mock's
/// own delay (dumps/tab_icon_lottie_mock.html).
const _holdDelay = Duration(milliseconds: 160);

class _TopTabState extends State<_TopTab> with SingleTickerProviderStateMixin {
  late Path _path = buildMockIconPath(widget.item.iconPath);

  // Starts fully drawn (1.0) — the animation is a decorative one-shot/loop
  // effect on activation or press, never a "hidden until revealed" state,
  // so an icon that's never been tapped still renders solid. `duration`
  // drives the one-shot draw-in (`forward()`); the hold-loop passes its
  // own explicit `period` to `repeat()`, which overrides this.
  late final _draw = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 420),
  )..addListener(() => setState(() {}));

  Timer? _holdTimer;
  bool _holding = false;

  @override
  void didUpdateWidget(_TopTab old) {
    super.didUpdateWidget(old);
    if (old.item.iconPath != widget.item.iconPath) {
      _path = buildMockIconPath(widget.item.iconPath);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _draw.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _holdTimer = Timer(_holdDelay, () {
      _holding = true;
      _draw.repeat(reverse: true, period: const Duration(milliseconds: 550));
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    if (_holding) {
      _holding = false;
      _draw.stop();
      _draw.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.teal : AppColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: _onTapDown,
        onTapCancel: _stopHold,
        onTap: () {
          final wasHolding = _holding;
          _stopHold();
          // A plain tap (never crossed the hold threshold) always replays
          // the one-shot draw-in — including re-tapping an already-active
          // tab, matching the approved mock where every tap animates, not
          // just tab switches. A released hold already settled visually
          // via `_stopHold`, so it skips this to avoid redrawing twice.
          if (!wasHolding) {
            _draw.forward(from: 0);
          }
          widget.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Reserves a 24x24 box (matching the icon's own SVG
                  // viewBox) regardless of the 19px render size, so the
                  // badge dot below can anchor to the icon's true corner.
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(19, 19),
                        painter: _StrokeDrawPainter(
                          path: _path,
                          progress: _draw.value,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  if (widget.item.badge)
                    Positioned(
                      // Offset by the icon's inset within the 24x24
                      // reserve box (2.5px each side) so the dot still
                      // sits at the icon's actual corner, not the box's.
                      top: -3.5,
                      right: -5.5,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                widget.item.label,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Strokes [path] (built in a 24x24 coordinate space by [buildMockIconPath])
/// scaled into [size], revealing only the leading [progress] fraction of
/// each contour's length — the "line drawing itself in" effect approved in
/// dumps/tab_icon_lottie_mock.html, without pairing it with any scale
/// change (that combination was what read as the icon "floating").
class _StrokeDrawPainter extends CustomPainter {
  const _StrokeDrawPainter({
    required this.path,
    required this.progress,
    required this.color,
  });

  final Path path;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
    } else if (progress > 0) {
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokeDrawPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.path != path;
}
