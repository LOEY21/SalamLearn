import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/remote/pin_reset_mailer.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/ui/auth/forgot_pin_sheet.dart';

class _FakeMailer extends PinResetMailer {
  _FakeMailer({this.ok = true});

  final bool ok;
  String? to;
  String? code;

  @override
  Future<bool> sendCode({
    required String toEmail,
    required String name,
    required String code,
  }) async {
    to = toEmail;
    this.code = code;
    return ok;
  }
}

class _FakeSession extends SessionNotifier {
  String? savedPin;

  @override
  SessionState build() => const SessionState();

  @override
  ({String? email, String name}) activeGrownUpContact() =>
      (email: 'parent@example.com', name: 'Aisha');

  @override
  Future<void> resetForgottenPin(String newPin) async => savedPin = newPin;
}

void main() {
  late _FakeSession session;

  Widget host(PinResetMailer mailer) => ProviderScope(
    overrides: [sessionProvider.overrideWith(() => session = _FakeSession())],
    child: MaterialApp(
      home: Scaffold(
        body: ForgotPinSheet(accentColor: Colors.teal, mailer: mailer),
      ),
    ),
  );

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
  }

  testWidgets('emails a code, rejects a wrong one, then sets the new PIN', (
    tester,
  ) async {
    final mailer = _FakeMailer();
    await tester.pumpWidget(host(mailer));
    await tester.pump();

    expect(mailer.to, 'parent@example.com');
    expect(mailer.code, matches(RegExp(r'^\d{6}$')));
    expect(find.textContaining('p*****@example.com'), findsOneWidget);

    final wrong = mailer.code == '000000' ? '111111' : '000000';
    await tester.enterText(find.byKey(const ValueKey('forgot-pin-code')), wrong);
    await tester.tap(find.text('Verify code'));
    await tester.pump();
    expect(find.text('Wrong code. Try again.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('forgot-pin-code')),
      mailer.code!,
    );
    await tester.tap(find.text('Verify code'));
    await tester.pump();
    expect(find.text('Create a new PIN'), findsOneWidget);

    await typePin(tester, '2468');
    expect(find.text('Confirm new PIN'), findsOneWidget);
    await typePin(tester, '2468');
    await tester.pump();
    expect(session.savedPin, '2468');
  });

  testWidgets('shows an error when the email cannot be sent', (tester) async {
    await tester.pumpWidget(host(_FakeMailer(ok: false)));
    await tester.pump();
    expect(find.textContaining("Couldn't send the code"), findsOneWidget);
    expect(find.text('Resend code'), findsOneWidget);
  });
}
