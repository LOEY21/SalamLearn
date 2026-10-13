import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_role_app.dart';

/// Thin wrapper over Firebase Auth (FR-2.1's "online state" half of the
/// dual-state model). Deliberately not called inline from
/// `ParentRepository`/`TeacherRepository`.register — registration must
/// stay fast and work fully offline, so mirroring to Firebase Auth is the
/// `SyncManager`'s job (Phase 6), not part of the registration path itself.
class FirebaseAuthGateway {
  /// [teacher] picks the teacher's own Firebase app (see [FirebaseRoleApp]);
  /// null follows the active role.
  FirebaseAuthGateway({FirebaseAuth? auth, bool? teacher})
    : _authOverride = auth,
      _teacher = teacher;

  final FirebaseAuth? _authOverride;
  final bool? _teacher;

  /// Lazy — see `FirestoreMirror._db` for why.
  FirebaseAuth get _auth =>
      _authOverride ??
      FirebaseAuth.instanceFor(app: FirebaseRoleApp.app(teacher: _teacher));

  /// The `*Teacher` methods always use the teacher app, whatever [_teacher]
  /// says — a teacher login must never land in the parent's session.
  FirebaseAuth get _teacherAuth =>
      _authOverride ??
      FirebaseAuth.instanceFor(app: FirebaseRoleApp.app(teacher: true));

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Settings "Change password". Firebase only allows this right after a
  /// sign-in, so `SessionNotifier.changePassword` re-signs in first.
  Future<void> updatePassword(String newPassword) =>
      _auth.currentUser!.updatePassword(newPassword);

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// FR-2.1's email-ownership check — sent right after [signUp] succeeds
  /// (see `ParentRepository.register`/`TeacherRepository.register`), using
  /// Firebase's own hosted verification link rather than a custom numeric
  /// code, since that needs no extra email-sending infrastructure (Cloud
  /// Functions + a mail provider) beyond what this project already has.
  /// Best-effort by design — `currentUser` is only non-null right after
  /// `signUp`/`signIn` populate it, and a missing user or a network hiccup
  /// here must never block account creation itself.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Admin-created-account activation (Teacher role only — see
  /// `auth_choice_screen.dart`'s `_ActivateView`). Doesn't require being
  /// signed in as that user — Firebase Auth sends this purely off the
  /// email address — so a teacher who's never touched this device before
  /// can trigger it themselves the first time they open the app. Also
  /// used as the "resend" action if the original link expired.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Firebase Auth allows one login per email, but a parent and a teacher
  /// may share a Gmail address with different passwords. Teacher logins on
  /// Gmail are therefore created under a `+teacher` alias — Gmail delivers
  /// it to the same inbox, so verification/reset emails still arrive. The
  /// Firestore teacher doc and everything the user sees keep the plain
  /// address. Must match `teacherAuthEmail` in admin-web/app.js.
  static String teacherAuthEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final at = normalized.lastIndexOf('@');
    if (at <= 0) return normalized;
    final local = normalized.substring(0, at);
    final domain = normalized.substring(at + 1);
    if (domain != 'gmail.com' && domain != 'googlemail.com') return normalized;
    if (local.endsWith('+teacher')) return normalized;
    return '$local+teacher@$domain';
  }

  Future<UserCredential> signUpTeacher({
    required String email,
    required String password,
  }) => _teacherAuth.createUserWithEmailAndPassword(
    email: teacherAuthEmail(email),
    password: password,
  );

  /// Tries the alias login first, then the plain address — teachers created
  /// before the alias existed still sign in with their original login.
  Future<UserCredential> signInTeacher({
    required String email,
    required String password,
  }) async {
    final alias = teacherAuthEmail(email);
    try {
      return await _teacherAuth.signInWithEmailAndPassword(
        email: alias,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (alias == email.trim().toLowerCase() ||
          e.code == 'network-request-failed' ||
          e.code == 'too-many-requests') {
        rethrow;
      }
      return _teacherAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  /// Alias only — the plain address may be a parent's login, and a reset
  /// sent there would change the parent's password.
  // ponytail: a Gmail teacher created before the alias still has a plain
  // login, so this reset never reaches them; recreate that teacher (or add
  // an email-migration step) if one needs a reset.
  Future<void> sendTeacherPasswordResetEmail(String email) =>
      _teacherAuth.sendPasswordResetEmail(email: teacherAuthEmail(email));
}
