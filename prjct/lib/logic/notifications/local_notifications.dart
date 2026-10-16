import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// System-tray notifications with sound + vibration. Local only: "new
/// homework" fires when the learner's device pulls it (hub open / Me tab),
/// while deadline reminders are scheduled ahead and fire even with the app
/// closed.
// ponytail: no server push — a teacher's new assignment reaches a closed app
// only on its next open. Real push needs FCM + a Cloud Function on
// `assigned_modules` writes (Blaze plan).
class LocalNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Payload tagging reminders so a reschedule can clear the stale ones.
  static const deadlinePayload = 'deadline';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'salamlearn_alerts',
      'Homework & reminders',
      channelDescription: 'New homework and upcoming deadlines',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    ),
  );

  /// Called once from `main`. Never called in tests, so every method below
  /// is a no-op there (and on platforms without a plugin setup).
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      // Android 13+ asks the user once; older versions grant it at install.
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('LocalNotifications.init failed: $e');
    }
  }

  static Future<void> show(int id, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  /// Schedules a one-off notification at [when]; past times are skipped.
  static Future<void> scheduleAt(
    int id,
    DateTime when,
    String title,
    String body, {
    String? payload,
  }) async {
    if (!_ready || !when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      // An absolute instant, so UTC needs no device time-zone lookup.
      scheduledDate: tz.TZDateTime.from(when, tz.UTC),
      notificationDetails: _details,
      // Inexact: avoids the exact-alarm permission; a reminder a few
      // minutes late is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Cancels every pending notification scheduled with [payload].
  static Future<void> cancelScheduled(String payload) async {
    if (!_ready) return;
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.payload == payload) await _plugin.cancel(id: p.id);
    }
  }
}
