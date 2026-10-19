import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/learner_profile.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';

import '../../test_helpers/hive_test_setup.dart';

class _FakeSession extends SessionNotifier {
  _FakeSession(this.learnerId);

  final String learnerId;

  @override
  SessionState build() => SessionState(
    learner: LearnerProfile(name: 'Amina', age: 6, id: learnerId),
  );
}

/// A container with learner [id] signed in.
ProviderContainer _signedIn([String id = 'learner-1']) {
  final container = ProviderContainer(
    overrides: [sessionProvider.overrideWith(() => _FakeSession(id))],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('starts full (5/5) with no stored state', () {
    final container = _signedIn();
    final state = container.read(noorEnergyProvider);
    expect(state.current, 5);
    expect(state.maxEnergy, 5);
    expect(state.hasEnergy, true);
  });

  test('consume decrements current and persists it', () {
    final container = _signedIn();
    final notifier = container.read(noorEnergyProvider.notifier);

    notifier.consume();

    expect(container.read(noorEnergyProvider).current, 4);
    expect(
      Hive.box<dynamic>(HiveBoxes.settings).get('noorEnergyCurrent_learner-1'),
      4,
    );
  });

  test('consume never goes below 0', () {
    final container = _signedIn();
    final notifier = container.read(noorEnergyProvider.notifier);

    for (var i = 0; i < 10; i++) {
      notifier.consume();
    }

    expect(container.read(noorEnergyProvider).current, 0);
    expect(container.read(noorEnergyProvider).hasEnergy, false);
  });

  test('spending from a full row starts a 24-minute clock', () {
    var now = DateTime(2026, 10, 17, 9);
    NoorEnergyNotifier.clock = () => now;
    addTearDown(() => NoorEnergyNotifier.clock = DateTime.now);
    final container = _signedIn();
    final notifier = container.read(noorEnergyProvider.notifier);

    notifier.consume();
    now = now.add(const Duration(minutes: 10));
    notifier.consume();

    // A second lantern doesn't push back the one already relighting.
    expect(
      container.read(noorEnergyProvider).nextLanternAt,
      DateTime(2026, 10, 17, 9, 24),
    );
  });

  test('spent lanterns relight one every 24 minutes', () {
    var now = DateTime(2026, 10, 17, 9);
    NoorEnergyNotifier.clock = () => now;
    addTearDown(() => NoorEnergyNotifier.clock = DateTime.now);
    final first = _signedIn();
    for (var i = 0; i < 5; i++) {
      first.read(noorEnergyProvider.notifier).consume();
    }
    expect(first.read(noorEnergyProvider).hasEnergy, false);

    int at(int h, int m) {
      now = DateTime(2026, 10, 17, h, m);
      return _signedIn().read(noorEnergyProvider).current;
    }

    expect(at(9, 23), 0);
    expect(at(9, 24), 1);
    expect(at(10, 12), 3);
    expect(at(10, 59), 4);
    expect(at(11, 0), 5);
    expect(_signedIn().read(noorEnergyProvider).nextLanternAt, isNull);
  });

  test('rebuilding does not re-refill already-spent lanterns', () {
    final container1 = _signedIn();
    container1.read(noorEnergyProvider.notifier).consume();
    container1.read(noorEnergyProvider.notifier).consume();
    expect(container1.read(noorEnergyProvider).current, 3);

    // Fresh container/notifier instance, same underlying Hive box.
    final container2 = _signedIn();
    expect(container2.read(noorEnergyProvider).current, 3);
  });

  test('every learner has their own lanterns; a new one starts full', () {
    final first = _signedIn('learner-1');
    for (var i = 0; i < 5; i++) {
      first.read(noorEnergyProvider.notifier).consume();
    }
    expect(first.read(noorEnergyProvider).current, 0);

    final second = _signedIn('learner-2');
    expect(second.read(noorEnergyProvider).current, 5);
    second.read(noorEnergyProvider.notifier).consume();
    expect(second.read(noorEnergyProvider).current, 4);

    // The first learner's spent lanterns are untouched.
    expect(_signedIn('learner-1').read(noorEnergyProvider).current, 0);
  });

  test('no learner signed in: full, and nothing is spent', () {
    final container = ProviderContainer(
      overrides: [sessionProvider.overrideWith(_NoLearner.new)],
    );
    addTearDown(container.dispose);
    container.read(noorEnergyProvider.notifier).consume();
    expect(container.read(noorEnergyProvider).current, 5);
  });
}

class _NoLearner extends SessionNotifier {
  @override
  SessionState build() => const SessionState();
}
