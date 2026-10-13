// Text-fit probe for the game suites: after every frame it walks the render
// tree and records, per visible piece of text, the *last* state it was seen
// in at its settled size — whether it was cut (hit its line limit /
// ellipsis), how big it was on screen, and whether it sat off screen. Judging
// each line at its largest showing means entrance pops and exit shrinks don't
// count, and hidden or mostly faded text is skipped.
//
// Off unless run with `--dart-define=TEXT_FIT=true` (see the game tests'
// flutter_test_config.dart); `--dart-define=TEXT_FIT_LANG=fil` runs the
// suites in Tagalog. Reports land in build/text_fit/<lang>/.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports, depend_on_referenced_packages
import 'package:test_api/src/backend/invoker.dart';

/// Devices the projected sizes are checked against (logical px, portrait).
/// Every game lays its screen out on a fixed stage and scales it to fit, so
/// a line's size on another device is its size here times the stage scale
/// there.
const textFitDevices = <String, Size>{
  'iPhone SE (1st gen)': Size(320, 568),
  'Small Android': Size(360, 640),
  'Galaxy A-series': Size(360, 800),
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
  'iPad mini': Size(744, 1133),
  'Galaxy Tab A': Size(800, 1280),
  'iPad Pro 12.9': Size(1024, 1366),
};

/// Loads the app's bundled fonts (from pubspec) and Flutter's Roboto — the
/// Android default the games fall back to — so text measures as on a device.
Future<void> loadRealFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  final pubspec = File('pubspec.yaml').readAsLinesSync();
  String? family;
  final fonts = <String, List<String>>{};
  for (final line in pubspec) {
    final f = RegExp(r'^\s*- family:\s*(\S+)').firstMatch(line);
    if (f != null) family = f.group(1);
    final a = RegExp(r'^\s*- asset:\s*(assets/fonts/\S+)').firstMatch(line);
    if (a != null && family != null) {
      fonts.putIfAbsent(family, () => []).add(a.group(1)!);
    }
  }
  for (final e in fonts.entries) {
    await load(e.key, e.value);
  }
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final roboto = '$root/bin/cache/artifacts/material_fonts';
  await load('Roboto', [
    for (final w in ['regular', 'medium', 'bold', 'black'])
      '$roboto/roboto-$w.ttf',
  ]);
}

/// Below this many logical px on a device a line is flagged as too small
/// for a young reader.
const double textFitMinPx = 9;

class _Seen {
  _Seen(this.test, this.text);
  final String test;
  final String text;
  bool cut = false;
  double px = 0;
  Rect rect = Rect.zero;

  /// Where it rested — the spot it was seen in for the most frames.
  /// Off-screen is judged here, so text sliding in or out isn't flagged.
  Rect lastRect = Rect.zero;
  final Map<String, int> restCounts = {};
  int restBest = 0;
  Size view = Size.zero;
}

class TextFitBinding extends AutomatedTestWidgetsFlutterBinding {
  TextFitBinding._();

  static TextFitBinding ensureInitialized() {
    if (_instance == null) TextFitBinding._();
    return _instance!;
  }

  static TextFitBinding? _instance;

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  /// test name -> text -> last state seen.
  final Map<String, Map<String, _Seen>> _seen = {};
  final Map<String, String> _files = {};

  @override
  void drawFrame() {
    super.drawFrame();
    final live = Invoker.current?.liveTest;
    if (live == null) return;
    final test = live.test.name;
    _files[test] = live.suite.path ?? '';
    final bucket = _seen.putIfAbsent(test, () => {});
    for (final view in renderViews) {
      final screen = Offset.zero & view.size;
      // Carries how opaque the subtree is; hidden or mostly faded text
      // (offstage screens, cards waiting to fade in) isn't judged.
      void visit(RenderObject o, double alpha) {
        if (o is RenderOffstage && o.offstage) return;
        if (o is RenderOpacity) alpha *= o.opacity;
        if (o is RenderAnimatedOpacity) alpha *= o.opacity.value;
        if (alpha < 0.5) return;
        if (o is RenderParagraph && o.hasSize && o.attached) {
          _record(bucket, test, o, screen, view.size);
        }
        o.visitChildren((c) => visit(c, alpha));
      }

      visit(view, 1);
    }
  }

  void _record(
    Map<String, _Seen> bucket,
    String test,
    RenderParagraph p,
    Rect screen,
    Size viewSize,
  ) {
    final text = p.text.toPlainText().trim();
    if (text.isEmpty) return;
    final size = _fontSize(p.text);
    if (size == null) return;
    final m = p.getTransformTo(null);
    final scale = math.sqrt((m.entry(0, 0) * m.entry(1, 1) - m.entry(0, 1) * m.entry(1, 0)).abs());
    if (scale < 0.05) return; // collapsed / not really shown
    final rect = MatrixUtils.transformRect(m, Offset.zero & p.size);
    final px = size * p.textScaler.scale(1) * scale;
    final s = bucket.putIfAbsent(text, () => _Seen(test, text));
    final key = '${(rect.left / 4).round()},${(rect.top / 4).round()}';
    final n = (s.restCounts[key] ?? 0) + 1;
    s.restCounts[key] = n;
    if (n >= s.restBest) {
      s.restBest = n;
      s.lastRect = rect;
    }
    // Judged where it settles: its largest showing. Entrance pops and exit
    // shrinks are smaller, so they never replace it.
    if (px + 0.01 < s.px) return;
    s.cut = p.didExceedMaxLines;
    s.px = px;
    s.rect = rect;
    s.view = viewSize;
  }

  static double? _fontSize(InlineSpan span) {
    double? found;
    span.visitChildren((s) {
      final f = s.style?.fontSize;
      if (f != null) found = found == null ? f : math.max(found!, f);
      return true;
    });
    return found ?? span.style?.fontSize;
  }

  /// Writes the report for this test file.
  void writeReport(String lang) {
    final byFile = <String, List<String>>{};
    for (final entry in _seen.entries) {
      final file = _files[entry.key] ?? 'unknown';
      final lines = byFile.putIfAbsent(file, () => []);
      for (final s in entry.value.values) {
        final issues = <String>[];
        if (s.cut) issues.add('CUT');
        final screen = Offset.zero & s.view;
        final inter = s.lastRect.intersect(screen);
        final area = s.lastRect.width * s.lastRect.height;
        if (area > 0 && (inter.width <= 0 || inter.height <= 0 || inter.width * inter.height < area * 0.6)) {
          issues.add('OFFSCREEN');
        }
        // Projected size on the smallest device of the matching orientation.
        final landscape = s.view.width > s.view.height;
        var worst = double.infinity;
        var worstName = '';
        for (final d in textFitDevices.entries) {
          final dev = landscape ? d.value.flipped : d.value;
          final k = math.min(dev.width / s.view.width, dev.height / s.view.height);
          final px = s.px * k;
          if (px < worst) {
            worst = px;
            worstName = d.key;
          }
        }
        if (worst < textFitMinPx) {
          issues.add('SMALL ${worst.toStringAsFixed(1)}px on $worstName');
        }
        if (issues.isEmpty) continue;
        lines.add('[${issues.join(', ')}] "${s.text.replaceAll('\n', r'\n')}"  '
            '(${s.px.toStringAsFixed(1)}px in test view ${s.view.width.toInt()}x${s.view.height.toInt()})  '
            '— ${s.test}');
      }
    }
    final dir = Directory('build/text_fit/$lang')..createSync(recursive: true);
    for (final e in byFile.entries) {
      final name = e.key.split(RegExp(r'[\\/]')).last.replaceAll('.dart', '');
      final uniq = e.value.toSet().toList()..sort();
      File('${dir.path}/$name.txt').writeAsStringSync('${uniq.join('\n')}\n');
    }
  }
}
