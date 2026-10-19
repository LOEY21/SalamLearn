import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/remote/firestore_mirror.dart';

/// Admin-generated teacher sign-in ID, "YYYY-NNNNNN" (admin-web
/// `generateEmployeeId`). Returns the canonical form, or null if [input]
/// isn't one, so "2026 483915" and "2026483915" both work.
String? normalizeEmployeeId(String input) {
  final digits = input.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d{10}$').hasMatch(digits)) return null;
  return '${digits.substring(0, 4)}-${digits.substring(4)}';
}

/// "jude@gmail.com" -> "j***@gmail.com"
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email[0]}***${email.substring(at)}';
}

/// Settings-box keys caching a teacher's Employee ID on this device, so the
/// ID works offline once they've signed in here and Personal Info can show it.
String employeeIdKey(String teacherId) => 'employeeId_$teacherId';
String employeeIdEmailKey(String employeeId) => 'employeeIdEmail_$employeeId';

/// Turns what a teacher typed into the email to sign in / activate with.
/// Emails pass through; an Employee ID resolves via this device's cache,
/// then `teacherIds` on the server. Null = unknown ID; throws when offline.
Future<String?> resolveTeacherLoginEmail(String input) async {
  final trimmed = input.trim();
  if (trimmed.contains('@')) return trimmed;
  final id = normalizeEmployeeId(trimmed);
  if (id == null) return null;
  final cached =
      Hive.box<dynamic>(HiveBoxes.settings).get(employeeIdEmailKey(id))
          as String?;
  return cached ?? await FirestoreMirror(teacher: true).emailForEmployeeId(id);
}
