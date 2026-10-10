import 'package:firebase_core/firebase_core.dart';

/// Firebase Auth keeps exactly one signed-in user per [FirebaseApp]. On a
/// phone shared by a parent and a teacher, one app meant switching roles
/// with the (local-only) PIN left Firebase signed in as the *other* account,
/// so every write failed with `permission-denied`.
///
/// The teacher therefore gets a second app instance — same project, same
/// options — with its own persisted sign-in. Parent and learner work stay on
/// the default app. Both remain signed in; switching roles just switches
/// which app [FirebaseAuthGateway] / [FirestoreMirror] talk to.
class FirebaseRoleApp {
  static const _teacherAppName = 'teacher';

  /// Set by `SessionNotifier` — true while the active role is the teacher.
  static bool Function() isTeacherActive = () => false;

  static Future<void> initTeacherApp(FirebaseOptions options) =>
      Firebase.initializeApp(name: _teacherAppName, options: options);

  /// [teacher] null means "follow the active role".
  static FirebaseApp app({bool? teacher}) => (teacher ?? isTeacherActive())
      ? Firebase.app(_teacherAppName)
      : Firebase.app();
}
