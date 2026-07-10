import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/models/parent_account.dart';
import 'package:salamlearn/data/repositories/parent_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('salamlearn_hive_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ParentAccountAdapter());
    }
    await Hive.openBox<ParentAccount>('parents');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('register hashes the password and PIN, never storing them as plain text', () async {
    final repo = ParentRepository();

    final account = await repo.register(
      fullName: 'Amir Rahman',
      email: 'amir@example.com',
      password: 'correct horse',
      pin: '1234',
    );

    expect(account.passwordHash, isNot(equals('correct horse')));
    expect(account.pinHash, isNot(equals('1234')));
  });

  test('verifyPassword and verifyPin accept the right credentials and reject wrong ones', () async {
    final repo = ParentRepository();
    final account = await repo.register(
      fullName: 'Amir Rahman',
      email: 'amir@example.com',
      password: 'correct horse',
      pin: '1234',
    );

    expect(repo.verifyPassword(account, 'correct horse'), isTrue);
    expect(repo.verifyPassword(account, 'wrong password'), isFalse);
    expect(repo.verifyPin(account, '1234'), isTrue);
    expect(repo.verifyPin(account, '0000'), isFalse);
  });

  test('register rejects a duplicate email', () async {
    final repo = ParentRepository();
    await repo.register(
      fullName: 'Amir Rahman',
      email: 'amir@example.com',
      password: 'correct horse',
      pin: '1234',
    );

    expect(
      () => repo.register(
        fullName: 'Another Parent',
        email: 'amir@example.com',
        password: 'different password',
        pin: '5678',
      ),
      throwsStateError,
    );
  });

  test('findByEmail and findById return the persisted account', () async {
    final repo = ParentRepository();
    final account = await repo.register(
      fullName: 'Amir Rahman',
      email: 'amir@example.com',
      password: 'correct horse',
      pin: '1234',
    );

    expect(repo.findByEmail('amir@example.com')?.id, account.id);
    expect(repo.findById(account.id)?.email, 'amir@example.com');
    expect(repo.findByEmail('nobody@example.com'), isNull);
  });
}
