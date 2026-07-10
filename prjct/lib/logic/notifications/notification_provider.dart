import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// In-memory notification inbox. Resets on app restart, same as the rest
/// of session state — no persistence until Hive/Firebase land.
class NotificationsNotifier extends Notifier<List<NotificationItem>> {
  @override
  List<NotificationItem> build() => const [
    NotificationItem(
      id: 'streak',
      emoji: '🔥',
      title: '5-day streak!',
      body: "You've learned something new 5 days in a row. Keep it up!",
    ),
    NotificationItem(
      id: 'tracing-done',
      emoji: '🎉',
      title: 'Tracing completed',
      body: 'Great job finishing all the Tracing cards.',
    ),
    NotificationItem(
      id: 'sorting-unlock',
      emoji: '🧩',
      title: 'Sort & Match unlocks soon',
      body: 'Finish Stories to unlock the Sort & Match module.',
      read: true,
    ),
  ];

  void markAllRead() {
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
