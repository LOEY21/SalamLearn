import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// SHA-256 + per-record salt hashing for both account passwords and the
/// 4-digit admin PIN (NFR-Security: "hash user credentials locally and
/// encrypt the 4-digit PIN"). Not a general-purpose crypto utility — scoped
/// to exactly this app's two credential kinds.
class CredentialHasher {
  const CredentialHasher._();

  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(length, (_) => random.nextInt(256)));
  }

  static String hash(String value, String salt) {
    final bytes = utf8.encode('$salt:$value');
    return sha256.convert(bytes).toString();
  }

  static bool verify(String candidate, String salt, String storedHash) {
    return hash(candidate, salt) == storedHash;
  }
}
