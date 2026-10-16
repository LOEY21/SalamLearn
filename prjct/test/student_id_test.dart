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

  // Pinned values — admin-web/app.js ports this hash, so both must agree.
  test('studentIdFor matches the admin-web port', () {
    expect(studentIdFor('3f2b9c1e-7a4d-4e8b-9c2f-1a2b3c4d5e6f'), '3582-8149');
    expect(studentIdFor('Xq7Lm2pR9tVb3nKc8wZd'), '2951-9797');
    expect(studentIdFor('a'), '2600-2220');
  });
}
