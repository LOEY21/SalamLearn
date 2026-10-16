import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:salamlearn/ui/core_modules/activities/good_deed_tree_audio.dart';
import 'package:salamlearn/ui/core_modules/activities/good_deed_tree_game.dart';

/// Tagalog card and bin labels must never break a word across lines
/// ("Pagdarasa / l sa Allah", "Basura / han") on small phones or tablets.
void main() {
  tearDown(() {
    AppTranslations.currentLanguageCodeOverride = null;
  });

  for (final session in GoodDeedTreeSession.values) {
    testWidgets('Filipino labels keep every word whole: ${session.name}', (
      tester,
    ) async {
      AppTranslations.currentLanguageCodeOverride = 'fil';
      addTearDown(tester.view.reset);
      for (final size in const [
        Size(360, 780),
        Size(412, 915),
        Size(800, 1280),
      ]) {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GoodDeedTreeGame(
                key: ValueKey('$session$size'),
                session: session,
                xp: 1,
                onComplete: (_, _, _) {},
                onExit: () {},
                audio: _SilentAudio(),
              ),
            ),
          ),
        );
        Future<void> wait(int ms) async {
          for (var t = 0; t < ms; t += 100) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await wait(2500);
        await tester.tap(find.byKey(const ValueKey('gdt-play')));
        await wait(6500);
        await tester.tap(find.byKey(const ValueKey('gdt-start')));
        await wait(10000);

        for (final e in find.byType(RichText).evaluate()) {
          final r = e.renderObject! as RenderParagraph;
          final text = r.text.toPlainText();
          for (final m in RegExp(r'[^\s-]+').allMatches(text)) {
            final tops = r
                .getBoxesForSelection(
                  TextSelection(baseOffset: m.start, extentOffset: m.end),
                )
                .map((b) => b.top.round())
                .toSet();
            expect(
              tops.length,
              1,
              reason: '"${m.group(0)}" breaks across lines in "$text" at $size',
            );
          }
        }
      }
    });
  }
}

class _SilentAudio extends GoodDeedTreeAudio {
  @override
  Future<void> say(List<String> clips) async {}
}
