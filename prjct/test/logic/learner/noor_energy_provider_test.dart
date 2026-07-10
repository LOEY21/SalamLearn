import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('starts full (5/5) with no stored state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(noorEnergyProvider);
    expect(state.current, 5);
    expect(state.maxEnergy, 5);
    expect(state.hasEnergy, true);
  });

  test('consume decrements current and persists it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(noorEnergyProvider.notifier);

    notifier.consume();

    expect(container.read(noorEnergyProvider).current, 4);
    expect(Hive.box<dynamic>(HiveBoxes.settings).get('noorEnergyCurrent'), 4);
  });

  test('consume never goes below 0', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(noorEnergyProvider.notifier);

    for (var i = 0; i < 10; i++) {
      notifier.consume();
    }

    expect(container.read(noorEnergyProvider).current, 0);
    expect(container.read(noorEnergyProvider).hasEnergy, false);
  });

  test('refills to max when the stored reset date is not today', () async {
    final settings = Hive.box<dynamic>(HiveBoxes.settings);
    await settings.put('noorEnergyCurrent', 1);
    await settings.put('noorEnergyLastResetDate', '2020-01-01');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(noorEnergyProvider);
    expect(state.current, 5);
  });

  test(
    'rebuilding on the same day does not re-refill already-consumed energy',
    () {
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);
      container1.read(noorEnergyProvider.notifier).consume();
      container1.read(noorEnergyProvider.notifier).consume();
      expect(container1.read(noorEnergyProvider).current, 3);

      // Fresh container/notifier instance, same underlying Hive box, same day.
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      expect(container2.read(noorEnergyProvider).current, 3);
    },
  );
}
