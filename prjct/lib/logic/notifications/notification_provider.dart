import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/class_repository.dart';
import '../auth/session.dart';

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
  });

  final String id;
  final String title;
  final String body;
  final String emoji;
  final bool read;

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    title: title,
    body: body,
    emoji: emoji,
    read: read ?? this.read,
  );
}

String _titleForModuleId(String id) {
  final cleanId = switch (id) {
    '1' => 'village-of-salaam',
    '2' => 'desert-of-letters',
    '3' => 'garden-of-words',
    '4' => 'river-of-sirah',
    '5' => 'masjid-of-salah',
    '6' => 'mountain-of-iman',
    '7' => 'quran-corner',
    _ => id,
  };
  return switch (cleanId) {
    'village-of-salaam' => 'Village of Salaam',
    'desert-of-letters' => 'Desert of Letters',
    'garden-of-words' => 'Garden of Words',
    'river-of-sirah' => 'River of Sirah',
    'masjid-of-salah' => 'Masjid of Salah',
    'mountain-of-iman' => 'Mountain of Iman',
    'quran-corner' => 'Qur\'an Corner',
    _ => cleanId,
  };
}

/// In-memory notification inbox. Resets on app restart, same as the rest
/// of session state — no persistence until Hive/Firebase land.
class NotificationsNotifier extends Notifier<List<NotificationItem>> {
  final Set<String> _readIds = {};

  @override
  List<NotificationItem> build() {
    // Seed default notifications
    final baseList = [
      const NotificationItem(
        id: 'streak',
        emoji: '🔥',
        title: '5-day streak!',
        body: "You've learned something new 5 days in a row. Keep it up!",
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

    final combined = [...homeworkNotifications, ...baseList];
    return [
      for (final n in combined)
        n.copyWith(
          read: _readIds.contains(n.id) || n.id == 'sorting-unlock',
        ),
    ];
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
