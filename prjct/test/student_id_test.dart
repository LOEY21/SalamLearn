import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/learner_profile.dart';

void main() {
  test('studentIdFor is stable, 8 digits, and input-format tolerant', () {
    const id = '3f2b9c1e-7a4d-4e8b-9c2f-1a2b3c4d5e6f';
    final sid = studentIdFor(id);
    expect(sid, matches(RegExp(r'^\d{4}-\d{4}$')));
    expect(studentIdFor(id), sid);
    expect(studentIdFor('Xq7Lm2pR9tVb3nKc8wZd'), isNot(sid));
    expect(
      normalizeStudentId(' ${sid.replaceAll('-', ' ')} '),
      normalizeStudentId(sid),
    );
  });
}
