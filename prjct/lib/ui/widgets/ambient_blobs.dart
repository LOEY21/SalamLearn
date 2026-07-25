import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

/// Two drifting background blobs rendered at the Scaffold level (outside
/// SafeArea) so they bleed to the true screen edges. Positions/colors/sizes
/// are per-screen, set by the caller to match each HTML preview's `.blob`
/// placement. When the same [AmbientBlobs] instance (same key) is given a
/// new [blob1]/[blob2] spec — e.g. navigating from get-started to language
/// — each blob glides smoothly to its new position/size/color instead of
/// snapping or re-fading in.
class AmbientBlobs extends StatelessWidget {
  const AmbientBlobs({
    super.key,
    required this.blob1,
    required this.blob2,
  });

  final BlobSpec blob1;
  final BlobSpec blob2;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              _blob(constraints, blob1),
              _blob(constraints, blob2),
            ],
          );
        },
      ),
    );
  }

  Widget _blob(BoxConstraints constraints, BlobSpec spec) {
    // Resolved to a top/left pair (even when the caller specified
    // right/bottom) so every blob always animates between two states using
    // the same two properties — mixing top+right on one screen with
    // top+left on another would force AnimatedPositioned to jump instead
    // of glide, since it can't interpolate a property appearing/vanishing.
    final left = spec.left ?? (constraints.maxWidth - spec.size - (spec.right ?? 0));
    final top = spec.top ?? (constraints.maxHeight - spec.size - (spec.bottom ?? 0));

    // Position/size stay put on exit (visible:false) — only opacity+scale
    // animate down in _DriftingBlob, so the blob shrinks and fades in
    // place rather than sliding somewhere first, keeping the exit quick
    // and drawing attention to the next screen instead of the background.
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      top: top,
      left: left,
      width: spec.size,
      height: spec.size,
      child: _DriftingBlob(spec: spec),
    );
  }
}

class BlobSpec {
  const BlobSpec({
    required this.color,
    required this.size,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.entranceDelay = 0.0,
    this.visible = true,
    this.exitDx = 0.0,
  });

  final Color color;
  final double size;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double entranceDelay;

  /// Set false to slide the blob out (e.g. leaving language for consent)
  /// instead of it just vanishing when the widget providing it stops
  /// being built.
  final bool visible;

  /// Fractional horizontal slide distance on exit (multiples of the
  /// blob's own width) — negative exits left, positive exits right.
  /// 0 (default) means no directional slide, just fade+shrink in place.
  final double exitDx;
}

class _DriftingBlob extends StatefulWidget {
  const _DriftingBlob({required this.spec});

  final BlobSpec spec;

  @override
  State<_DriftingBlob> createState() => _DriftingBlobState();
}

class _DriftingBlobState extends State<_DriftingBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates this endlessly-drifting circle onto its own
    // compositor layer so the animation moves a cached raster instead of
    // repainting the blob (and forcing nearby siblings to repaint) every
    // frame — this was the main source of jank while ambient blobs are on
    // screen (get-started / language / role-picker all run two of these).
    // Exit: slides off to the side (direction set per-blob via exitDx) while
    // fading, rather than shrinking in place — a clean sideways "step off"
    // for the background so attention lands on the next screen's content,
    // rather than the blob just disappearing when its parent route stops
    // rendering it.
    return RepaintBoundary(
      child: AnimatedSlide(
        offset: widget.spec.visible ? Offset.zero : Offset(widget.spec.exitDx, 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeIn,
        child: AnimatedOpacity(
          opacity: widget.spec.visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeIn,
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, child) {
              final t = _drift.value;
              return Transform.translate(
                offset: Offset(-8 * t, 10 * t),
                child: child,
              );
            },
            // Color animates smoothly too (get-started's cream-dark blob2
            // vs language's mint one, for example) via AnimatedContainer's
            // implicit color tween.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              width: widget.spec.size,
              height: widget.spec.size,
              decoration: BoxDecoration(
                // Preview's blobIn keyframe rests at opacity:0.6, not
                // fully opaque.
                color: widget.spec.color.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
