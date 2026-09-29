import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sends the "Forgot PIN?" 6-digit code through EmailJS (no backend of our
/// own). The template `template_bok4zk6` reads `{{to_email}}`, `{{name}}`
/// and `{{code}}`. The public key is meant to ship in client apps; the
/// EmailJS account must have "Allow EmailJS API for non-browser
/// applications" switched on or every send is rejected.
class PinResetMailer {
  static const _serviceId = 'service_pog12st';
  static const _templateId = 'template_bok4zk6';
  static const _publicKey = 'WCR6324opvTRcAsPF';

  /// True when EmailJS accepted the email. False on any network or API
  /// error — callers show one generic "couldn't send" message.
  Future<bool> sendCode({
    required String toEmail,
    required String name,
    required String code,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': _serviceId,
              'template_id': _templateId,
              'user_id': _publicKey,
              'template_params': {
                'to_email': toEmail,
                'name': name,
                'code': code,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
