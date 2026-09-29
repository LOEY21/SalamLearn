import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/repositories/progress_repository.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/connectivity/internet_access.dart';
import 'package:salamlearn/logic/parent/analytics_providers.dart';
import 'package:salamlearn/logic/parent/game_grades.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  test('score bands follow the DepEd descriptor cut-offs', () {
    expect(GradeBand.forScore(100), GradeBand.outstanding);
    expect(GradeBand.forScore(90), GradeBand.outstanding);
    expect(GradeBand.forScore(89.9), GradeBand.verySatisfactory);
    expect(GradeBand.forScore(85), GradeBand.verySatisfactory);
    expect(GradeBand.forScore(80), GradeBand.satisfactory);
    expect(GradeBand.forScore(75), GradeBand.fairlySatisfactory);
    expect(GradeBand.forScore(74.9), GradeBand.needsPractice);
    expect(GradeBand.forScore(0), GradeBand.needsPractice);
  });

  test('feedback names the child and counts mistakes', () {
    expect(
      gameFeedback(scorePct: 95, mistakes: 0, name: 'Aisha'),
      'Excellent work! Aisha has mastered this game. No mistakes made.',
    );
    expect(
      gameFeedback(scorePct: 60, mistakes: 1, name: 'Aisha'),
      contains('Made 1 mistake along the way.'),
    );
    expect(
      gameFeedback(scorePct: 60, mistakes: 3),
      contains('Made 3 mistakes'),
    );
  });

  test('curriculum groups into 12 games holding all 40 sessions', () {
    final games = curriculumGames();
    expect(games, hasLength(12));
    expect(games.expand((g) => g.sessions), hasLength(40));
    final tracer = games.firstWhere((g) => g.name == 'Magic Sand Tracer');
    expect(tracer.sessions.map((s) => sessionLabel(s.lesson)), [
      'Session 1 (Alif to Kha)',
      'Session 2 (Dal to Sad)',
      'Session 3 (Dad to Qaf)',
      'Session 4 (Kaf to Ya)',
    ]);
  });

  test('curriculum groups into 7 stages holding all 40 sessions', () {
    final stages = curriculumStages();
    expect(stages, hasLength(7));
    expect(stages.every((s) => s.isStage), isTrue);
    expect(stages.expand((s) => s.sessions), hasLength(40));
    expect(stages.first.name, 'Stage 1: Welcome to Madrasah');
  });

  test('formatDuration', () {
    expect(formatDuration(45), '45s');
    expect(formatDuration(125), '2m 05s');
  });

  test('parentGameResultsProvider keeps the latest result per game', () async {
    final tempDir = await setUpTestHive();
    addTearDown(() => tearDownTestHive(tempDir));
    final c = ProviderContainer(
      overrides: [internetAccessProvider.overrideWithValue(() async => true)],
    );
    addTearDown(c.dispose);
    final n = c.read(sessionProvider.notifier);
    n.setLanguage('en');
    await n.giveConsent();
    n.stageParentRegistration(
      fullName: 'Parent One',
      email: 'parent@example.com',
      password: 'Password123',
    );
    await n.createPin('1234');
    final learner = await n.createLearner(
      name: 'Aisha',
      age: 6,
      username: 'aisha6',
    );

    final progress = ProgressRepository();
    await progress.writeProgress(
      learnerId: learner.id!,
      moduleId: '1',
      strokeAccuracyPct: 60,
      sequencingErrors: 4,
      timeOnTaskSeconds: 30,
      lessonId: 'lesson-a',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await progress.writeProgress(
      learnerId: learner.id!,
      moduleId: '1',
      strokeAccuracyPct: 92,
      sequencingErrors: 0,
      timeOnTaskSeconds: 40,
      lessonId: 'lesson-a',
    );

    final results = c.read(parentGameResultsProvider);
    expect(results.keys, ['lesson-a']);
    expect(results['lesson-a']!.strokeAccuracyPct, 92);
  });
}
