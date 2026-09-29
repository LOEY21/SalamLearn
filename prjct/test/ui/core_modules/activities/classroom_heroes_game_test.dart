import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/classroom_heroes_game.dart';
import 'package:salamlearn/ui/core_modules/activities/classroom_heroes_audio.dart';

void main() {
  test('all Classroom Heroes recordings are bundled', () async {
    expect(classroomAudio.length, 4);
    final clips = <String>{'ambient.mp3'};
    for (final session in classroomAudio) {
      expect(session.length, 3);
      for (final question in session) {
        clips.addAll([question.prompt, question.correct, question.decoy]);
      }
    }
    expect(clips.length, 37);
    for (final clip in clips) {
      final data = await rootBundle.load('assets/audio/classroom_heroes/$clip');
      expect(data.lengthInBytes, greaterThan(0), reason: clip);
    }
  });
  // The game is laid out against the prototype's 1600x900 landscape stage
  // and scaled to fit, so matching the surface to it makes the scale exactly
  // 1 and keeps the hit targets where the design puts them.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(1600, 900);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(
    ClassroomHeroesSession session, {
    void Function(int, double, int)? onComplete,
    VoidCallback? onExit,
    ClassroomAudioPlayback? audio,
  }) => MaterialApp(
    home: Scaffold(
      body: ClassroomHeroesGame(
        // A fresh State per session — otherwise pumping a second session
        // into the same slot keeps the first one's screen.
        key: ValueKey(session.number),
        session: session,
        xp: 30,
        onComplete: onComplete ?? (_, _, _) {},
        onExit: onExit,
        audioEnabled: audio != null,
        audio: audio,
      ),
    ),
  );

  const sessions = [
    heroesRespectSession,
    heroesKindnessSession,
    heroesResponsibilitySession,
    heroesTeamworkSession,
  ];

  testWidgets('question and both choices speak before a tap', (tester) async {
    final audio = _FakeClassroomAudio();
    const session = heroesRespectSession;
    final clips = classroomAudio.first.first;
    await tester.pumpWidget(host(session, audio: audio));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 1000));
    final dynamic playButton = tester.widget(find.byKey(const ValueKey('ch-play')));
    (playButton.onTap as VoidCallback)();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(audio.played.last, clips.prompt);

    audio.complete();
    await tester.pump(const Duration(milliseconds: 500));
    final first = audio.played.last;
    audio.complete();
    await tester.pump();
    // Read left to right, and the hero card's side is random.
    expect({first, audio.played.last}, {clips.correct, clips.decoy});
    final heroX = tester.getCenter(
      find.text(session.questions.first.correctText),
    ).dx;
    final decoyX = tester.getCenter(
      find.text(session.questions.first.decoyText),
    ).dx;
    expect(first == clips.correct, heroX < decoyX);

    final beforeTap = audio.played.length;
    await tester.tap(find.text(session.questions.first.correctText));
    await tester.pump();
    expect(audio.played.length, beforeTap);
    expect(audio.stops, greaterThan(0));
  });

  Future<void> skipNarration(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Taps the play button, then sits through the curtain wipe and the
  /// narration bar so the question panel is on screen.
  Future<void> startSession(
    WidgetTester tester,
    ClassroomHeroesSession session,
  ) async {
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.tap(find.byKey(const ValueKey('ch-play')));
    await tester.pump();
    await skipNarration(tester);
  }

  testWidgets('opens on the same title screen for every session', (
    tester,
  ) async {
    for (final session in sessions) {
      await tester.pumpWidget(host(session));
      await tester.pump(const Duration(milliseconds: 1400));

      // Same logo, ribbon and play button for every session.
      expect(find.byKey(const ValueKey('ch-play')), findsOneWidget);
      expect(find.text('Classroom Hero Meter'), findsNothing);
    }
  });

  testWidgets('every session carries three scenarios and two choices each', (
    tester,
  ) async {
    for (final session in sessions) {
      expect(session.questions, hasLength(3));
      await tester.pumpWidget(host(session));
      await startSession(tester, session);

      final q = session.questions.first;
      expect(find.text(q.promptText), findsOneWidget);
      expect(find.text(q.correctText), findsOneWidget);
      expect(find.text(q.decoyText), findsOneWidget);
    }
  });

  testWidgets('the decoy asks for another try and never advances', (
    tester,
  ) async {
    const session = heroesRespectSession;
    await tester.pumpWidget(host(session));
    await startSession(tester, session);

    await tester.tap(find.text(session.questions.first.decoyText));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Try again!'), findsOneWidget);
    expect(find.text(session.retryText), findsOneWidget);
    // Still on the same question, with no success feedback.
    expect(find.text(session.questions.first.promptText), findsOneWidget);
    expect(find.text(session.questions.first.successFeedback), findsNothing);
  });

  testWidgets('the hero choice congratulates, then moves on', (tester) async {
    const session = heroesKindnessSession;
    await tester.pumpWidget(host(session));
    await startSession(tester, session);

    await tester.tap(find.text(session.questions.first.correctText));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('MUMTAZ!'), findsWidgets);
    expect(find.text(session.questions.first.successFeedback), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await skipNarration(tester);

    expect(find.text(session.questions[1].promptText), findsOneWidget);
  });

  testWidgets('three hero choices finish the session and report the score', (
    tester,
  ) async {
    const session = heroesTeamworkSession;
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
    await startSession(tester, session);

    for (var i = 0; i < session.questions.length; i++) {
      // One wrong tap on the first scenario, so the score has an error in it.
      if (i == 0) {
        await tester.tap(find.text(session.questions[i].decoyText));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text(session.questions[i].correctText));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.text(i == session.questions.length - 1 ? 'Finish' : 'Next'),
      );
      await tester.pump();
      if (i < session.questions.length - 1) await skipNarration(tester);
    }

    final handle = tester.ensureSemantics();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text(session.finishText), findsOneWidget);
    expect(xp, isNull, reason: 'the badge waits for the continue button');

    await tester.tap(find.bySemanticsLabel('Continue to Next Lesson'));
    await tester.pump();
    handle.dispose();

    expect(xp, 30);
    expect(errors, 1);
    expect(accuracy, closeTo(75, 0.01)); // 3 right out of 4 taps
  });
}

class _FakeClassroomAudio implements ClassroomAudioPlayback {
  final List<String> played = [];
  void Function()? _onComplete;
  int stops = 0;

  void complete() {
    final callback = _onComplete;
    _onComplete = null;
    callback?.call();
  }

  @override
  Future<void> startMusic() async {}

  @override
  Future<void> play(
    String asset, {
    void Function()? onComplete,
    void Function()? onError,
    void Function(Duration)? onDuration,
  }) async {
    played.add(asset);
    _onComplete = onComplete;
  }

  @override
  Future<void> stopVoice() async {
    stops++;
    _onComplete = null;
  }

  @override
  Future<void> dispose() async {}
}
