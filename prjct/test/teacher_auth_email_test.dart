import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/remote/firebase_auth_gateway.dart';

void main() {
  test('teacherAuthEmail aliases Gmail only, idempotently', () {
    expect(
      FirebaseAuthGateway.teacherAuthEmail(' Jude@Gmail.com '),
      'jude+teacher@gmail.com',
    );
    expect(
      FirebaseAuthGateway.teacherAuthEmail('jude+teacher@gmail.com'),
      'jude+teacher@gmail.com',
    );
    expect(
      FirebaseAuthGateway.teacherAuthEmail('jude@lpu.edu.ph'),
      'jude@lpu.edu.ph',
    );
  });
}
