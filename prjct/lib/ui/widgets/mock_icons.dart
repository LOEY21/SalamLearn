import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_parsing/path_parsing.dart';

/// Exact line icons from the approved top-tab dashboard mock (24x24
/// viewBox, stroke-width 2, round cap/join, no fill) — copied 1:1 from
/// the artifact's inline SVG markup rather than approximated with
/// Material icons, so the app matches the mock pixel-for-pixel.
class MockIcon extends StatelessWidget {
  const MockIcon(this._path, {super.key, this.size = 20, this.color});

  final String _path;
  final double size;
  final Color? color;

  static const _wrapOpen =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">';
  static const _wrapClose = '</svg>';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '$_wrapOpen$_path$_wrapClose',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? IconTheme.of(context).color ?? Colors.black,
        BlendMode.srcIn,
      ),
    );
  }
}

/// [PathProxy] that just forwards straight to a Flutter [Path] — the
/// canonical adapter shown in `path_parsing`'s own example, letting
/// [writeSvgPathDataToPath] (which already reduces arcs to cubics) build
/// a real [Path] instead of printing commands.
class _FlutterPathProxy extends PathProxy {
  final Path path = Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

final _tagPattern = RegExp(r'<(path|circle|rect)([^>]*)/>');
final _attrPattern = RegExp(r'(\w+)="([^"]*)"');

/// Parses a [MockIcons] raw-markup fragment (`<path d="…"/><circle .../>`
/// etc., always 24x24-viewBox stroke icons) into one combined [Path] with
/// one contour per shape — used to drive the tab bar's stroke-draw
/// animation via [Path.computeMetrics]/[PathMetric.extractPath], which a
/// flutter_svg [SvgPicture] can't expose since it never hands back the
/// parsed geometry.
Path buildMockIconPath(String rawSvg) {
  final path = Path();
  for (final match in _tagPattern.allMatches(rawSvg)) {
    final tag = match.group(1)!;
    final attrs = {
      for (final a in _attrPattern.allMatches(match.group(2)!))
        a.group(1)!: a.group(2)!,
    };
    switch (tag) {
      case 'path':
        final proxy = _FlutterPathProxy();
        writeSvgPathDataToPath(attrs['d'], proxy);
        path.addPath(proxy.path, Offset.zero);
      case 'circle':
        final cx = double.parse(attrs['cx']!);
        final cy = double.parse(attrs['cy']!);
        final r = double.parse(attrs['r']!);
        path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      case 'rect':
        final x = double.parse(attrs['x']!);
        final y = double.parse(attrs['y']!);
        final w = double.parse(attrs['width']!);
        final h = double.parse(attrs['height']!);
        final rx = double.tryParse(attrs['rx'] ?? '') ?? 0;
        path.addRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx)),
        );
    }
  }
  return path;
}

abstract final class MockIcons {
  // ---- tab bar ----
  static const progress = '<path d="M3 3v18h18"/><path d="M7 15l3-4 3 2 5-6"/>';
  static const profile =
      '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c1-3 3.2-4.5 6-4.5S14 17 15 20"/><path d="M17 8h5M19.5 5.5v5"/>';
  static const settings =
      '<circle cx="12" cy="12" r="3"/><path d="M19.4 13a1.7 1.7 0 0 0 .34 1.87l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.7 1.7 0 0 0-1.87-.34 1.7 1.7 0 0 0-1 1.55V19a2 2 0 1 1-4 0v-.09A1.7 1.7 0 0 0 9 17.4a1.7 1.7 0 0 0-1.87.34l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.7 1.7 0 0 0 4.6 13a1.7 1.7 0 0 0-1.55-1H3a2 2 0 1 1 0-4h.09A1.7 1.7 0 0 0 4.6 6.6a1.7 1.7 0 0 0-.34-1.87l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.7 1.7 0 0 0 9 2.6a1.7 1.7 0 0 0 1-1.55V1a2 2 0 1 1 4 0v.09a1.7 1.7 0 0 0 1 1.55 1.7 1.7 0 0 0 1.87-.34l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.7 1.7 0 0 0 19.4 8a1.7 1.7 0 0 0 1.55 1H21a2 2 0 1 1 0 4h-.09a1.7 1.7 0 0 0-1.55 1z"/>';
  static const home =
      '<circle cx="8" cy="8" r="3"/><path d="M2 20c.8-3 3-4.6 6-4.6s5.2 1.6 6 4.6"/><circle cx="17" cy="8" r="2.4"/><path d="M15.8 15.6c2.4.4 4 1.8 4.6 4.4"/>';
  static const classroom =
      '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><path d="M8 4v5"/>';

  // ---- header actions ----
  static const swap =
      '<path d="M17 2l4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><path d="M7 22l-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>';
  static const cast =
      '<path d="M2 8.5a15 15 0 0 1 20 0"/><path d="M5.5 12a10 10 0 0 1 13 0"/><path d="M9 15.5a5 5 0 0 1 6 0"/><circle cx="12" cy="19" r="1.4" fill="currentColor"/>';
  static const learnerHead =
      '<circle cx="12" cy="8" r="3.2"/><path d="M5 20c1.2-3.4 4-5 7-5s5.8 1.6 7 5"/>';
  static const school =
      '<path d="M3 9.5L12 4l9 5.5-9 5.5-9-5.5z"/><path d="M7 12.5V17c0 1.5 2 3 5 3s5-1.5 5-3v-4.5"/>';

  // ---- KPI pills ----
  static const clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
  static const warningTriangle =
      '<path d="M12 9v4"/><circle cx="12" cy="16.3" r=".4" fill="currentColor"/><path d="M10.3 3.9L2.5 18a1.8 1.8 0 0 0 1.6 2.7h15.8a1.8 1.8 0 0 0 1.6-2.7L13.7 3.9a1.8 1.8 0 0 0-3.4 0z"/>';
  static const trendUp = '<path d="M7 17V7h10"/><path d="M7 7l10 10"/>';
  static const trendDown = '<path d="M7 7v10h10"/><path d="M7 17L17 7"/>';
  static const check = '<path d="M20 6L9 17l-5-5"/>';
  static const clockPie = '<path d="M12 8v4l3 2"/><circle cx="12" cy="12" r="9"/>';

  // ---- cards ----
  static const trend = '<path d="M3 3v18h18"/><path d="M7 15l3-4 3 2 5-6"/>';
  static const layers = '<path d="M4 19h16M4 15l4-5 4 3 4-6 4 4"/>';
  static const classBadge = '<path d="M3 21V8l9-5 9 5v13"/><path d="M9 21v-6h6v6"/>';
  static const classBadgeFilled = '<path d="M3 21V8l9-5 9 5v13"/>';
  static const gear = settings;
  static const account = '<rect x="3" y="11" width="18" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>';
  static const bell = '<path d="M4 5h16M4 12h16M4 19h10"/>';
  static const roster =
      '<circle cx="9" cy="7" r="3"/><path d="M2 20c.8-3.4 3-5 7-5"/><path d="M15 21v-2a4 4 0 0 0-4-4"/><circle cx="17" cy="7" r="2.2"/>';
  static const lightning = '<path d="M13 2L3 14h7l-1 8 10-12h-7l1-8z"/>';
  static const castSquare =
      '<path d="M2 8.5a15 15 0 0 1 20 0"/><path d="M5.5 12a10 10 0 0 1 13 0"/><path d="M9 15.5a5 5 0 0 1 6 0"/>';
  static const homework = '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>';
  static const lock = '<rect x="3" y="11" width="18" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/>';
  static const chevronRight = '<path d="M9 5l7 7-7 7"/>';
  static const healthArrows = '<path d="M22 12h-4l-3 9-4-18-3 9H2"/>';
  static const plus = '<path d="M12 5v14M5 12h14"/>';
  static const codeBox = '<path d="M4 4h16v16H4z"/><path d="M4 9h16M9 4v16"/>';
  static const infoCircle = '<circle cx="12" cy="12" r="9"/><path d="M12 8h.01M11 12h1v4h1"/>';
}
