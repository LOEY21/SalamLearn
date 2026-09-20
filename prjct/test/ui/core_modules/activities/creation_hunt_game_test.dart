import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/creation_hunt_game.dart';

void main() {
  // The game is laid out against the prototype's 393x852 phone frame and
  // scaled to fit, so matching the surface to it makes the scale exactly 1
  // and lets the tests tap a spot's fractional coordinates directly.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(393, 852);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(
    CreationHuntStage stage, {
    void Function(int, double, int)? onComplete,
    VoidCallback? onExit,
  }) => MaterialApp(
    home: Scaffold(
      body: CreationHuntGame(
        // A fresh State per stage — otherwise pumping a second stage into
        // the same slot keeps the first one's screen.
        key: ValueKey(stage.name),
        stage: stage,
        xp: 30,
        onComplete: onComplete ?? (_, _, _) {},
        onExit: onExit,
      ),
    ),
  );

  Offset centreOf(CreationHuntSpot spot) => Offset(spot.x * 393, spot.y * 852);

  /// Walks title -> how to play -> the hunt itself.
  Future<void> startHunt(WidgetTester tester) async {
    await tester.tapAt(const Offset(196, 400));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(
      find.bySemanticsLabel('Start the hunt'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('opens on the same title screen for every stage', (tester) async {
    final handle = tester.ensureSemantics();
    for (final stage in [forestHuntStage, skyHuntStage, gardenHuntStage]) {
      await tester.pumpWidget(host(stage));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Tap anywhere to begin'), findsOneWidget);

      await tester.tapAt(const Offset(196, 400));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.bySemanticsLabel('Start the hunt'), findsOneWidget);
    }
    handle.dispose();
  });

  testWidgets('tapping a creation fills a token, a decoy does not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(forestHuntStage));
    await startHunt(tester);

    expect(find.text('Found: 0/6'), findsOneWidget);
    expect(find.text('Find the things Allah created!'), findsOneWidget);

    final bird = forestHuntStage.spots.firstWhere((s) => s.id == 'bird');
    final car = forestHuntStage.spots.firstWhere((s) => s.id == 'car');

    // A creation: verdict card, then the counter moves.
    await tester.tapAt(centreOf(bird));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('SubhanAllah!'), findsOneWidget);
    expect(find.text('Allah created the bird.'), findsOneWidget);
    expect(find.text('Found: 1/6'), findsOneWidget);

    await tester.tap(
      find.bySemanticsLabel('Keep hunting'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('SubhanAllah!'), findsNothing);

    // A decoy: the other verdict, and the counter stays put.
    await tester.tapAt(centreOf(car));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Not this one'), findsOneWidget);
    expect(find.text('Found: 1/6'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Try again'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Not this one'), findsNothing);
    handle.dispose();
  });

  testWidgets('the verdict button still works when a frame lands mid-tap', (
    tester,
  ) async {
    // Pressing the button spawns a tap ripple, which rebuilds the hunt
    // between the press and the release. The button has to survive that.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(forestHuntStage));
    await startHunt(tester);

    final bird = forestHuntStage.spots.firstWhere((s) => s.id == 'bird');
    await tester.tapAt(centreOf(bird));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('SubhanAllah!'), findsOneWidget);

    final button = tester.getCenter(find.bySemanticsLabel('Keep hunting'));
    final gesture = await tester.startGesture(button);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SubhanAllah!'), findsNothing);
    handle.dispose();
  });

  testWidgets('the five pine trees all count as the one "tree" token', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(forestHuntStage));
    await startHunt(tester);

    final canopy = forestHuntStage.spots.firstWhere((s) => s.id == 'tree');
    final pine = forestHuntStage.spots.firstWhere((s) => s.id == 'tree_pine_1');

    await tester.tapAt(centreOf(canopy));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Found: 1/6'), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel('Keep hunting'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 500));

    // An alias of the same creation — already found, so nothing happens.
    await tester.tapAt(centreOf(pine));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Found: 1/6'), findsOneWidget);
    expect(find.text('SubhanAllah!'), findsNothing);
    handle.dispose();
  });

  testWidgets('verdict copy stays inside its board, clear of the button', (
    tester,
  ) async {
    // The two boards are not drawn alike: the green one runs nearly edge to
    // edge, the brown one carries ~16% transparent margin top and bottom, so
    // a single shared inset pushes the brown board's copy out into the open.
    final handle = tester.ensureSemantics();

    Rect boardOf(WidgetTester t, String asset) => t.getRect(
      find
          .byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName.contains(asset),
          )
          .first,
    );

    await tester.pumpWidget(host(forestHuntStage));
    await startHunt(tester);

    final bird = forestHuntStage.spots.firstWhere((s) => s.id == 'bird');
    final car = forestHuntStage.spots.firstWhere((s) => s.id == 'car');

    await tester.tapAt(centreOf(bird));
    await tester.pump(const Duration(milliseconds: 600));

    var board = boardOf(tester, 'reveal_panel_blank');
    var title = tester.getRect(find.text('SubhanAllah!'));
    var body = tester.getRect(find.text('Allah created the bird.'));
    var button = tester.getRect(find.bySemanticsLabel('Keep hunting'));

    expect(board.contains(title.topLeft), isTrue);
    expect(board.contains(body.bottomRight), isTrue);
    expect(body.bottom, lessThanOrEqualTo(button.top + 0.5));
    expect(title.width, lessThanOrEqualTo(board.width));

    await tester.tap(
      find.bySemanticsLabel('Keep hunting'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tapAt(centreOf(car));
    await tester.pump(const Duration(milliseconds: 600));

    board = boardOf(tester, 'wrong_panel_blank');
    title = tester.getRect(find.text('Not this one'));
    body = tester.getRect(find.textContaining('People made the car'));
    button = tester.getRect(find.bySemanticsLabel('Try again'));

    // The brown board's art starts ~16% down its own box — the copy has to
    // clear that, not the box's edge.
    expect(board.contains(title.topLeft), isTrue);
    expect(title.top, greaterThan(board.top + board.height * 0.14));
    expect(board.contains(body.bottomRight), isTrue);
    expect(body.bottom, lessThanOrEqualTo(button.top + 0.5));
    handle.dispose();
  });

  testWidgets('finding all six reaches the badge screen and completes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    int? awardedXp;
    int? errors;
    await tester.pumpWidget(
      host(
        forestHuntStage,
        onComplete: (xp, _, errs) {
          awardedXp = xp;
          errors = errs;
        },
      ),
    );
    await startHunt(tester);

    for (final spot in forestHuntStage.creations) {
      await tester.tapAt(centreOf(spot));
      await tester.pump(const Duration(milliseconds: 600));
      if (find.bySemanticsLabel('Keep hunting').evaluate().isNotEmpty) {
        await tester.tap(
          find.bySemanticsLabel('Keep hunting'),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    expect(find.text('Found: 6/6'), findsOneWidget);

    // Recap beat, then the badge screen; the continue button hands back.
    await tester.pump(const Duration(milliseconds: 8000));
    expect(
      find.textContaining('created by Allah in the forest'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 4400));
    expect(awardedXp, isNull);
    await tester.tap(find.text('Tap anywhere to continue to next lesson'));
    await tester.pump();
    expect(awardedXp, 30);
    expect(errors, 0);

    await tester.pump(const Duration(seconds: 1));
    handle.dispose();
  });

  testWidgets('the HUD exit chip leaves the lesson', (tester) async {
    final handle = tester.ensureSemantics();
    var exited = false;
    await tester.pumpWidget(host(gardenHuntStage, onExit: () => exited = true));
    await startHunt(tester);

    await tester.tap(find.bySemanticsLabel('Exit'), warnIfMissed: false);
    await tester.pump();
    expect(exited, isTrue);
    handle.dispose();
  });

  testWidgets('every stage has six creations and its own decoys', (
    tester,
  ) async {
    for (final stage in [forestHuntStage, skyHuntStage, gardenHuntStage]) {
      expect(stage.creations.length, 6, reason: stage.name);
      expect(
        stage.spots.where((s) => !s.isCreation).isNotEmpty,
        isTrue,
        reason: stage.name,
      );
      // Aliases must point at a real canonical spot.
      for (final alias in stage.spots.where((s) => s.alias)) {
        expect(
          stage.creations.any((c) => c.id == alias.group),
          isTrue,
          reason: '${stage.name}: ${alias.id}',
        );
      }
    }
  });
}
