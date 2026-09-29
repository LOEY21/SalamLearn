import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/notifications/notification_provider.dart';
import 'package:salamlearn/logic/recent_module_provider.dart';

import '../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;

  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() async => tearDownTestHive(tempDir));

  test('earning a badge or streak adds an unread Backpack notification', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(notificationsProvider).where((n) => n.id.startsWith('badge-')),
      isEmpty,
    );

    container.read(unlockedBadgesProvider.notifier).unlockBadge('Ayah Builder Badge');
    container.read(learnerStreakProvider.notifier).increment();
    final items = container.read(notificationsProvider);

    final badge = items.firstWhere((n) => n.id == 'badge-ayah_builder');
    expect(badge.read, isFalse);
    expect(badge.opensBackpack, isTrue);

    final streak = items.firstWhere((n) => n.id == 'streak-6');
    expect(streak.read, isFalse);
    expect(streak.opensBackpack, isTrue);

    container.read(notificationsProvider.notifier).markRead('badge-ayah_builder');
    expect(
      container.read(notificationsProvider).firstWhere((n) => n.id == 'badge-ayah_builder').read,
      isTrue,
    );
  });
}
