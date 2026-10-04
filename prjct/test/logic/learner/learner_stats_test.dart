import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/learner_profile.dart';
import 'package:salamlearn/data/repositories/progress_repository.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/logic/recent_module_provider.dart';

import '../../test_helpers/hive_test_setup.dart';

class _Learner extends SessionNotifier {
  _Learner(this.id);
  final String id;

  @override
  SessionState build() =>
      SessionState(learner: LearnerProfile(name: id, age: 6, id: id));
}

ProviderContainer _containerFor(String learnerId) {
  final c = ProviderContainer(
    overrides: [sessionProvider.overrideWith(() => _Learner(learnerId))],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  late Directory dir;
  setUp(() async => dir = await setUpTestHive());
  tearDown(() async => tearDownTestHive(dir));

  test('a brand-new child starts with no XP, no streak and no badges', () {
    final c = _containerFor('new-child');
    expect(c.read(learnerXpProvider), 0);
    expect(c.read(learnerStreakProvider), 0);
    expect(c.read(unlockedBadgesProvider), isEmpty);
  });

  test("a child's own lessons, streak and badges count — and never carry "
      'over to another child', () async {
    final lesson = curriculum.first.lessons.first;
    await ProgressRepository().writeProgress(
      learnerId: 'amina',
      moduleId: '1',
      strokeAccuracyPct: 90,
      sequencingErrors: 0,
      timeOnTaskSeconds: 60,
      lessonId: lesson.id,
    );
    final amina = _containerFor('amina');
    amina.read(unlockedBadgesProvider.notifier).unlockBadge('First Steps Badge');
    await Future<void>.delayed(Duration.zero);

    expect(amina.read(learnerXpProvider), lesson.xp);
    expect(amina.read(learnerStreakProvider), 1);
    expect(amina.read(unlockedBadgesProvider), ['First Steps Badge']);

    // Badges are saved: a fresh session for the same child still has it.
    expect(
      _containerFor('amina').read(unlockedBadgesProvider),
      ['First Steps Badge'],
    );

    final bilal = _containerFor('bilal');
    expect(bilal.read(learnerXpProvider), 0);
    expect(bilal.read(learnerStreakProvider), 0);
    expect(bilal.read(unlockedBadgesProvider), isEmpty);
  });
}
