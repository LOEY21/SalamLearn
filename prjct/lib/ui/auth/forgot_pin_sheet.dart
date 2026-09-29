import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../data/remote/pin_reset_mailer.dart';
import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_pad.dart';

/// PIN gate "Forgot PIN?" flow: email a 6-digit code to the account's
/// address -> enter it -> new PIN -> confirm. Pops `true` once the new PIN
/// is saved; the caller's PIN pad then asks for it.
Future<bool> showForgotPinSheet(
  BuildContext context, {
  required Color accentColor,
  PinResetMailer? mailer,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ForgotPinSheet(
      accentColor: accentColor,
      mailer: mailer ?? PinResetMailer(),
    ),
  );
  return done ?? false;
}

enum _Step { code, fresh, confirm }

class ForgotPinSheet extends ConsumerStatefulWidget {
  const ForgotPinSheet({
    super.key,
    required this.accentColor,
    required this.mailer,
  });

  final Color accentColor;
  final PinResetMailer mailer;

  @override
  ConsumerState<ForgotPinSheet> createState() => _ForgotPinSheetState();
}

class _ForgotPinSheetState extends ConsumerState<ForgotPinSheet> {
  static const _codeLife = Duration(minutes: 10);
  static const _resendWait = 60;
  static const _maxAttempts = 5;

  final _codeC = TextEditingController();
  final _random = Random.secure();

  _Step _step = _Step.code;
  String? _code;
  DateTime? _sentAt;
  int _attempts = 0;
  bool _sending = false;
  int _resendIn = 0;
  Timer? _resendTimer;
  String _newPin = '';
  String? _error;

  late final ({String? email, String name}) _contact =
      ref.read(sessionProvider.notifier).activeGrownUpContact();

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeC.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _contact.email;
    if (email == null || email.isEmpty) {
      setState(() => _error = 'This account has no email address.');
      return;
    }
    final code = List.generate(6, (_) => _random.nextInt(10)).join();
    setState(() {
      _sending = true;
      _error = null;
    });
    final ok = await widget.mailer.sendCode(
      toEmail: email,
      name: _contact.name,
      code: code,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _code = code;
        _sentAt = DateTime.now();
        _attempts = 0;
        _codeC.clear();
        _startResendTimer();
      } else {
        _error = "Couldn't send the code. Check your internet and try again.";
      }
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendIn = _resendWait;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _checkCode() {
    final entered = _codeC.text.trim();
    if (entered.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    if (_code == null ||
        DateTime.now().difference(_sentAt!) > _codeLife ||
        _attempts >= _maxAttempts) {
      setState(() {
        _code = null;
        _error = 'This code has expired. Tap "Resend code".';
      });
      return;
    }
    if (entered != _code) {
      _attempts++;
      setState(() {
        if (_attempts >= _maxAttempts) {
          _code = null;
          _error = 'Too many wrong tries. Tap "Resend code".';
        } else {
          _error = 'Wrong code. Try again.';
        }
      });
      return;
    }
    setState(() {
      _code = null;
      _step = _Step.fresh;
      _error = null;
    });
  }

  bool _onPin(String pin) {
    if (_step == _Step.fresh) {
      setState(() {
        _newPin = pin;
        _step = _Step.confirm;
        _error = null;
      });
      return true;
    }
    if (pin != _newPin) {
      setState(() => _error = "PINs don't match. Try again.");
      return false;
    }
    _save();
    return true;
  }

  Future<void> _save() async {
    await ref.read(sessionProvider.notifier).resetForgottenPin(_newPin);
    if (mounted) Navigator.of(context).pop(true);
  }

  String get _maskedEmail {
    final email = _contact.email ?? '';
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email[0]}${'*' * (at - 1).clamp(3, 6)}${email.substring(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.code => 'Forgot PIN?',
      _Step.fresh => 'Create a new PIN',
      _Step.confirm => 'Confirm new PIN',
    };
    final subtitle = switch (_step) {
      _Step.code => _sending
          ? 'Sending a code to $_maskedEmail...'
          : _sentAt == null
          ? "We'll send a 6-digit code to $_maskedEmail"
          : 'We sent a 6-digit code to $_maskedEmail',
      _Step.fresh => 'Enter a new 4-digit PIN',
      _Step.confirm => 'Enter the same PIN again',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.creamBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.coral,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_step == _Step.code)
                _buildCodeStep()
              else
                PinPad(
                  key: ValueKey(_step),
                  accentColor: widget.accentColor,
                  onSubmit: _onPin,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeStep() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('forgot-pin-code'),
            controller: _codeC,
            enabled: !_sending,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _checkCode(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.35),
                letterSpacing: 10,
              ),
              filled: true,
              fillColor: AppColors.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.creamBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: widget.accentColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.accentColor,
              ),
              onPressed: _sending ? null : _checkCode,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify code'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _sending || _resendIn > 0 ? null : _send,
            child: Text(
              _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
