import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/models/consent_record.dart';
import '../../data/models/learner_profile.dart';
import '../../data/repositories/consent_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../data/remote/firebase_auth_gateway.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../data/repositories/parent_repository.dart';
import '../../data/repositories/teacher_repository.dart';
import '../sync/sync_manager.dart';

enum UserRole { learner, parent, asatidz }

/// Outcome of [SessionNotifier.signIn].
enum SignInResult {
  /// A local account matched — the PIN gate is next, same as always.
  success,

  /// No local account, but Firebase Auth + the cloud profile matched (FR-7.2
  /// "sign in on any device"). A pending registration was staged just like
  /// the sign-up form does; the caller must route to `/pin/setup` next so
  /// this device gets its own local PIN (PINs are never mirrored).
  needsLocalPinSetup,

  /// Neither the local account nor (if tried) Firebase Auth accepted the
  /// credentials.
  invalidCredentials,

  /// No local account matched, and this device has no internet connection
  /// to try the remote fallback — genuinely different from wrong
  /// credentials, so the UI shouldn't say "incorrect password" (misleading)
  /// or count it against the attempt-limit lockout (not the user's fault).
  noInternet,
}

/// Session state backed by real Hive-persisted accounts (Phase 4 of the
/// backend plan) — [activeParentId]/[activeTeacherId] point at whichever
/// [ParentAccount]/[TeacherAccount] is currently signed in on this device;
/// [learner] is the active child profile. Everything here survives an app
/// restart because it's a thin view over Hive-backed repositories, not the
/// source of truth itself.
class SessionState {
  const SessionState({
    this.activeRole,
    this.pinVerified = false,
    this.activeParentId,
    this.activeTeacherId,
    this.learner,
    this.consent,
    this.languageCode,
  });

  final UserRole? activeRole;
  final bool pinVerified;
  final String? activeParentId;
  final String? activeTeacherId;
  final LearnerProfile? learner;
  final ConsentRecord? consent;
  final String? languageCode;

  bool get onboarded => languageCode != null;
  bool get consented => consent != null;

  /// Whether the *current* [activeRole] already has an account on this
  /// device — the router uses this to decide `/pin/verify` (account
  /// exists, just needs the PIN) vs `/pin/setup` (bootstrap one first).
  bool get hasPin => activeRole == UserRole.asatidz
      ? activeTeacherId != null
      : activeParentId != null;

  SessionState copyWith({
    UserRole? activeRole,
    bool? pinVerified,
    String? activeParentId,
    String? activeTeacherId,
    LearnerProfile? learner,
    ConsentRecord? consent,
    String? languageCode,
    bool clearRole = false,
  }) {
    return SessionState(
      activeRole: clearRole ? null : activeRole ?? this.activeRole,
      pinVerified: pinVerified ?? this.pinVerified,
      activeParentId: activeParentId ?? this.activeParentId,
      activeTeacherId: activeTeacherId ?? this.activeTeacherId,
      learner: learner ?? this.learner,
      consent: consent ?? this.consent,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}

/// A registration form's collected fields, held only in memory between
/// "form submitted" and "PIN chosen" — never persisted until
/// [SessionNotifier.createPin] finalizes it with the user's own PIN.
class _PendingParentRegistration {
  _PendingParentRegistration({
    required this.fullName,
    required this.email,
    required this.password,
    this.mobileNumber,
    this.remoteId,
    this.remoteFirebaseUid,
  });

  final String fullName;
  final String email;
  final String password;
  final String? mobileNumber;

  /// Set only when this pending registration came from [SessionNotifier]'s
  /// "sign in on any device" remote fallback — tells [SessionNotifier.createPin]
  /// to reuse the cloud doc's id/firebaseUid via
  /// `ParentRepository.createFromRemote` instead of minting a brand-new
  /// local-only account via `register`.
  final String? remoteId;
  final String? remoteFirebaseUid;

  /// Set by [SessionNotifier.beginParentEmailVerification] — the Parent-only
  /// pre-PIN email verification gate creates the Firebase Auth user (and
  /// sends its verification link) right after the sign-up form, well before
  /// [SessionNotifier.createPin] normally would. Not `final`: it starts
  /// null and is filled in once that gate step succeeds, so `createPin`
  /// can tell "already created, reuse this uid" apart from "gate never ran
  /// or failed, create it now" without a second field.
  String? firebaseUid;
}

class _PendingTeacherRegistration {
  const _PendingTeacherRegistration({
    required this.fullName,
    required this.school,
    required this.email,
    required this.password,
    this.mobileNumber,
    this.remoteId,
    this.remoteFirebaseUid,
  });

  final String fullName;
  final String school;
  final String email;
  final String password;
  final String? mobileNumber;

  /// See `_PendingParentRegistration.remoteId` doc.
  final String? remoteId;
  final String? remoteFirebaseUid;
}

class SessionNotifier extends Notifier<SessionState> {
  final _parents = ParentRepository();
  final _teachers = TeacherRepository();
  final _learners = LearnerRepository();
  final _consents = ConsentRepository();

  _PendingParentRegistration? _pendingParent;
  _PendingTeacherRegistration? _pendingTeacher;

  /// Whether the PIN about to be set up is for an account that already
  /// exists remotely (just verified via email + password on this new
  /// device) rather than a brand-new one — the PIN-setup screen uses this
  /// to skip the enter-then-confirm double entry (identity is already
  /// proven; the PIN here is purely "pick this device's local unlock
  /// code", not a from-scratch credential that needs a typo safety net).
  bool get pendingIsRemoteLinked =>
      _pendingParent?.remoteId != null || _pendingTeacher?.remoteId != null;

  /// Single device-level consent key — one parent's consent covers every
  /// learner they create on this device (FR-2.2 doesn't model per-child
  /// consent, just "the parent agreed").
  static const _consentKey = 'device';

  Box<dynamic> get _settings => Hive.box<dynamic>(HiveBoxes.settings);

  /// Rehydrates session state from Hive on every app start — without this,
  /// the account/learner data a user just created is still safely on disk
  /// (that's why re-registering the same email correctly says "already
  /// registered"), but the in-memory session forgets it ever existed the
  /// moment the app restarts, since `Notifier.build()` used to always
  /// return a blank `SessionState`. `pinVerified` deliberately does *not*
  /// rehydrate to true — restarting the app must always re-prompt the PIN,
  /// same as the flowchart's "Enter PIN" gate on every return visit.
  @override
  SessionState build() {
    final languageCode = _settings.get('languageCode') as String?;
    final roleName = _settings.get('activeRole') as String?;

    // A stored id whose record no longer exists (e.g. a partial data wipe,
    // or `pm clear`/reinstall leaving the `settings` box out of sync with
    // the entity boxes) must not read as "has an account" — otherwise
    // `hasPin` reports true for an account that can never actually verify,
    // permanently stranding the user on the PIN gate. Drop the dangling id
    // right away instead of just hiding the symptom in `hasPin`.
    var activeParentId = _settings.get('activeParentId') as String?;
    if (activeParentId != null && _parents.findById(activeParentId) == null) {
      _settings.delete('activeParentId');
      activeParentId = null;
    }
    var activeTeacherId = _settings.get('activeTeacherId') as String?;
    if (activeTeacherId != null &&
        _teachers.findById(activeTeacherId) == null) {
      _settings.delete('activeTeacherId');
      activeTeacherId = null;
    }
    var activeLearnerId = _settings.get('activeLearnerId') as String?;
    final learner = activeLearnerId == null
        ? null
        : _learners.findById(activeLearnerId);
    if (activeLearnerId != null && learner == null) {
      _settings.delete('activeLearnerId');
    }

    return SessionState(
      languageCode: languageCode,
      consent: _consents.get(_consentKey),
      activeRole: roleName == null ? null : UserRole.values.byName(roleName),
      activeParentId: activeParentId,
      activeTeacherId: activeTeacherId,
      learner: learner,
      pinVerified: false,
    );
  }

  void setLanguage(String code) {
    _settings.put('languageCode', code);
    state = state.copyWith(languageCode: code);
  }

  Future<void> giveConsent() async {
    final record = ConsentRecord(agreedAt: DateTime.now());
    await _consents.save(_consentKey, record);
    state = state.copyWith(consent: record);
  }

  /// Picking Parent/Asatidz on the role picker is only a transient "which
  /// screen am I looking at right now" choice — it must NOT be persisted
  /// yet. Only [createPin]/[signIn] (an account actually being
  /// authenticated) makes *that* role durable across restarts; otherwise
  /// merely tapping "Parent" and backing out would permanently claim this
  /// device for the parent role with no account behind it, stranding the
  /// next launch on a PIN-setup screen it can never get past normally.
  ///
  /// Switching *into* the Learner role is different: it's not a
  /// registration choice, it's "hand the device to the child now," and the
  /// grown-up quitting mid-session (or the child themselves) should come
  /// back to the Learner Hub on the next launch, not bounce to the role
  /// picker or the grown-up's own PIN-gated dashboard — `splash_screen.dart`
  /// already sends `UserRole.learner` straight to `/hub` on cold start, so
  /// this just needs to actually survive a restart. Re-entering Parent/
  /// Asatidz mode from inside the hub (e.g. `profile_screen.dart`'s "Parent
  /// Settings" row) still only sets it transiently — it stays PIN-gated
  /// every time either way, since `pinVerified` never rehydrates to true.
  void selectRole(UserRole role) {
    state = state.copyWith(activeRole: role, pinVerified: false);
    if (role == UserRole.learner) {
      _settings.put('activeRole', role.name);
    }
  }

  /// Sign-up form's immediate "is this email already registered on this
  /// device" check — lets the UI warn right on the email field the moment
  /// "Create account" is tapped, instead of only surfacing
  /// `ParentRepository.register`'s `StateError` after the user has also
  /// gone through the PIN screen. Local-only: a device that's never seen
  /// this email before will still let registration proceed here even if
  /// the email is already registered on a *different* device, since
  /// checking that would mean querying Firestore by email pre-auth — the
  /// security rules deliberately block that (see `firestore.rules`'
  /// `/parents`/`/teachers` doc) to prevent account-enumeration.
  bool emailTaken({required UserRole role, required String email}) {
    return role == UserRole.asatidz
        ? _teachers.findByEmail(email) != null
        : _parents.findByEmail(email) != null;
  }

  /// FR-2.3/Figure 5 — stages a parent's personal-info form. Nothing is
  /// persisted yet; the account is only actually created once they've
  /// chosen and confirmed their own PIN on the next screen (see
  /// [createPin]) — that's the "enter PIN, confirm PIN" step, not a
  /// system-generated one.
  void stageParentRegistration({
    required String fullName,
    required String email,
    required String password,
    String? mobileNumber,
  }) {
    _pendingParent = _PendingParentRegistration(
      fullName: fullName,
      email: email,
      password: password,
      mobileNumber: mobileNumber,
    );
    state = state.copyWith(activeRole: UserRole.parent, pinVerified: false);
  }

  /// The staged parent's email — read by the email-verification gate
  /// screen to show "we sent a link to X" without exposing `_pendingParent`
  /// itself outside this notifier.
  String? get pendingParentEmail => _pendingParent?.email;

  /// Parent-only pre-PIN email verification gate (see
  /// `email_verification_gate_screen.dart`). Unlike the normal flow, where
  /// `ParentRepository.register` creates the Firebase Auth user and sends
  /// its verification link at PIN-creation time, this creates that user
  /// *now* — right after the sign-up form, before the PIN screen — so the
  /// gate screen has a real account to check `emailVerified` against. The
  /// resulting uid is stashed on `_pendingParent` so `createPin` reuses it
  /// instead of calling `signUp` a second time (which would either throw
  /// `email-already-in-use` or silently create a duplicate).
  ///
  /// Best-effort by design, matching every other Firebase touchpoint in
  /// this class: offline or any Firebase error just returns false so the
  /// gate screen can offer "continue anyway" rather than permanently
  /// stranding an offline-first registration on a network call.
  Future<bool> beginParentEmailVerification() async {
    final pending = _pendingParent;
    if (pending == null) return false;
    if (pending.firebaseUid != null) return true;
    try {
      final gateway = FirebaseAuthGateway();
      final credential = await gateway.signUp(
        email: pending.email,
        password: pending.password,
      );
      final uid = credential.user?.uid;
      if (uid == null) return false;
      pending.firebaseUid = uid;
      await gateway.sendEmailVerification();
      return true;
    } catch (e) {
      debugPrint('beginParentEmailVerification failed: $e');
      return false;
    }
  }

  /// Re-fetches the Firebase user (`emailVerified` only updates locally
  /// after a `reload()`) and reports whether the gate can let the parent
  /// through to PIN setup now.
  Future<bool> refreshParentEmailVerified() async {
    final gateway = FirebaseAuthGateway();
    final user = gateway.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {
      return false;
    }
    return gateway.currentUser?.emailVerified ?? false;
  }

  /// FR-6.1/Figure 6 — same staging step as [stageParentRegistration], for
  /// the teacher form.
  void stageTeacherRegistration({
    required String fullName,
    required String school,
    required String email,
    required String password,
    String? mobileNumber,
  }) {
    _pendingTeacher = _PendingTeacherRegistration(
      fullName: fullName,
      school: school,
      email: email,
      password: password,
      mobileNumber: mobileNumber,
    );
    state = state.copyWith(activeRole: UserRole.asatidz, pinVerified: false);
  }

  /// PIN-setup screen's "create + confirm" step. Two cases:
  /// - A registration form was just staged (`stageParentRegistration`/
  ///   `stageTeacherRegistration`) — finalize it now, creating the real
  ///   account with this PIN.
  /// - No pending registration (the `/pin/setup` router fallback, reached
  ///   when a grown-up area is hit before any registration happened, e.g.
  ///   a direct deep link) — bootstrap a bare PIN-only account instead.
  Future<void> createPin(String pin) async {
    // Only now — an account is actually about to exist — does the role
    // become durable across restarts. See [selectRole]'s doc for why this
    // can't happen any earlier.
    await _settings.put(
      'activeRole',
      state.activeRole?.name ?? UserRole.parent.name,
    );

    if (state.activeRole == UserRole.asatidz) {
      final pending = _pendingTeacher;
      if (pending != null) {
        _pendingTeacher = null;
        final account = pending.remoteId != null
            ? await _teachers.createFromRemote(
                id: pending.remoteId!,
                fullName: pending.fullName,
                school: pending.school,
                email: pending.email,
                password: pending.password,
                mobileNumber: pending.mobileNumber,
                pin: pin,
                firebaseUid: pending.remoteFirebaseUid,
              )
            : await _teachers.register(
                fullName: pending.fullName,
                school: pending.school,
                email: pending.email,
                password: pending.password,
                mobileNumber: pending.mobileNumber,
                pin: pin,
              );
        // Best-effort initial push — without this, a brand-new account
        // only ever reaches Firestore the next time something calls
        // `SyncManager.syncNow()` (the Settings "Sync now" button, or a
        // connectivity-change listener that isn't reliably kept alive).
        // The admin web panel reads Firestore only, so a just-registered
        // account would otherwise look "missing" there indefinitely even
        // though local registration fully succeeded.
        if (pending.remoteId == null && account.firebaseUid != null) {
          try {
            await FirestoreMirror().pushTeacher(account);
          } catch (e) {
            debugPrint('createPin: initial teacher push failed: $e');
          }
        }
        await _settings.put('activeTeacherId', account.id);
        state = state.copyWith(activeTeacherId: account.id, pinVerified: true);
        return;
      }
      final account = await _teachers.createPinOnly(pin);
      await _settings.put('activeTeacherId', account.id);
      state = state.copyWith(activeTeacherId: account.id, pinVerified: true);
    } else {
      final pending = _pendingParent;
      if (pending != null) {
        _pendingParent = null;
        final account = pending.remoteId != null
            ? await _parents.createFromRemote(
                id: pending.remoteId!,
                fullName: pending.fullName,
                email: pending.email,
                password: pending.password,
                mobileNumber: pending.mobileNumber,
                pin: pin,
                firebaseUid: pending.remoteFirebaseUid,
              )
            : await _parents.register(
                fullName: pending.fullName,
                email: pending.email,
                password: pending.password,
                mobileNumber: pending.mobileNumber,
                pin: pin,
                // Set when the email-verification gate already created
                // this Firebase user (see `beginParentEmailVerification`'s
                // doc) — skips `register`'s own signUp so it doesn't
                // collide with the one that already exists.
                existingFirebaseUid: pending.firebaseUid,
              );
        // See the matching comment in the teacher branch above.
        if (pending.remoteId == null && account.firebaseUid != null) {
          try {
            await FirestoreMirror().pushParent(account);
          } catch (e) {
            debugPrint('createPin: initial parent push failed: $e');
          }
        }
        await _settings.put('activeParentId', account.id);
        state = state.copyWith(activeParentId: account.id, pinVerified: true);
        if (pending.remoteId != null) await _pullLearnersFromRemote(account.id);
        return;
      }
      final account = await _parents.createPinOnly(pin);
      await _settings.put('activeParentId', account.id);
      state = state.copyWith(activeParentId: account.id, pinVerified: true);
    }
  }

  /// FR-7.2 "sign in on any device" — pulls every child profile Firestore
  /// has for [parentId] down onto this device right after its account is
  /// (re-)created here, so the Parent Dashboard isn't empty on a device
  /// that's never seen this parent before. Best-effort: offline or a
  /// permission hiccup just leaves the dashboard empty for now rather than
  /// blocking PIN setup from completing.
  ///
  /// Sets the first pulled child as `state.learner` — `parentLearnersProvider`
  /// only recomputes when `activeParentId` or the active learner's id
  /// changes (see its doc), and `activeParentId` has already changed by the
  /// time this runs, so without also touching `learner` here the roster
  /// would silently never refresh again after this one pull completes.
  Future<void> _pullLearnersFromRemote(String parentId) async {
    try {
      final remoteLearners = await FirestoreMirror().fetchLearnersForParent(
        parentId,
      );
      LearnerProfile? first;
      for (final remote in remoteLearners) {
        final saved = await _learners.saveFromRemote(
          id: remote.id,
          parentId: parentId,
          name: remote.name,
          age: remote.age,
          avatar: remote.avatar,
          gradeLevel: remote.gradeLevel,
          username: remote.username,
          createdAt: remote.createdAt,
        );
        first ??= saved;
      }
      if (first != null) {
        await _settings.put('activeLearnerId', first.id);
        state = state.copyWith(learner: first);
      }
    } catch (e) {
      debugPrint('SessionNotifier: pulling remote learners failed: $e');
    }
  }

  /// FR-2.1 first factor — email + password, checked *before* the PIN
  /// gate. On success, marks the matching account active (so the PIN
  /// screen that follows checks the right account) but deliberately
  /// leaves `pinVerified` false — the PIN is still a required second
  /// factor.
  ///
  /// If no local account matches, falls back to FR-7.2's "sign in on any
  /// device" path: verifies against Firebase Auth (the real credential
  /// store once online) and, if that succeeds, pulls the profile down from
  /// Firestore and stages it as a pending registration — same shape the
  /// sign-up form produces — so [createPin] can finish setting up this
  /// device with its own local PIN. Returns [SignInResult.invalidCredentials]
  /// for both "no such email" and "wrong password" either locally or in the
  /// cloud, so the UI can't distinguish account existence from a typo.
  Future<SignInResult> signIn({
    required UserRole role,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint(
      'SessionNotifier.signIn: role=$role email="$normalizedEmail" '
      'localParents=${_parents.debugAllEmails()} localTeachers=${_teachers.debugAllEmails()}',
    );

    if (role == UserRole.asatidz) {
      final account = _teachers.findByEmail(normalizedEmail);
      debugPrint(
        'SessionNotifier.signIn: teacher local match=${account != null}',
      );
      if (account != null) {
        if (!_teachers.verifyPassword(account, password)) {
          return SignInResult.invalidCredentials;
        }
        await _settings.put('activeRole', role.name);
        await _settings.put('activeTeacherId', account.id);
        state = state.copyWith(
          activeRole: role,
          activeTeacherId: account.id,
          pinVerified: false,
        );
        return SignInResult.success;
      }
      return _tryRemoteTeacherSignIn(
        email: normalizedEmail,
        password: password,
      );
    } else {
      final account = _parents.findByEmail(normalizedEmail);
      debugPrint(
        'SessionNotifier.signIn: parent local match=${account != null}',
      );
      if (account != null) {
        if (!_parents.verifyPassword(account, password)) {
          return SignInResult.invalidCredentials;
        }
        await _settings.put('activeRole', role.name);
        await _settings.put('activeParentId', account.id);
        state = state.copyWith(
          activeRole: role,
          activeParentId: account.id,
          pinVerified: false,
          learner: _resolveActiveLearnerFor(account.id),
        );
        return SignInResult.success;
      }
      return _tryRemoteParentSignIn(email: normalizedEmail, password: password);
    }
  }

  /// Restores the previously-active child (if any) for a parent who just
  /// signed back in — `activeLearnerId` survives [logout] specifically so
  /// this can find it. Guards on `parentId` so a stale pointer never leaks
  /// a different parent's child on a shared device.
  LearnerProfile? _resolveActiveLearnerFor(String parentId) {
    final learnerId = _settings.get('activeLearnerId') as String?;
    if (learnerId == null) return null;
    final learner = _learners.findById(learnerId);
    if (learner == null || learner.parentId != parentId) return null;
    return learner;
  }

  /// Checked before every remote sign-in attempt — Firebase Auth's own
  /// `network-request-failed` exception isn't a reliable way to detect
  /// "offline" (it can also fire for other transient reasons, and takes a
  /// full request timeout to surface), so this checks the OS-level
  /// connectivity state directly and fails fast instead.
  Future<bool> _hasInternet() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<SignInResult> _tryRemoteParentSignIn({
    required String email,
    required String password,
  }) async {
    if (!await _hasInternet()) return SignInResult.noInternet;
    try {
      final gateway = FirebaseAuthGateway();
      final credential = await gateway.signIn(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) return SignInResult.invalidCredentials;
      final remote = await FirestoreMirror().fetchParentByFirebaseUid(uid);
      if (remote == null) return SignInResult.invalidCredentials;
      _pendingParent = _PendingParentRegistration(
        fullName: remote.fullName,
        email: email,
        password: password,
        mobileNumber: remote.mobileNumber,
        remoteId: remote.id,
        remoteFirebaseUid: remote.firebaseUid,
      );
      state = state.copyWith(activeRole: UserRole.parent, pinVerified: false);
      return SignInResult.needsLocalPinSetup;
    } catch (e) {
      // Wrong password, no such Firebase user, or Firestore unreachable —
      // all read the same to the UI ("invalid credentials"); logged here
      // for diagnosis without exposing raw exception text to the user.
      debugPrint('SessionNotifier: remote parent sign-in failed: $e');
      return SignInResult.invalidCredentials;
    }
  }

  Future<SignInResult> _tryRemoteTeacherSignIn({
    required String email,
    required String password,
  }) async {
    if (!await _hasInternet()) return SignInResult.noInternet;
    try {
      final gateway = FirebaseAuthGateway();
      final credential = await gateway.signIn(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) return SignInResult.invalidCredentials;
      final remote = await FirestoreMirror().fetchTeacherByFirebaseUid(uid);
      if (remote == null) return SignInResult.invalidCredentials;
      _pendingTeacher = _PendingTeacherRegistration(
        fullName: remote.fullName,
        school: remote.school ?? '',
        email: email,
        password: password,
        mobileNumber: remote.mobileNumber,
        remoteId: remote.id,
        remoteFirebaseUid: remote.firebaseUid,
      );
      state = state.copyWith(activeRole: UserRole.asatidz, pinVerified: false);
      return SignInResult.needsLocalPinSetup;
    } catch (e) {
      debugPrint('SessionNotifier: remote teacher sign-in failed: $e');
      return SignInResult.invalidCredentials;
    }
  }

  /// FR-2.1 dual-state PIN check — real hash compare against whichever
  /// account is active for the current role. Returns false (not an
  /// exception) when no account exists yet, matching the old stub's
  /// "just tell me yes/no" contract that the PIN pad widgets rely on.
  bool verifyPin(String candidate) {
    final bool ok;
    if (state.activeRole == UserRole.asatidz) {
      final account = state.activeTeacherId == null
          ? null
          : _teachers.findById(state.activeTeacherId!);
      ok = account != null && _teachers.verifyPin(account, candidate);
    } else {
      final account = state.activeParentId == null
          ? null
          : _parents.findById(state.activeParentId!);
      ok = account != null && _parents.verifyPin(account, candidate);
    }
    if (ok) state = state.copyWith(pinVerified: true);
    return ok;
  }

  /// Whether the active account has a Firebase Auth link yet (FR-7.2 sync
  /// needs this — see `ParentRepository.linkToFirebase` doc for why an
  /// account can end up without one).
  bool get activeAccountLinkedToFirebase {
    if (state.activeRole == UserRole.asatidz) {
      final account = state.activeTeacherId == null
          ? null
          : _teachers.findById(state.activeTeacherId!);
      return account?.firebaseUid != null;
    }
    final account = state.activeParentId == null
        ? null
        : _parents.findById(state.activeParentId!);
    return account?.firebaseUid != null;
  }

  /// The active parent's own name (as they registered it) — distinct from
  /// `state.learner?.name`, which is the *child's* name. Used by the
  /// Progress screen's greeting so it can address the parent by name
  /// instead of only ever naming the child being tracked.
  String? get activeParentFullName {
    final id = state.activeParentId;
    if (id == null) return null;
    return _parents.findById(id)?.fullName;
  }

  /// Same as [activeParentFullName] but for the active Asatidz account —
  /// backs the Teacher Home tab's greeting.
  String? get activeTeacherFullName {
    final id = state.activeTeacherId;
    if (id == null) return null;
    return _teachers.findById(id)?.fullName;
  }

  /// Whether the active account even has an email/password to link with in
  /// the first place — false for a bare PIN-only account created via
  /// `createPinOnly` (the router's `/pin/setup` fallback, reached when a
  /// grown-up area is hit before any full registration happened). Such an
  /// account has no `passwordHash` at all, so any password typed into the
  /// "Link to Cloud" card would always fail `verifyPassword` — this getter
  /// is what lets that card hide itself for that case instead of showing
  /// a password prompt that can never succeed.
  bool get activeAccountHasEmail {
    if (state.activeRole == UserRole.asatidz) {
      final account = state.activeTeacherId == null
          ? null
          : _teachers.findById(state.activeTeacherId!);
      return account?.email != null;
    }
    final account = state.activeParentId == null
        ? null
        : _parents.findById(state.activeParentId!);
    return account?.email != null;
  }

  /// Retries the Firebase Auth link for the active account — throws with
  /// the real reason (wrong password, or a [FirebaseAuthException] like
  /// `weak-password`) so the UI can show something actionable instead of
  /// a silent failure.
  Future<void> linkActiveAccountToFirebase(String password) async {
    if (state.activeRole == UserRole.asatidz) {
      final account = state.activeTeacherId == null
          ? null
          : _teachers.findById(state.activeTeacherId!);
      if (account == null) throw StateError('No active account');
      await _teachers.linkToFirebase(account: account, password: password);
    } else {
      final account = state.activeParentId == null
          ? null
          : _parents.findById(state.activeParentId!);
      if (account == null) throw StateError('No active account');
      await _parents.linkToFirebase(account: account, password: password);
    }
  }

  /// FR-2.3/Figure 7 — creates a brand-new learner attached to whichever
  /// parent account is active. [password] is optional — see
  /// `LearnerRepository.register`'s doc for why the Parent Dashboard's
  /// "Add Child Profile" flow doesn't pass one at all.
  Future<LearnerProfile> createLearner({
    required String name,
    required int age,
    required String username,
    String? password,
    String avatar = '🧒',
    String gradeLevel = 'Grade 1',
  }) async {
    final profile = await _learners.register(
      parentId: state.activeParentId ?? '',
      name: name,
      age: age,
      username: username,
      password: password,
      avatar: avatar,
      gradeLevel: gradeLevel,
    );
    if (profile.id != null) {
      await _settings.put('activeLearnerId', profile.id);
    }
    state = state.copyWith(learner: profile);
    // Best-effort — see the matching comment on the parent/teacher register
    // branches in `createPin` for why this can't just wait for the next
    // manual/connectivity-triggered sync.
    if (profile.id != null) {
      try {
        await FirestoreMirror().pushLearner(profile);
      } catch (e) {
        debugPrint('createLearner: initial push failed: $e');
      }
    }
    return profile;
  }

  /// Parent Dashboard's "Add Child Profile" flow re-checks the *parent's
  /// own* account password as a lightweight confirmation that the actual
  /// account holder is the one creating this child's profile — it's not
  /// creating or checking any credential belonging to the child. Returns
  /// false if there's no active parent account at all (shouldn't happen
  /// in practice, since this flow requires being signed in as one).
  bool verifyActiveParentPassword(String password) {
    final id = state.activeParentId;
    if (id == null) return false;
    final account = _parents.findById(id);
    if (account == null) return false;
    return _parents.verifyPassword(account, password);
  }

  /// Switches which of the parent's (possibly several) children is
  /// "active" — every learner-scoped view (KPIs, streak, suggestions,
  /// the roster a teacher sees) reads `state.learner`/its id, so this is
  /// effectively "open this child's dashboard instead." A no-op if
  /// [learnerId] doesn't resolve (e.g. stale UI state).
  Future<void> switchActiveLearner(String learnerId) async {
    final profile = _learners.findById(learnerId);
    if (profile == null) return;
    await _settings.put('activeLearnerId', learnerId);
    state = state.copyWith(learner: profile);
  }

  /// Edits the *existing* active learner's profile fields (Parent
  /// Dashboard "Edit Child Profile" card) — never touches their
  /// username/password, unlike [createLearner].
  Future<void> updateLearnerProfile({
    required String name,
    required int age,
    required String avatar,
    String? gradeLevel,
  }) async {
    final existing = state.learner;
    if (existing == null) return;
    final updated = await _learners.update(
      existing,
      name: name,
      age: age,
      avatar: avatar,
      gradeLevel: gradeLevel,
    );
    state = state.copyWith(learner: updated);
  }

  /// Parent Dashboard's "Delete Child Profile" — permanently removes one
  /// learner (local record + best-effort mirrored Firestore doc, matching
  /// [eraseAll]'s "delete remote before local" ordering while the id still
  /// resolves). If this was the active learner, re-picks another of the
  /// same parent's children if one exists, or clears `state.learner`
  /// entirely if that was the last one — done via a fresh [SessionState]
  /// rather than [SessionState.copyWith] since `copyWith` has no way to
  /// null out an already-set field.
  Future<void> deleteLearner(String learnerId) async {
    try {
      await FirestoreMirror().deleteDoc(HiveBoxes.learners, learnerId);
    } catch (_) {
      // Offline, never-synced, or already gone — nothing to do, matching
      // eraseAll's own best-effort remote-delete contract.
    }
    await _learners.delete(learnerId);

    if (state.learner?.id != learnerId) return;

    final remaining = _learners.byParentId(state.activeParentId ?? '');
    final next = remaining.isEmpty ? null : remaining.first;
    if (next?.id != null) {
      await _settings.put('activeLearnerId', next!.id!);
    } else {
      await _settings.delete('activeLearnerId');
    }
    state = SessionState(
      languageCode: state.languageCode,
      consent: state.consent,
      activeRole: state.activeRole,
      pinVerified: state.pinVerified,
      activeParentId: state.activeParentId,
      activeTeacherId: state.activeTeacherId,
      learner: next,
    );
  }

  void lockAdminModules() => state = state.copyWith(pinVerified: false);

  /// Full sign-out (the dashboards' "Logout" button) — distinct from
  /// [lockAdminModules], which only re-locks the PIN gate but keeps the
  /// account "active" on this device. Logging out clears which account is
  /// active entirely, so the next launch lands on the role picker and
  /// requires email + password again, not just the PIN. Leaves every
  /// account's data untouched on disk — only [eraseAll] deletes data.
  ///
  /// Deliberately does NOT delete `activeLearnerId` — that's kept as "last
  /// selected child" memory so [signIn] can restore the same child's
  /// dashboard on the next login instead of showing a generic no-child
  /// state every time.
  Future<void> logout() async {
    await _settings.delete('activeRole');
    await _settings.delete('activeParentId');
    await _settings.delete('activeTeacherId');
    state = SessionState(
      languageCode: state.languageCode,
      consent: state.consent,
    );
  }

  /// FR-7.3 "Right to be Forgotten" — deletes every mirrored Firestore
  /// document (best-effort; needs the ids while they still exist locally,
  /// so this must run *before* the local wipe), then wipes every Hive box
  /// on disk and resets the in-memory session to a clean slate.
  Future<void> eraseAll() async {
    await SyncManager().eraseRemoteData();
    await HiveService.eraseEverything();
    state = const SessionState();
  }

  /// Detects the "removed via the admin web panel" case: Hive is this
  /// device's own source of truth (see the module doc), so it never
  /// notices on its own that the cloud copy of the *currently signed-in*
  /// parent/teacher account is gone — nothing here queries Firestore on
  /// every launch, only on explicit actions like this. Dashboards call this
  /// once on load so a deleted account gets logged out instead of quietly
  /// continuing to show stale local data forever.
  ///
  /// Deliberately conservative: only a *confirmed* remote miss (a
  /// successful query that found nothing) triggers [logout]. Being offline,
  /// never having linked to Firebase in the first place, or any other
  /// error is treated as "still exists" — a lookup failing to prove
  /// something must never be treated as proof it's gone.
  Future<bool> verifyActiveAccountStillExists() async {
    try {
      if (state.activeRole == UserRole.asatidz) {
        final id = state.activeTeacherId;
        final account = id == null ? null : _teachers.findById(id);
        final firebaseUid = account?.firebaseUid;
        if (firebaseUid == null) return true;
        final remote = await FirestoreMirror().fetchTeacherByFirebaseUid(
          firebaseUid,
        );
        if (remote != null) return true;
      } else {
        final id = state.activeParentId;
        final account = id == null ? null : _parents.findById(id);
        final firebaseUid = account?.firebaseUid;
        if (firebaseUid == null) return true;
        final remote = await FirestoreMirror().fetchParentByFirebaseUid(
          firebaseUid,
        );
        if (remote != null) return true;
      }
    } catch (_) {
      return true;
    }
    await logout();
    return false;
  }
}

/// See [SessionNotifier.verifyActiveAccountStillExists] doc. `autoDispose`
/// so a stale result doesn't linger in memory once the dashboard that
/// triggered it is gone — the next dashboard visit re-checks fresh.
final accountStillExistsProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.read(sessionProvider.notifier).verifyActiveAccountStillExists();
});

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
