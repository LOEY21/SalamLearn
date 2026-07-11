import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('starts at 0 when nothing stored yet', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(learnerXpProvider), 0);
  });

  test('addXp increases the total and persists it to Hive', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(learnerXpProvider.notifier).addXp(50);

    expect(container.read(learnerXpProvider), 50);
    expect(Hive.box<dynamic>(HiveBoxes.settings).get('learnerXp'), 50);
  });

  test('addXp accumulates across multiple calls', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(learnerXpProvider.notifier);

    notifier.addXp(50);
    notifier.addXp(30);

    expect(container.read(learnerXpProvider), 80);
  });
}
