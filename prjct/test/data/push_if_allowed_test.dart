import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/remote/firestore_mirror.dart';

void main() {
  test('a record the rules reject is skipped, so one stops no sync', () async {
    await pushIfAllowed(
      () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );
  });

  test('any other failure (offline etc.) still fails the sync', () {
    expect(
      pushIfAllowed(
        () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      ),
      throwsA(isA<FirebaseException>()),
    );
  });
}
