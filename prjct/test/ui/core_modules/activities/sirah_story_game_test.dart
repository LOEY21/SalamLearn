import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/sirah_story_game.dart';

void main() {
  // The game is laid out against the scene art's own 1870x841 landscape
  // stage and scaled to fit, so matching the surface to it makes the scale
  // exactly 1 and keeps every layer where the design puts it.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(1870, 841);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(
    SirahStorySession session, {
    void Function(int, double, int)? onComplete,
    VoidCallback? onExit,
  }) => MaterialApp(
    home: Scaffold(
      body: SirahStoryGame(
        // A fresh State per session — otherwise pumping a second session
        // into the same slot keeps the first one's screen.
        key: ValueKey(session.number),
        session: session,
        xp: 40,
        onComplete: onComplete ?? (_, _, _) {},
        onExit: onExit,
      ),
    ),
  );

  const sessions = [
    sirahBirthSession,
    sirahHalimahSession,
    sirahFamilySession,
    sirahAlAminSession,
  ];

  /// Advances [total] in real frames. The game's clock only moves on frame
  /// ticks, so one giant pump lets a timer fire mid-pump against a stale
  /// clock — which no device ever does.
  Future<void> run(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  /// Presses START ADVENTURE and sits through the curtain wipe into the
  /// first scene.
  Future<void> start(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.byKey(const ValueKey('sirah-play')));
    await run(tester, const Duration(milliseconds: 6600));
  }

  /// Waits out the page's narration, so the scene dims and the subject
  /// becomes tappable.
  Future<void> hearOut(WidgetTester tester, SirahStoryPage page) async {
    await tester.pump(Duration(milliseconds: page.narrationMs + 100));
  }

  /// Taps the glowing layer and sits through the 1.5s darkening beat before
  /// the question card assembles.
  Future<void> openQuestion(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('sirah-glow')));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The beat on the answered card, then the wipe into the next scene.
  Future<void> advance(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2100));
    await run(tester, const Duration(milliseconds: 6600));
  }

  testWidgets('opens on the same start screen for every session', (
    tester,
  ) async {
    for (final session in sessions) {
      await tester.pumpWidget(host(session));
      await tester.pump(const Duration(milliseconds: 1200));

      // The same title screen every time — logo, ribbon and PLAY, laid out
      // to the reference. Which session it is, the curtain plate says.
      expect(find.byKey(const ValueKey('sirah-play')), findsOneWidget);
      for (final art in const [
        'assets/images/sirah_story/title_logo.png',
        'assets/images/sirah_story/title_ribbon.png',
        'assets/images/sirah_story/play_btn.png',
      ]) {
        expect(
          find.byWidgetPredicate(
            (w) => w is Image && (w.image as AssetImage).assetName == art,
          ),
          findsOneWidget,
          reason: art,
        );
      }
      // Nothing of the story itself has started yet.
      expect(find.text(session.pages.first.narration), findsNothing);
    }
  });

  testWidgets('every session carries two pages, each with one question', (
    tester,
  ) async {
    for (final session in sessions) {
      expect(session.pages, hasLength(2));
      await tester.pumpWidget(host(session));
      await start(tester);

      final page = session.pages.first;
      expect(find.text(page.narration), findsOneWidget);

      await hearOut(tester, page);
      await openQuestion(tester);

      expect(find.text(page.prompt), findsOneWidget);
      expect(find.text(page.correct), findsOneWidget);
      expect(find.text(page.decoy), findsOneWidget);
    }
  });

  testWidgets('the glow only answers once the narration has finished', (
    tester,
  ) async {
    const session = sirahBirthSession;
    await tester.pumpWidget(host(session));
    await start(tester);

    // The layer is in the scene from the start, but it is not lit and does
    // not answer until the line has been read.
    await tester.tap(
      find.byKey(const ValueKey('sirah-glow')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(session.pages.first.prompt), findsNothing);

    await hearOut(tester, session.pages.first);
    await openQuestion(tester);
    expect(find.text(session.pages.first.prompt), findsOneWidget);
  });

  testWidgets('the question card waits out the 1.5s transition', (
    tester,
  ) async {
    const session = sirahBirthSession;
    final page = session.pages.first;
    await tester.pumpWidget(host(session));
    await start(tester);
    await hearOut(tester, page);

    await tester.tap(find.byKey(const ValueKey('sirah-glow')));
    await tester.pump(const Duration(milliseconds: 1400));
    // Still darkening — no card, and no curtain over the scene either.
    expect(find.text(page.prompt), findsNothing);
    expect(find.text('Question 1'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(page.prompt), findsOneWidget);
  });

  testWidgets('the start button wipes in on the session plate', (tester) async {
    const session = sirahHalimahSession;
    await tester.pumpWidget(host(session));
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.byKey(const ValueKey('sirah-play')));
    await tester.pump(const Duration(milliseconds: 1600));
    // Curtain shut, announcing the session.
    expect(find.text('SIRAH STORY  ·  SESSION 2'), findsOneWidget);
    expect(find.text(session.title), findsWidgets);

    // Still up, fully readable, four seconds after it arrived — and the
    // story has not started behind it.
    await tester.pump(const Duration(milliseconds: 3400));
    expect(find.text('SIRAH STORY  ·  SESSION 2'), findsOneWidget);
    expect(find.text(session.pages.first.narration), findsNothing);

    await tester.pump(const Duration(milliseconds: 1600));
    // Drawn back on the first scene, plate gone.
    expect(find.text('SIRAH STORY  ·  SESSION 2'), findsNothing);
    expect(find.text(session.pages.first.narration), findsOneWidget);
  });

  testWidgets('the scene holds still — no drift, no pulse', (tester) async {
    const session = sirahAlAminSession; // its last page is the celebrate one
    await tester.pumpWidget(host(session));
    await start(tester);

    final scene = find.descendant(
      of: find.byType(FittedBox),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName == session.pages.first.background,
      ),
    );
    final glow = find.byKey(const ValueKey('sirah-glow'));

    final scene0 = tester.getRect(scene);
    final glow0 = tester.getRect(glow);
    await tester.pump(const Duration(seconds: 9));

    expect(tester.getRect(scene), scene0);
    expect(tester.getRect(glow), glow0);
  });

  testWidgets('the narration bar fills across the line, at full height', (
    tester,
  ) async {
    await tester.pumpWidget(host(sirahHalimahSession));
    await start(tester);

    // The fill is the gradient box inside the bar's clipped track.
    Size fill() => tester.getSize(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(DecoratedBox),
      ),
    );

    final early = fill();
    // A zero-height fill is invisible however wide it gets — the track then
    // reads as an empty bar, which is what an Align around it used to cause.
    expect(early.height, greaterThan(0));
    expect(early.width, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 1500));
    final later = fill();
    expect(later.height, early.height);
    expect(later.width, greaterThan(early.width));
  });

  testWidgets('Replay Narration only arrives once the line is read', (
    tester,
  ) async {
    const session = sirahBirthSession;
    final page = session.pages.first;
    await tester.pumpWidget(host(session));
    await start(tester);

    final replay = find.byKey(const ValueKey('sirah-replay'));
    bool blocked() => tester
        .widget<IgnorePointer>(
          find.ancestor(of: replay, matching: find.byType(IgnorePointer)).first,
        )
        .ignoring;

    // Mid-narration it is faded out and takes no taps.
    expect(blocked(), isTrue);

    await hearOut(tester, page);
    await tester.pump(const Duration(milliseconds: 400));
    expect(blocked(), isFalse);
  });

  testWidgets('back and replay swap to their pressed art while held', (
    tester,
  ) async {
    const session = sirahBirthSession;
    await tester.pumpWidget(host(session));
    await start(tester);
    await hearOut(tester, session.pages.first);

    String artOf(Key k) =>
        ((tester.widget<Image>(
                  find.descendant(
                    of: find.byKey(k),
                    matching: find.byType(Image),
                  ),
                )).image
                as AssetImage)
            .assetName;

    for (final key in const [
      ValueKey('sirah-back'),
      ValueKey('sirah-replay'),
    ]) {
      final rest = artOf(key);
      expect(rest, endsWith('_btn.png'));

      final press = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pump();
      expect(artOf(key), endsWith('_btn_down.png'), reason: '\$key held');

      // Cancelled, not released — a real tap on Back would open the
      // leave-the-story confirm and cover the next button.
      await press.cancel();
      await tester.pump(const Duration(milliseconds: 100));
      expect(artOf(key), rest, reason: '\$key released');
    }
  });

  testWidgets('Back on the question card returns to the scene and re-reads', (
    tester,
  ) async {
    const session = sirahBirthSession;
    final page = session.pages.first;
    await tester.pumpWidget(host(session));
    await start(tester);
    await hearOut(tester, page);
    await openQuestion(tester);
    expect(find.text(page.prompt), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sirah-question-back')));
    await tester.pump(const Duration(milliseconds: 400));

    // Card gone, scene back, and the line is being read again from the top.
    expect(find.text(page.prompt), findsNothing);
    expect(find.text(page.narration), findsOneWidget);

    // Still the same page, and it answers again once the line is done.
    await hearOut(tester, page);
    await openQuestion(tester);
    expect(find.text(page.prompt), findsOneWidget);
  });

  testWidgets('the finale star stays out of the sky until the line is read', (
    tester,
  ) async {
    const session = sirahAlAminSession;
    final last = session.pages.last;
    expect(last.celebrate, isTrue);

    await tester.pumpWidget(host(session));
    await start(tester);
    await hearOut(tester, session.pages.first);
    await openQuestion(tester);
    await tester.tap(find.text(session.pages.first.correct));
    await advance(tester);
    expect(find.text(last.narration), findsOneWidget);

    final star = find.byWidgetPredicate(
      (w) => w is Image && (w.image as AssetImage).assetName == last.glow.asset,
    );
    // Narrating: no star anywhere yet.
    expect(star, findsNothing);

    // Line done: it rises in, lands where the art puts it, and answers.
    await hearOut(tester, last);
    await run(tester, const Duration(milliseconds: 1200));
    expect(star, findsWidgets);
    await openQuestion(tester);
    expect(find.text(last.prompt), findsOneWidget);
  });

  testWidgets('the speaker chip on the question card is never clipped', (
    tester,
  ) async {
    const session = sirahBirthSession;
    await tester.pumpWidget(host(session));
    await start(tester);
    await hearOut(tester, session.pages.first);
    await openQuestion(tester);

    final chip = find.descendant(
      of: find.byType(SizedBox),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName ==
                'assets/images/sirah_story/speaker.png',
      ),
    );
    final chipRect = tester.getRect(chip.first);
    // The row the chip sits in clips its children, so it must be at least
    // as tall as the chip or the chip gets flattened into an oval.
    final row = tester.getRect(
      find.ancestor(of: chip.first, matching: find.byType(Stack)).first,
    );
    expect(chipRect.height, 84);
    expect(row.top, lessThanOrEqualTo(chipRect.top + 0.5));
    expect(row.bottom, greaterThanOrEqualTo(chipRect.bottom - 0.5));
  });

  testWidgets('the decoy never advances the story', (tester) async {
    const session = sirahHalimahSession;
    await tester.pumpWidget(host(session));
    await start(tester);
    await hearOut(tester, session.pages.first);
    await openQuestion(tester);

    await tester.tap(find.text(session.pages.first.decoy));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MUMTAZ!'), findsNothing);
    // Still the same question, both answers still on offer.
    expect(find.text(session.pages.first.prompt), findsOneWidget);
    expect(find.text(session.pages.first.correct), findsOneWidget);
  });

  testWidgets('the right answer shows the MUMTAZ ribbon and moves on', (
    tester,
  ) async {
    const session = sirahFamilySession;
    await tester.pumpWidget(host(session));
    await start(tester);
    await hearOut(tester, session.pages.first);
    await openQuestion(tester);

    await tester.tap(find.text(session.pages.first.correct));
    await tester.pump(const Duration(milliseconds: 300));
    // MUMTAZ! is the painted ribbon now, not a text badge.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName ==
                'assets/images/sirah_story/mumtaz_ribbon.png',
      ),
      findsOneWidget,
    );

    // The card holds its beat, then the curtain wipes to the second scene.
    await advance(tester);
    expect(find.text(session.pages[1].narration), findsOneWidget);
    expect(find.text(session.pages.first.prompt), findsNothing);
  });

  testWidgets('both pages finish the session and report the score', (
    tester,
  ) async {
    const session = sirahAlAminSession;
    int? xp;
    double? accuracy;
    int? errors;
    await tester.pumpWidget(
      host(
        session,
        onComplete: (x, a, e) {
          xp = x;
          accuracy = a;
          errors = e;
        },
      ),
    );
    await start(tester);

    for (final page in session.pages) {
      await hearOut(tester, page);
      await openQuestion(tester);
      await tester.tap(find.text(page.correct));
      await advance(tester);
    }

    // It finishes on the scene just played, not the title screen's square.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName == session.pages.last.background,
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName ==
                'assets/images/sirah_story/start_bg.png',
      ),
      findsNothing,
    );

    // The ending screen, built from the reference's own art.
    for (final art in const [
      'assets/images/sirah_story/end_plaque.png',
      'assets/images/sirah_story/end_panel_blank.png',
      'assets/images/sirah_story/end_boy.png',
      'assets/images/sirah_story/end_girl.png',
      'assets/images/sirah_story/end_btn.png',
    ]) {
      expect(
        find.byWidgetPredicate(
          (w) => w is Image && (w.image as AssetImage).assetName == art,
        ),
        findsOneWidget,
        reason: art,
      );
    }

    // The panel congratulates them on finishing the whole lesson.
    expect(find.text('Congratulations!'), findsOneWidget);
    expect(find.text('You completed the whole lesson!'), findsOneWidget);

    // Nothing is reported until Continue Next Lesson is pressed.
    expect(xp, isNull);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.byKey(const ValueKey('sirah-continue')));
    await tester.pump();

    expect(xp, 40);
    expect(errors, 0);
    expect(accuracy, 100.0);
  });

  testWidgets('backing out of the first page asks before leaving', (
    tester,
  ) async {
    const session = sirahBirthSession;
    await tester.pumpWidget(host(session));
    await start(tester);
    await hearOut(tester, session.pages.first);

    await tester.tap(find.byKey(const ValueKey('sirah-back')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('Leave the story? You will go back to the start screen.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep Reading'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(session.pages.first.narration), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sirah-back')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Go to Start'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('sirah-play')), findsOneWidget);
  });
}
