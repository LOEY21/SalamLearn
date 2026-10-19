import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/auth/employee_id.dart';

void main() {
  test('normalizeEmployeeId accepts the admin-web format and variants', () {
    expect(normalizeEmployeeId('2026-483915'), '2026-483915');
    expect(normalizeEmployeeId(' 2026483915 '), '2026-483915');
    expect(normalizeEmployeeId('2026 483915'), '2026-483915');
    expect(normalizeEmployeeId('2026-48391'), isNull);
    expect(normalizeEmployeeId('jude'), isNull);
  });

  test('maskEmail hides the local part', () {
    expect(maskEmail('jude@gmail.com'), 'j***@gmail.com');
    expect(maskEmail('not-an-email'), 'not-an-email');
  });
}
