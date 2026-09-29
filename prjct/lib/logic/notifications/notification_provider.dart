import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/class_repository.dart';
import '../../data/student_badges.dart';
import '../../ui/core_modules/module_registry.dart';
import '../auth/session.dart';
import '../recent_module_provider.dart';

/// A single notification surfaced to the learner (streak reminders, module
/// unlocks, completion cheers). Placeholder phase: seeded mock data only —
/// no push/local-notification wiring yet.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.emoji,
    this.read = false,
    this.opensBackpack = false,
  });

  final String id;
  final String title;
  final String body;
  final String emoji;
  final bool read;

  /// Tapping takes the learner to the Backpack tab (badge/streak rewards).
  final bool opensBackpack;

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    title: title,
    body: body,
    emoji: emoji,
    read: read ?? this.read,
    opensBackpack: opensBackpack,
  );
}

String _titleForModuleId(String id) => assignmentTitle(id);

/// In-memory notification inbox. Resets on app restart, same as the rest
/// of session state — no persistence until Hive/Firebase land.
class NotificationsNotifier extends Notifier<List<NotificationItem>> {
  final Set<String> _readIds = {};

  @override
  List<NotificationItem> build() {
    final streak = ref.watch(learnerStreakProvider);
    final newBadges = ref
        .watch(unlockedBadgesProvider)
        .where((b) => !UnlockedBadgesNotifier.seed.contains(b))
        .toList()
        .reversed;

    final badgeNotifications = [
      for (final name in newBadges)
        if (allStudentBadges.where((b) => isBadgeUnlocked(b, [name])).firstOrNull
            case final badge?)
          NotificationItem(
            id: 'badge-${badge.id}',
            emoji: badge.emoji,
            title: 'You earned the ${badge.shortName} badge!',
            body: badge.category == BadgeCategory.streak
                ? 'Open your Backpack and tap Streaks to see it.'
                : 'Open your Backpack to see your new badge.',
            opensBackpack: true,
          ),
    ];

    // Seed default notifications
    final baseList = [
      NotificationItem(
        id: 'streak-$streak',
        emoji: '🔥',
        title: '$streak-day streak!',
        body:
            "You've learned something new $streak days in a row. Open your Backpack to see your streak!",
        opensBackpack: true,
      ),
      const NotificationItem(
        id: 'tracing-done',
        emoji: '🎉',
        title: 'Tracing completed',
        body: 'Great job finishing all the Tracing cards.',
      ),
      const NotificationItem(
        id: 'sorting-unlock',
        emoji: '🧩',
        title: 'Sort & Match unlocks soon',
        body: 'Finish Stories to unlock the Sort & Match module.',
      ),
    ];

    final learner = ref.watch(sessionProvider).learner;

    final List<Map<String, dynamic>> homeworks = [];

    // Individual student assignments
    if (learner != null && learner.id != null) {
      final learnerId = learner.id!;
      final enrollments = ClassRepository().byLearnerId(learnerId);
      final enrolledClassIds = enrollments.map((e) => e.classId).toSet();

      for (final classId in enrolledClassIds) {
        final classAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: null);
        for (final a in classAssignments) {
          homeworks.add({
            'module': a.moduleId,
            'type': 'class',
          });
        }
        final personalAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: learnerId);
        for (final a in personalAssignments) {
          homeworks.add({
            'module': a.moduleId,
            'type': 'personal',
          });
        }
      }
    }

    final homeworkNotifications = <NotificationItem>[];
    for (final hw in homeworks) {
      final moduleId = hw['module'] as String;
      final type = hw['type'] as String;
      final moduleTitle = _titleForModuleId(moduleId);
      final id = 'hw-$moduleId-$type';

      homeworkNotifications.add(
        NotificationItem(
          id: id,
          emoji: '📝',
          title: 'New Teacher Homework!',
          body: type == 'class'
              ? 'Your teacher assigned the "$moduleTitle" module to the whole class.'
              : 'Your teacher assigned the "$moduleTitle" module specifically for you!',
        ),
      );
    }

    final combined = [
      ...badgeNotifications,
      ...homeworkNotifications,
      ...baseList,
    ];
    return [
      for (final n in combined)
        n.copyWith(
          read: _readIds.contains(n.id) || n.id == 'sorting-unlock',
        ),
    ];
  }

  void markRead(String id) {
    _readIds.add(id);
    state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
  }

  void markAllRead() {
    for (final n in state) {
      _readIds.add(n.id);
    }
    state = [for (final n in state) n.copyWith(read: true)];
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<NotificationItem>>(
      NotificationsNotifier.new,
    );

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.read).length;
});
