import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/models/assigned_module.dart';
import '../../data/models/badge_award.dart';
import '../../data/models/class_section.dart';
import '../../data/models/consent_record.dart';
import '../../data/models/enrollment.dart';
import '../../data/models/learner_profile.dart';
import '../../data/models/parent_account.dart';
import '../../data/models/progress_record.dart';
import '../../data/models/streak_state.dart';
import '../../data/models/teacher_account.dart';
import '../theme/app_colors.dart';

/// Debug-only Hive contents viewer — since there's no external table
/// browser for Hive's on-disk boxes (unlike Firestore's console), this is
/// how you actually see what `HiveService.init()`'s boxes hold. Only wire
/// this in behind `kDebugMode` (the settings screen entry point already
/// does) — it prints raw local data, including partial credential hashes.
class DatabaseInspectorScreen extends StatelessWidget {
  const DatabaseInspectorScreen({super.key});

  static const _boxNames = [
    HiveBoxes.parents,
    HiveBoxes.teachers,
    HiveBoxes.learners,
    HiveBoxes.consents,
    HiveBoxes.classes,
    HiveBoxes.enrollments,
    HiveBoxes.progress,
    HiveBoxes.assignedModules,
    HiveBoxes.streaks,
    HiveBoxes.badges,
    HiveBoxes.settings,
  ];

  @override
  Widget build(BuildContext context) {
    // Only ever reached from Settings — this app navigates exclusively via
    // `context.go()` (never `.push()`), so without this, hardware back
    // falls through to exiting the app instead of returning there.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/settings');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hive database inspector'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/settings'),
          ),
          actions: [
            TextButton(
              onPressed: () => _resetTutorial(context),
              child: const Text(
                'Reset tutorial',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final name in _boxNames) _BoxSection(boxName: name),
          ],
        ),
      ),
    );
  }
}

/// Clears every learner's `tutorial_seen_<id>` flag from the `settings`
/// box, so the first-run mascot tutorial (`MascotTutorialOverlay`) fires
/// again next time any learner opens the Adventure Map — the flag is
/// permanent once set (see `TutorialSeenNotifier.markSeen`), and a single
/// stray tap during testing is enough to set it, so this is the fast way
/// back to "unseen" without wiping the whole settings box or reinstalling.
void _resetTutorial(BuildContext context) {
  final settings = Hive.box<dynamic>(HiveBoxes.settings);
  final keys = settings.keys.where(
    (k) => k is String && k.startsWith('tutorial_seen_'),
  );
  settings.deleteAll(keys);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Cleared ${keys.length} tutorial_seen flag(s)')),
  );
}

class _BoxSection extends StatelessWidget {
  const _BoxSection({required this.boxName});

  final String boxName;

  @override
  Widget build(BuildContext context) {
    // Hive refuses to hand back an already-open box under a different type
    // parameter — `Hive.box<dynamic>(name)` throws `HiveError: ... already
    // open and of type Box<X>` for every box HiveService.init() opened
    // typed. Each box has to be re-fetched with its original type.
    final entries = _readBox(boxName);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(
          '$boxName (${entries.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: entries.isEmpty
            ? [const Padding(padding: EdgeInsets.all(12), child: Text('empty'))]
            : [
                for (final entry in entries)
                  _RecordTile(recordKey: entry.key, value: entry.value),
              ],
      ),
    );
  }
}

List<MapEntry<dynamic, dynamic>> _readBox(String boxName) {
  Box<T> typed<T>() => Hive.box<T>(boxName);
  final Iterable<MapEntry<dynamic, dynamic>> entries = switch (boxName) {
    HiveBoxes.parents => typed<ParentAccount>().toMap().entries,
    HiveBoxes.teachers => typed<TeacherAccount>().toMap().entries,
    HiveBoxes.learners => typed<LearnerProfile>().toMap().entries,
    HiveBoxes.consents => typed<ConsentRecord>().toMap().entries,
    HiveBoxes.classes => typed<ClassSection>().toMap().entries,
    HiveBoxes.enrollments => typed<Enrollment>().toMap().entries,
    HiveBoxes.progress => typed<ProgressRecord>().toMap().entries,
    HiveBoxes.assignedModules => typed<AssignedModule>().toMap().entries,
    HiveBoxes.streaks => typed<StreakState>().toMap().entries,
    HiveBoxes.badges => typed<BadgeAward>().toMap().entries,
    _ => typed<dynamic>().toMap().entries,
  };
  return entries.toList();
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.recordKey, required this.value});

  final dynamic recordKey;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final fields = _describe(value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'key: $recordKey',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
          for (final entry in fields.entries)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          const Divider(),
        ],
      ),
    );
  }
}

/// Masks a hash/salt down to its first 8 chars — enough to eyeball "yes
/// this got hashed, not stored as plain text" without printing the whole
/// secret onto a debug screen.
String? _mask(String? value) => value == null ? null : '${value.substring(0, value.length.clamp(0, 8))}…';

Map<String, dynamic> _describe(dynamic value) {
  return switch (value) {
    ParentAccount a => {
        'id': a.id,
        'fullName': a.fullName,
        'email': a.email,
        'mobileNumber': a.mobileNumber,
        'passwordHash': _mask(a.passwordHash),
        'pinHash': _mask(a.pinHash),
        'firebaseUid': a.firebaseUid,
        'createdAt': a.createdAt,
      },
    TeacherAccount t => {
        'id': t.id,
        'fullName': t.fullName,
        'school': t.school,
        'email': t.email,
        'mobileNumber': t.mobileNumber,
        'passwordHash': _mask(t.passwordHash),
        'pinHash': _mask(t.pinHash),
        'firebaseUid': t.firebaseUid,
        'createdAt': t.createdAt,
      },
    LearnerProfile l => {
        'id': l.id,
        'parentId': l.parentId,
        'name': l.name,
        'age': l.age,
        'avatar': l.avatar,
        'gradeLevel': l.gradeLevel,
        'username': l.username,
        'passwordHash': _mask(l.passwordHash),
        'createdAt': l.createdAt,
      },
    ConsentRecord c => {'agreedAt': c.agreedAt},
    ClassSection c => {
        'id': c.id,
        'teacherId': c.teacherId,
        'name': c.name,
        'invitationCode': c.invitationCode,
        'createdAt': c.createdAt,
      },
    Enrollment e => {
        'classId': e.classId,
        'learnerId': e.learnerId,
        'enrolledAt': e.enrolledAt,
      },
    ProgressRecord p => {
        'id': p.id,
        'learnerId': p.learnerId,
        'moduleId': p.moduleId,
        'strokeAccuracyPct': p.strokeAccuracyPct,
        'sequencingErrors': p.sequencingErrors,
        'timeOnTaskSeconds': p.timeOnTaskSeconds,
        'completedAt': p.completedAt,
        'assignedByTeacher': p.assignedByTeacher,
      },
    AssignedModule m => {
        'id': m.id,
        'classId': m.classId,
        'learnerId': m.learnerId,
        'moduleId': m.moduleId,
        'dueDate': m.dueDate,
        'assignedAt': m.assignedAt,
      },
    StreakState s => {
        'learnerId': s.learnerId,
        'currentStreak': s.currentStreak,
        'lastPlayedDate': s.lastPlayedDate,
      },
    BadgeAward b => {
        'learnerId': b.learnerId,
        'badgeId': b.badgeId,
        'earnedAt': b.earnedAt,
      },
    _ => {'value': value.toString()},
  };
}
