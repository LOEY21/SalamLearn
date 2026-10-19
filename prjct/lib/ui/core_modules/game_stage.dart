import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Fills the bars a fixed-size game stage leaves on a screen of another
/// shape (a tablet) by stretching the art's own edge rows/columns outward,
/// mirrored and softened, so the picture reads as running to the screen
/// edge. Paints only the bars — the stage draws the art itself, on top.
class StageBands extends StatelessWidget {
  const StageBands({
    super.key,
    required this.asset,
    required this.design,
    this.art,
    this.alignment = Alignment.center,
  });

  final String asset;

  /// The stage's design size; it is fitted (contain) into the screen.
  final Size design;

  /// Where the stage draws [asset], in design units — the whole stage if
  /// null. Art that spills past the stage leaves narrower bars.
  final Rect? art;

  /// How the stage is aligned in the screen (as its FittedBox is).
  final Alignment alignment;

  /// How much of the art's edge (fraction of its size) is stretched out.
  static const _edge = .025;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final screen = Offset.zero & box.biggest;
      final k = (screen.width / design.width) < (screen.height / design.height)
          ? screen.width / design.width
          : screen.height / design.height;
      final stage = alignment.inscribe(design * k, screen);
      final a = art ?? Offset.zero & design;
      final r = Rect.fromLTWH(
        stage.left + a.left * k,
        stage.top + a.top * k,
        a.width * k,
        a.height * k,
      );
      // Overlap the art a little so the soft edge of the blur never shows.
      const o = 6.0;

      // The art's outer edge, stretched and mirrored so its very first
      // row/column meets the art without a seam.
      Widget strip(Rect band, Alignment align, Size drawn) =>
          Positioned.fromRect(
            rect: band,
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 10,
                  sigmaY: 10,
                  tileMode: TileMode.clamp,
                ),
                child: Transform.flip(
                  flipX: align.x != 0,
                  flipY: align.y != 0,
                  child: OverflowBox(
                    alignment: align,
                    minWidth: drawn.width,
                    maxWidth: drawn.width,
                    minHeight: drawn.height,
                    maxHeight: drawn.height,
                    child: Image.asset(asset, fit: BoxFit.fill),
                  ),
                ),
              ),
            ),
          );

      final top = r.top - screen.top;
      final bottom = screen.bottom - r.bottom;
      final left = r.left - screen.left;
      final right = screen.right - r.right;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (top > .5)
            strip(
              Rect.fromLTWH(r.left, 0, r.width, top + o),
              Alignment.topCenter,
              Size(r.width, (top + o) / _edge),
            ),
          if (bottom > .5)
            strip(
              Rect.fromLTWH(r.left, r.bottom - o, r.width, bottom + o),
              Alignment.bottomCenter,
              Size(r.width, (bottom + o) / _edge),
            ),
          if (left > .5)
            strip(
              Rect.fromLTWH(0, r.top, left + o, r.height),
              Alignment.centerLeft,
              Size((left + o) / _edge, r.height),
            ),
          if (right > .5)
            strip(
              Rect.fromLTWH(r.right - o, r.top, right + o, r.height),
              Alignment.centerRight,
              Size((right + o) / _edge, r.height),
            ),
        ],
      );
    },
  );
}

/// A [design]-sized layer zoomed to cover the whole screen, cropping
/// whatever spills past it — for art with no tap targets on it.
class StageCover extends StatelessWidget {
  const StageCover({super.key, required this.design, required this.child});

  final Size design;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox.fromSize(size: design, child: child),
      ),
    ),
  );
}
