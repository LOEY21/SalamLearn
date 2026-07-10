import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over Firebase Auth (FR-2.1's "online state" half of the
/// dual-state model). Deliberately not called inline from
/// `ParentRepository`/`TeacherRepository`.register — registration must
/// stay fast and work fully offline, so mirroring to Firebase Auth is the
/// `SyncManager`'s job (Phase 6), not part of the registration path itself.
class FirebaseAuthGateway {
  FirebaseAuthGateway({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;

  /// Lazy — see `FirestoreMirror._db` for why.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

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
}
