import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared helpers for the responsive layout tests: a size x text-scale
/// matrix, real-font metrics, and a scroll-through check that fails on any
/// overflow, any word broken mid-word, or any content it couldn't reach.

/// Window sizes from a small phone up to a desktop monitor, both
/// orientations for tablets.
const responsiveSizes = [
  Size(320, 568),
  Size(360, 640),
  Size(390, 844),
  Size(412, 915),
  Size(600, 960),
  Size(768, 1024),
  Size(1024, 768),
  Size(1280, 800),
  Size(1920, 1080),
];

/// Default, a common "large text" setting, and Android/iOS max-ish.
const responsiveTextScales = [1.0, 1.3, 2.0];

/// Every laid-out paragraph whose longest single word is wider than the
/// paragraph itself — i.e. a word Flutter had to break mid-word.
List<String> brokenWords(WidgetTester tester) {
  final broken = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    final text = paragraph.text.toPlainText();
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: paragraph.text.style),
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout();
      if (painter.width > paragraph.size.width + 1) {
        broken.add('"$word" in "$text"');
      }
      painter.dispose();
    }
  }
  return broken;
}

/// A point on screen at [fraction] of the window height — drags start here
/// so they always land on visible content (a scroll view's own centre can
/// sit below the screen edge when its header has not scrolled away yet).
Offset onScreen(WidgetTester tester, double fraction) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return Offset(size.width / 2, size.height * fraction);
}

double totalScroll(WidgetTester tester) => find
    .byType(Scrollable)
    .evaluate()
    .map((e) => (e as StatefulElement).state as ScrollableState)
    .fold(0.0, (sum, state) => sum + state.position.pixels);

/// Checks for overflow and broken words, scrolls a screenful, repeats until
/// the innermost scroll view hits its end. Fails if a drag stops moving
/// anything before then, so no content is ever silently left unchecked.
Future<void> scrollThroughChecking(
  WidgetTester tester,
  String label, {
  double dragAt = 0.6,
}) async {
  for (var step = 0; step < 200; step++) {
    expect(tester.takeException(), isNull, reason: label);
    expect(brokenWords(tester), isEmpty, reason: label);
    // Innermost *vertical* scroll view — a text field's own horizontal
    // scroller doesn't count.
    final inner = find
        .byType(Scrollable)
        .evaluate()
        .map((e) => (e as StatefulElement).state as ScrollableState)
        .lastWhere((s) => axisDirectionToAxis(s.axisDirection) == Axis.vertical)
        .position;
    if (inner.pixels >= inner.maxScrollExtent) return;
    final before = totalScroll(tester);
    await tester.dragFrom(onScreen(tester, dragAt), const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 400));
    expect(totalScroll(tester), greaterThan(before), reason: '$label: stuck');
  }
  fail('$label: never reached the end');
}

/// Drags (down = towards the top) until [finder] is built, then brings it
/// fully into view.
Future<void> scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  required bool towardsTop,
}) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester.dragFrom(
      onScreen(tester, 0.6),
      Offset(0, towardsTop ? 250 : -250),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 400));
  // Under a scroll-away header (NestedScrollView) ensureVisible can jump
  // the inner list past the target, unbuilding it; drag back to it.
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester.dragFrom(
      onScreen(tester, 0.6),
      Offset(0, i < 30 ? 250 : -250),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  // ensureVisible only reasons about the innermost viewport; under the
  // scroll-away header that viewport can still extend past the screen, so
  // keep dragging until the target's centre is genuinely on screen.
  // Visible part of the list the target lives in: its scroll viewport
  // clipped to the screen (a pinned header or the screen edge can hide
  // part of the viewport).
  final screen =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  final list = find.ancestor(
    of: finder.first,
    matching: find.byType(Scrollable),
  );
  // Pinned (not scrolling) targets — e.g. the tabs on a tall screen — are
  // already where they'll stay.
  if (list.evaluate().isEmpty) return;
  final viewport = tester.getRect(list.first).intersect(screen);
  for (var i = 0; i < 20; i++) {
    final y = tester.getCenter(finder.first).dy;
    final top = viewport.top + viewport.height * 0.15;
    final bottom = viewport.top + viewport.height * 0.85;
    if (y > top && y < bottom) {
      // Let any fling coast to a stop: a tap on a still-moving list only
      // stops the scroll, it doesn't press the row (same as on a device).
      await tester.pump(const Duration(seconds: 2));
      return;
    }
    await tester.dragFrom(viewport.center, Offset(0, y <= top ? 150 : -150));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// One pump() is one frame — a route/sheet transition only *starts* on it.
/// Pump a frame, then let the transition run to completion.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 100));
}

/// flutter_test's default font draws every glyph as a full square (~2x a
/// real font's width), which would flag words that fit fine on a device.
/// Load real metrics: the app's Baloo 2 for display text, and Nunito
/// standing in for the platform font (slightly wider than Roboto, so this
/// errs on the strict side).
Future<void> loadRealFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  await load('Baloo2Var', 'assets/fonts/Baloo2-Variable.ttf');
  await load('Roboto', 'assets/fonts/Nunito-Variable.ttf');
}

/// Scrolls [target] into view and taps it until [opened] appears (a route,
/// dialog or sheet). Retries once: under a heavily loaded parallel test
/// run the list can still be settling, and a tap on a moving list only
/// stops the scroll instead of pressing the row (same as on a device).
Future<void> tapToOpen(
  WidgetTester tester,
  Finder target,
  Finder opened, {
  required String reason,
  bool towardsTop = false,
}) async {
  for (var attempt = 0; attempt < 2 && opened.evaluate().isEmpty; attempt++) {
    await scrollUntilFound(tester, target, towardsTop: towardsTop);
    await tester.tap(target.first);
    await settle(tester);
  }
  expect(opened, findsWidgets, reason: '$reason: did not open');
}
