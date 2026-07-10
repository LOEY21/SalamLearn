import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../logic/auth/credential_hasher.dart';
import '../local/hive_boxes.dart';
import '../models/parent_account.dart';
import '../remote/firebase_auth_gateway.dart';
import '../remote/firestore_mirror.dart';

/// Hive-backed CRUD + credential checks for [ParentAccount] (FR-2.1, FR-2.3;
/// Diagrams Figure 5).
class ParentRepository {
  Box<ParentAccount> get _box => Hive.box<ParentAccount>(HiveBoxes.parents);

  /// [pin] is chosen by the parent themselves (entered + confirmed on the
  /// PIN-setup screen right after this form) — not system-generated.
  Future<ParentAccount> register({
    required String fullName,
    required String email,
    required String password,
    required String pin,
    String? mobileNumber,
    // Set when `SessionNotifier.beginParentEmailVerification`'s pre-PIN
    // gate already created (and sent the verification email for) this
    // Firebase user — skips the signUp/verification-send below so this
    // doesn't collide with the account that already exists.
    String? existingFirebaseUid,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (findByEmail(normalizedEmail) != null) {
      throw StateError('Email is already registered');
    }
    final passwordSalt = CredentialHasher.generateSalt();
    final pinSalt = CredentialHasher.generateSalt();

    String? firebaseUid = existingFirebaseUid;
    if (firebaseUid == null) {
      // Best-effort Firebase Auth link — this is the *only* moment this is
      // possible during registration itself, since the plaintext password is
      // discarded the instant it's hashed below. Offline (or any Firebase
      // error — e.g. a password under Firebase's 6-character minimum, or
      // Email/Password sign-in not actually enabled for this project) just
      // leaves firebaseUid null; registration must still succeed either way
      // per FR-2.1's offline-first requirement. If this does fail, the
      // account isn't permanently stuck — [linkToFirebase] can retry it
      // later with the parent re-entering their password.
      try {
        final gateway = FirebaseAuthGateway();
        final credential = await gateway.signUp(
          email: normalizedEmail,
          password: password,
        );
        firebaseUid = credential.user?.uid;
        // Best-effort — a failure here (offline right after signUp, rate
        // limit, etc.) must not undo the account that was just created.
        try {
          await gateway.sendEmailVerification();
        } catch (e) {
          debugPrint(
            'ParentRepository.register: verification email failed: $e',
          );
        }
      } on FirebaseAuthException catch (e) {
        debugPrint(
          'ParentRepository.register: Firebase Auth link failed (${e.code}): ${e.message}',
        );
        firebaseUid = null;
      } catch (e) {
        debugPrint('ParentRepository.register: Firebase Auth link failed: $e');
        firebaseUid = null;
      }
    }

    final account = ParentAccount(
      id: const Uuid().v4(),
      fullName: fullName,
      email: normalizedEmail,
      mobileNumber: mobileNumber,
      passwordHash: CredentialHasher.hash(password, passwordSalt),
      passwordSalt: passwordSalt,
      pinHash: CredentialHasher.hash(pin, pinSalt),
      pinSalt: pinSalt,
      createdAt: DateTime.now(),
      firebaseUid: firebaseUid,
    );
    await _box.put(account.id, account);
    return account;
  }

  /// Bootstraps a bare account with only a PIN — no email/password yet.
  /// Used by the `/pin/setup` fallback (router's admin-area gate) when a
  /// grown-up area is reached before any full registration happened.
  Future<ParentAccount> createPinOnly(
    String pin, {
    String fullName = 'Parent',
  }) async {
    final pinSalt = CredentialHasher.generateSalt();
    final account = ParentAccount(
      id: const Uuid().v4(),
      fullName: fullName,
      pinHash: CredentialHasher.hash(pin, pinSalt),
      pinSalt: pinSalt,
      createdAt: DateTime.now(),
    );
    await _box.put(account.id, account);
    return account;
  }

  /// FR-7.2 "sign in on any device" second half — after
  /// [FirebaseAuthGateway.signIn] has verified the password and
  /// [FirestoreMirror.fetchParentByEmail] found the cloud profile, this
  /// creates the local mirror of that account on *this* device. Reuses the
  /// cloud doc's id (so future syncs from this device update the same
  /// Firestore document instead of creating a duplicate) and re-hashes the
  /// password locally (the plaintext is only ever available transiently,
  /// right after Firebase Auth verified it — never itself synced). The PIN
  /// is a brand-new one chosen on this device, since PINs are never
  /// mirrored to the cloud.
  Future<ParentAccount> createFromRemote({
    required String id,
    required String fullName,
    required String email,
    required String password,
    required String pin,
    String? mobileNumber,
    String? firebaseUid,
  }) async {
    final passwordSalt = CredentialHasher.generateSalt();
    final pinSalt = CredentialHasher.generateSalt();
    final account = ParentAccount(
      id: id,
      fullName: fullName,
      email: email,
      mobileNumber: mobileNumber,
      passwordHash: CredentialHasher.hash(password, passwordSalt),
      passwordSalt: passwordSalt,
      pinHash: CredentialHasher.hash(pin, pinSalt),
      pinSalt: pinSalt,
      createdAt: DateTime.now(),
      firebaseUid: firebaseUid,
    );
    await _box.put(account.id, account);
    return account;
  }

  /// Retries the Firebase Auth link for an account that registered with
  /// `firebaseUid == null` (offline, or a Firebase error at the time — see
  /// [register]'s doc). The parent re-enters their password since it was
  /// never stored in plaintext; verified against the local hash first so a
  /// wrong password fails fast without ever reaching Firebase. Throws
  /// [FirebaseAuthException] with the real reason on failure (e.g.
  /// `weak-password`) instead of swallowing it, so the UI can show
  /// something actionable.
  Future<ParentAccount> linkToFirebase({
    required ParentAccount account,
    required String password,
  }) async {
    if (account.firebaseUid != null) return account;
    if (!verifyPassword(account, password)) {
      throw StateError('Incorrect password');
    }

    String firebaseUid;
    try {
      final credential = await FirebaseAuthGateway().signUp(
        email: account.email!,
        password: password,
      );
      firebaseUid = credential.user!.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      // A Firebase user for this email exists already (e.g. an earlier
      // partially-successful registration attempt) — sign into it instead
      // of creating a duplicate.
      try {
        final credential = await FirebaseAuthGateway().signIn(
          email: account.email!,
          password: password,
        );
        firebaseUid = credential.user!.uid;
      } on FirebaseAuthException catch (signInError) {
        if (signInError.code == 'invalid-credential' ||
            signInError.code == 'wrong-password') {
          throw StateError(
            'A cloud account for ${account.email} already exists with a '
            "different password than this device's local one (likely from "
            'an earlier registration attempt that partially succeeded). '
            'Delete that user in the Firebase console under Authentication, '
            'then try linking again.',
          );
        }
        rethrow;
      }
    }

    final updated = ParentAccount(
      id: account.id,
      fullName: account.fullName,
      email: account.email,
      mobileNumber: account.mobileNumber,
      passwordHash: account.passwordHash,
      passwordSalt: account.passwordSalt,
      pinHash: account.pinHash,
      pinSalt: account.pinSalt,
      createdAt: account.createdAt,
      firebaseUid: firebaseUid,
    );
    await _box.put(account.id, updated);
    return updated;
  }

  ParentAccount? findById(String id) => _box.get(id);

  /// Case-insensitive — the email is normalized to lowercase at
  /// registration time, but this also protects against callers (like the
  /// sign-in form) not normalizing what the user typed before looking it
  /// up, which would otherwise silently reject correct credentials.
  ParentAccount? findByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final account in _box.values) {
      if (account.email == normalized) return account;
    }
    return null;
  }

  /// Diagnostic-only — every locally-stored account's email (or `<none>`
  /// for a bare PIN-only account), used to trace sign-in mismatches
  /// without needing a database inspector. Not for any production code
  /// path.
  List<String> debugAllEmails() =>
      _box.values.map((a) => a.email ?? '<none>').toList();

  bool verifyPassword(ParentAccount account, String candidate) {
    if (account.passwordHash == null || account.passwordSalt == null) {
      return false;
    }
    return CredentialHasher.verify(
      candidate,
      account.passwordSalt!,
      account.passwordHash!,
    );
  }

  bool verifyPin(ParentAccount account, String candidate) =>
      CredentialHasher.verify(candidate, account.pinSalt, account.pinHash);

  /// Pushes every locally-stored parent account to Firestore (FR-7.2 sync).
  /// Skips accounts with no `firebaseUid` (registered offline, never
  /// linked) — the security rules require `firebaseUid == request.auth.uid`
  /// to write, so pushing one is guaranteed to be rejected; the "link to
  /// cloud" card in the dashboard is the actual fix for those, not a
  /// retried push. A push failure for one account (permission-denied,
  /// network) doesn't abort the rest, since sync's whole point is "push
  /// what you can" — one bad account or a mid-sync network drop shouldn't
  /// permanently block every other account/collection from ever syncing.
  Future<void> pushAll(FirestoreMirror mirror) async {
    for (final account in _box.values) {
      if (account.firebaseUid == null) continue;
      try {
        await mirror.pushParent(account);
      } catch (_) {
        // Best-effort — see doc above.
      }
    }
  }
}
