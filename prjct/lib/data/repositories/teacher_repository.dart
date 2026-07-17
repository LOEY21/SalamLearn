import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../logic/auth/credential_hasher.dart';
import '../local/hive_boxes.dart';
import '../models/teacher_account.dart';
import '../remote/firebase_auth_gateway.dart';
import '../remote/firestore_mirror.dart';

/// Hive-backed CRUD + credential checks for [TeacherAccount] (FR-2.1,
/// FR-6.1; Diagrams Figure 6).
class TeacherRepository {
  Box<TeacherAccount> get _box => Hive.box<TeacherAccount>(HiveBoxes.teachers);

  /// [pin] is chosen by the teacher themselves (entered + confirmed on the
  /// PIN-setup screen right after this form) — not system-generated.
  Future<TeacherAccount> register({
    required String fullName,
    required String school,
    required String email,
    required String password,
    required String pin,
    String? mobileNumber,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (findByEmail(normalizedEmail) != null) {
      throw StateError('Email is already registered');
    }
    final passwordSalt = CredentialHasher.generateSalt();
    final pinSalt = CredentialHasher.generateSalt();

    // Best-effort Firebase Auth link — see the matching comment in
    // `ParentRepository.register` for why this has to happen here and
    // can't be deferred to sync time, and why a failure isn't permanent
    // ([linkToFirebase] can retry it).
    String? firebaseUid;
    try {
      final gateway = FirebaseAuthGateway();
      final credential = await gateway.signUp(
        email: normalizedEmail,
        password: password,
      );
      firebaseUid = credential.user?.uid;
      // Best-effort — see the matching comment in `ParentRepository.register`.
      try {
        await gateway.sendEmailVerification();
      } catch (e) {
        debugPrint('TeacherRepository.register: verification email failed: $e');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'TeacherRepository.register: Firebase Auth link failed (${e.code}): ${e.message}',
      );
      firebaseUid = null;
    } catch (e) {
      debugPrint('TeacherRepository.register: Firebase Auth link failed: $e');
      firebaseUid = null;
    }

    final account = TeacherAccount(
      id: const Uuid().v4(),
      fullName: fullName,
      school: school,
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

  /// Bootstraps a bare account with only a PIN — see
  /// `ParentRepository.createPinOnly` for why this exists.
  Future<TeacherAccount> createPinOnly(
    String pin, {
    String fullName = 'Asatidz',
  }) async {
    final pinSalt = CredentialHasher.generateSalt();
    final account = TeacherAccount(
      id: const Uuid().v4(),
      fullName: fullName,
      pinHash: CredentialHasher.hash(pin, pinSalt),
      pinSalt: pinSalt,
      createdAt: DateTime.now(),
    );
    await _box.put(account.id, account);
    return account;
  }

  /// See `ParentRepository.createFromRemote` doc — same "sign in on any
  /// device" second half, for a teacher account.
  Future<TeacherAccount> createFromRemote({
    required String id,
    required String fullName,
    required String email,
    required String password,
    required String pin,
    String? school,
    String? mobileNumber,
    String? firebaseUid,
  }) async {
    final passwordSalt = CredentialHasher.generateSalt();
    final pinSalt = CredentialHasher.generateSalt();
    final account = TeacherAccount(
      id: id,
      fullName: fullName,
      school: school,
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

  /// See `ParentRepository.linkToFirebase` doc — same retry contract for
  /// a teacher account that registered with `firebaseUid == null`.
  Future<TeacherAccount> linkToFirebase({
    required TeacherAccount account,
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

    final updated = TeacherAccount(
      id: account.id,
      fullName: account.fullName,
      school: account.school,
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

  TeacherAccount? findById(String id) => _box.get(id);

  /// Case-insensitive — see `ParentRepository.findByEmail` doc for why.
  TeacherAccount? findByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final account in _box.values) {
      if (account.email == normalized) return account;
    }
    return null;
  }

  /// Diagnostic-only — see `ParentRepository.debugAllEmails` doc.
  List<String> debugAllEmails() =>
      _box.values.map((a) => a.email ?? '<none>').toList();

  /// See `ParentRepository.updatePasswordLocally` doc — same "resync from a
  /// remote password reset" contract for a teacher account.
  Future<TeacherAccount> updatePasswordLocally({
    required TeacherAccount account,
    required String newPassword,
  }) async {
    final passwordSalt = CredentialHasher.generateSalt();
    final updated = TeacherAccount(
      id: account.id,
      fullName: account.fullName,
      school: account.school,
      email: account.email,
      mobileNumber: account.mobileNumber,
      passwordHash: CredentialHasher.hash(newPassword, passwordSalt),
      passwordSalt: passwordSalt,
      pinHash: account.pinHash,
      pinSalt: account.pinSalt,
      createdAt: account.createdAt,
      firebaseUid: account.firebaseUid,
    );
    await _box.put(account.id, updated);
    return updated;
  }

  bool verifyPassword(TeacherAccount account, String candidate) {
    if (account.passwordHash == null || account.passwordSalt == null) {
      return false;
    }
    return CredentialHasher.verify(
      candidate,
      account.passwordSalt!,
      account.passwordHash!,
    );
  }

  bool verifyPin(TeacherAccount account, String candidate) =>
      CredentialHasher.verify(candidate, account.pinSalt, account.pinHash);

  /// See `ParentRepository.pushAll` doc — same skip-unlinked /
  /// best-effort-per-account contract.
  Future<void> pushAll(FirestoreMirror mirror) async {
    for (final account in _box.values) {
      if (account.firebaseUid == null) continue;
      try {
        await mirror.pushTeacher(account);
      } catch (_) {
        // Best-effort — see doc above.
      }
    }
  }
}
