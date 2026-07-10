import 'package:hive/hive.dart';

import '../local/hive_boxes.dart';
import '../models/consent_record.dart';
import '../remote/firestore_mirror.dart';

/// Hive-backed store for [ConsentRecord] (FR-2.2). Keyed by whichever id
/// the caller uses to scope consent — in practice the parent account id,
/// since one parent's consent covers every learner they create.
class ConsentRepository {
  Box<ConsentRecord> get _box => Hive.box<ConsentRecord>(HiveBoxes.consents);

  Future<void> save(String key, ConsentRecord record) => _box.put(key, record);

  ConsentRecord? get(String key) => _box.get(key);

  bool hasConsented(String key) => _box.containsKey(key);

  Future<void> revoke(String key) => _box.delete(key);

  /// Pushes every locally-stored consent record to Firestore (FR-7.2 sync).
  Future<void> pushAll(FirestoreMirror mirror) async {
    for (final key in _box.keys) {
      final record = _box.get(key);
      if (record != null) await mirror.pushConsent(key.toString(), record);
    }
  }
}
