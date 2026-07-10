import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';

void main() {
  setUp(() async {
    Hive.init('test/.hive_tmp');
    await Hive.openBox<dynamic>(HiveBoxes.settings);
  });

  tearDown(() async {
    await Hive.box<dynamic>(HiveBoxes.settings).clear();
    await Hive.close();
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
