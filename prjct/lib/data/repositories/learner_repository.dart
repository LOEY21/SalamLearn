import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../logic/auth/credential_hasher.dart';
import '../local/hive_boxes.dart';
import '../models/learner_profile.dart';
import '../remote/firestore_mirror.dart';

/// Hive-backed CRUD for [LearnerProfile], including the learner's own
/// username/password created by the parent during setup (Diagrams Figure 7).
class LearnerRepository {
  Box<LearnerProfile> get _box => Hive.box<LearnerProfile>(HiveBoxes.learners);

  /// [password] is optional — the Student Hub's own sign-in
  /// (`_learnerSignIn` on the auth hub) is tap-an-avatar only, never a
  /// typed credential, so a learner created via the Parent Dashboard's
  /// "Add Child Profile" flow has no real use for one; that flow instead
  /// asks the parent to re-enter *their own* password as a confirmation
  /// step (see `SessionNotifier.verifyActiveParentPassword`) and passes
  /// `password: null` here. The standalone "Learner" self-registration
  /// path on the role picker's sign-up form still collects and passes a
  /// real one, since no parent is authenticated in that flow to confirm
  /// against instead.
  Future<LearnerProfile> register({
    required String parentId,
    required String name,
    required int age,
    required String username,
    String? password,
    String avatar = '🧒',
    String gradeLevel = 'Grade 1',
  }) async {
    if (findByUsername(username) != null) {
      throw StateError('Username is already taken');
    }
    String? passwordHash;
    String? passwordSalt;
    if (password != null) {
      passwordSalt = CredentialHasher.generateSalt();
      passwordHash = CredentialHasher.hash(password, passwordSalt);
    }
    final profile = LearnerProfile(
      id: const Uuid().v4(),
      parentId: parentId,
      name: name,
      age: age,
      avatar: avatar,
      gradeLevel: gradeLevel,
      username: username,
      passwordHash: passwordHash,
      passwordSalt: passwordSalt,
      createdAt: DateTime.now(),
    );
    await _box.put(profile.id, profile);
    return profile;
  }

  LearnerProfile? findById(String id) => _box.get(id);

  LearnerProfile? findByUsername(String username) {
    for (final learner in _box.values) {
      if (learner.username == username) return learner;
    }
    return null;
  }

  /// Case-insensitive exact match on the learner's full name — used by the
  /// teacher's "Enroll Existing Learner" form, which asks for the child's
  /// full name (not their username, which the teacher has no reason to
  /// know). Returns every match since names aren't guaranteed unique across
  /// families; the caller decides how to handle 0 or 2+ results.
  List<LearnerProfile> findAllByName(String name) {
    final normalized = name.trim().toLowerCase();
    return _box.values.where((l) => l.name.trim().toLowerCase() == normalized).toList();
  }

  List<LearnerProfile> byParentId(String parentId) =>
      _box.values.where((l) => l.parentId == parentId).toList();

  /// Parent Dashboard's "Delete Child Profile" — removes the local record
  /// only; the caller (`SessionNotifier.deleteLearner`) is responsible for
  /// also deleting the mirrored Firestore doc and re-picking an active
  /// learner if this was it.
  Future<void> delete(String id) => _box.delete(id);

  /// Updates profile fields (name/age/avatar/grade) in place — leaves
  /// [LearnerProfile.username]/password untouched, unlike [register].
  Future<LearnerProfile> update(
    LearnerProfile existing, {
    String? name,
    int? age,
    String? avatar,
    String? gradeLevel,
  }) async {
    final updated = LearnerProfile(
      id: existing.id,
      parentId: existing.parentId,
      name: name ?? existing.name,
      age: age ?? existing.age,
      avatar: avatar ?? existing.avatar,
      gradeLevel: gradeLevel ?? existing.gradeLevel,
      username: existing.username,
      passwordHash: existing.passwordHash,
      passwordSalt: existing.passwordSalt,
      createdAt: existing.createdAt,
    );
    if (existing.id != null) {
      await _box.put(existing.id, updated);
    }
    return updated;
  }

  bool verifyPassword(LearnerProfile profile, String candidate) {
    if (profile.passwordHash == null || profile.passwordSalt == null) return false;
    return CredentialHasher.verify(candidate, profile.passwordSalt!, profile.passwordHash!);
  }

  /// FR-7.2 "sign in on any device" — saves a child profile pulled down
  /// from Firestore onto this device. Reuses the cloud doc's id (so a
  /// later push from this device updates the same document rather than
  /// duplicating it) and leaves the learner's own username/password
  /// unset — those aren't mirrored (see `FirestoreMirror`'s doc), so this
  /// device can see the child in the dashboard but the child themselves
  /// would need re-registering here to actually use the Student Hub on it.
  Future<LearnerProfile> saveFromRemote({
    required String id,
    required String parentId,
    required String name,
    required int age,
    required String avatar,
    required String gradeLevel,
    String? username,
    DateTime? createdAt,
  }) async {
    final profile = LearnerProfile(
      id: id,
      parentId: parentId,
      name: name,
      age: age,
      avatar: avatar,
      gradeLevel: gradeLevel,
      username: username,
      createdAt: createdAt,
    );
    await _box.put(profile.id, profile);
    return profile;
  }

  /// Pushes every locally-stored learner to Firestore (FR-7.2 sync). See
  /// `ParentRepository.pushAll` doc — same best-effort-per-item contract
  /// (a permission-denied or network blip on one child doesn't stop the
  /// rest of this parent's children, or any other collection, from
  /// getting their own attempt).
  Future<void> pushAll(FirestoreMirror mirror) async {
    for (final learner in _box.values) {
      try {
        await mirror.pushLearner(learner);
      } catch (_) {
        // Best-effort — see doc above.
      }
    }
  }
}
