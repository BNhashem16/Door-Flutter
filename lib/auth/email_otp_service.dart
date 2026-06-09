import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'brevo_config.dart';
import 'otp_result.dart';
import 'secure_store.dart';

/// Free, server-less 4-digit OTP over email via Brevo transactional email.
///
/// Trade-off (no paid backend): the code is generated on-device, emailed via
/// Brevo's transactional API, and the active record is kept in encrypted
/// secure storage so it
/// survives screen rebuilds and app restarts. Verification compares the entered
/// code locally. A normal user receives a real code and it works; a malicious
/// user could bypass the check, but real gate access is still gated by admin
/// approval, so this stays a light "did you receive the email" confirmation.
class EmailOtpService {
  EmailOtpService({SecureStore store = const FlutterSecureStore()})
      : _store = store;

  final SecureStore _store;

  static const int _codeLength = 4;
  static const Duration _ttl = Duration(minutes: 10);
  static const Duration _cooldown = Duration(seconds: 60);
  static const int _maxAttempts = 5;

  String _key(String uid) => 'email_otp_$uid';

  /// Generate a fresh code, email it, and store the record. Enforces the
  /// resend cooldown. Returns [OtpOk], [OtpCooldown], or [OtpError].
  Future<OtpResult> send({
    required String uid,
    required String email,
    required String locale,
  }) async {
    if (!BrevoConfig.isConfigured) return const OtpError();

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _read(uid);
    if (existing != null) {
      final cooldownUntil = (existing['cooldownUntil'] as num?)?.toInt() ?? 0;
      if (cooldownUntil > now) {
        return OtpCooldown(((cooldownUntil - now) / 1000).ceil());
      }
    }

    final code = _generateCode();
    final sent = await _sendEmail(email: email, code: code, locale: locale);
    if (!sent) return const OtpError();

    await _write(uid, {
      'code': code,
      'expiresAt': now + _ttl.inMilliseconds,
      'attempts': 0,
      'cooldownUntil': now + _cooldown.inMilliseconds,
    });
    return const OtpOk();
  }

  /// Check [code] against the stored record. Consumes the record on success.
  Future<OtpResult> verify({required String uid, required String code}) async {
    final rec = await _read(uid);
    if (rec == null) return const OtpExpired();

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = (rec['expiresAt'] as num?)?.toInt() ?? 0;
    if (now > expiresAt) {
      await _store.delete(_key(uid));
      return const OtpExpired();
    }

    final attempts = (rec['attempts'] as num?)?.toInt() ?? 0;
    if (attempts >= _maxAttempts) return const OtpTooMany();

    if (rec['code'] == code) {
      await _store.delete(_key(uid));
      return const OtpOk();
    }

    final next = attempts + 1;
    rec['attempts'] = next;
    await _write(uid, rec);
    return OtpWrong((_maxAttempts - next).clamp(0, _maxAttempts));
  }

  Future<void> clear(String uid) => _store.delete(_key(uid));

  String _generateCode() =>
      Random.secure().nextInt(10000).toString().padLeft(_codeLength, '0');

  Future<bool> _sendEmail({
    required String email,
    required String code,
    required String locale,
  }) async {
    final isAr = locale == 'ar';
    final subject = isAr ? 'رمز التحقق' : 'Verification code';
    try {
      final res = await http
          .post(
            Uri.parse(BrevoConfig.endpoint),
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json',
              'api-key': BrevoConfig.apiKey,
            },
            body: jsonEncode({
              'sender': {
                'name': BrevoConfig.senderName,
                'email': BrevoConfig.senderEmail,
              },
              'to': [
                {'email': email},
              ],
              'subject': subject,
              'htmlContent': _buildHtml(code: code, isAr: isAr),
              'textContent': _buildText(code: code, isAr: isAr),
            }),
          )
          .timeout(const Duration(seconds: 20));
      // Brevo returns 201 Created on a successfully queued transactional email.
      return res.statusCode == 201 || res.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  String _buildHtml({required String code, required bool isAr}) {
    final dir = isAr ? 'rtl' : 'ltr';
    final intro =
        isAr ? 'رمز التحقق الخاص بك هو:' : 'Your verification code is:';
    final note = isAr
        ? 'صالح لمدة 10 دقائق. إذا لم تطلب هذا الرمز، تجاهل هذه الرسالة.'
        : 'Valid for 10 minutes. If you did not request this code, ignore this email.';
    return '<div dir="$dir" style="font-family:sans-serif;text-align:center">'
        '<p style="font-size:16px">$intro</p>'
        '<p style="font-size:40px;font-weight:bold;letter-spacing:8px;'
        'margin:16px 0">$code</p>'
        '<p style="font-size:13px;color:#666">$note</p>'
        '</div>';
  }

  String _buildText({required String code, required bool isAr}) {
    if (isAr) {
      return 'رمز التحقق الخاص بك هو: $code\n'
          'صالح لمدة 10 دقائق. إذا لم تطلب هذا الرمز، تجاهل هذه الرسالة.';
    }
    return 'Your verification code is: $code\n'
        'Valid for 10 minutes. If you did not request this code, ignore this email.';
  }

  Future<Map<String, dynamic>?> _read(String uid) async {
    final raw = await _store.read(_key(uid));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(String uid, Map<String, dynamic> record) =>
      _store.write(_key(uid), jsonEncode(record));
}
