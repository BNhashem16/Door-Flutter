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
    // Branded subject (a bare "Verification code" reads as phishing to spam
    // filters and users).
    final subject = isAr ? 'رمز التحقق — تحكم البوابة' : 'Gate Control verification code';
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
              // Reply-To at the verified sender so replies have a real home.
              'replyTo': {
                'name': BrevoConfig.senderName,
                'email': BrevoConfig.senderEmail,
              },
              'to': [
                {'email': email},
              ],
              'subject': subject,
              'htmlContent': _buildHtml(code: code, isAr: isAr),
              'textContent': _buildText(code: code, isAr: isAr),
              // Brevo transactional tag — reputation tracking, not spammy.
              'tags': ['otp'],
            }),
          )
          .timeout(const Duration(seconds: 20));
      // Brevo returns 201 Created on a successfully queued transactional email.
      return res.statusCode == 201 || res.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  /// Clean, professional, single-column email. Inline CSS only and table-based
  /// layout for maximum email-client compatibility (Gmail, Outlook, Apple Mail).
  String _buildHtml({required String code, required bool isAr}) {
    final dir = isAr ? 'rtl' : 'ltr';
    final lang = isAr ? 'ar' : 'en';
    final align = isAr ? 'right' : 'left';
    final brand = isAr ? 'تحكم البوابة' : 'Gate Control';
    final title = isAr ? 'رمز التحقق' : 'Verification code';
    final intro = isAr
        ? 'استخدم الرمز التالي لتأكيد بريدك الإلكتروني داخل التطبيق:'
        : 'Use the code below to confirm your email address in the app:';
    final expiry = isAr
        ? 'ينتهي هذا الرمز خلال <strong style="color:#0f172a">10 دقائق</strong>.'
        : 'This code expires in <strong style="color:#0f172a">10 minutes</strong>.';
    final ignore = isAr
        ? 'لم تطلب هذا الرمز؟ يمكنك تجاهل هذه الرسالة بأمان — لن يتغيّر أي شيء.'
        : "Didn't request this code? You can safely ignore this email — nothing will change.";
    final pre = isAr
        ? 'رمز التحقق الخاص بك من $brand'
        : 'Your $brand verification code';
    // Spaced digits read clearly and are easy to copy.
    final spaced = code.split('').join('&nbsp;&nbsp;');

    return '<!DOCTYPE html><html lang="$lang" dir="$dir">'
        '<head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta name="color-scheme" content="light only"></head>'
        '<body style="margin:0;padding:0;background:#eef2f6;">'
        // hidden preheader (inbox preview text — avoids empty-preview spam signal)
        '<div style="display:none;max-height:0;overflow:hidden;opacity:0;'
        'mso-hide:all;font-size:1px;line-height:1px;color:#eef2f6;">$pre</div>'
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        'style="background:#eef2f6;padding:32px 12px;">'
        '<tr><td align="center">'
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        'style="max-width:480px;background:#ffffff;border:1px solid #e2e8f0;'
        'border-radius:18px;overflow:hidden;'
        'font-family:\'Segoe UI\',Tahoma,Arial,sans-serif;">'
        // header
        '<tr><td style="background:#1d4ed8;padding:22px 24px;text-align:center;">'
        '<span style="color:#ffffff;font-size:21px;font-weight:700;">'
        '🔐&nbsp;&nbsp;$brand</span></td></tr>'
        // body
        '<tr><td style="padding:30px 28px 24px;color:#0f172a;'
        'direction:$dir;text-align:$align;">'
        '<p style="margin:0 0 6px;font-size:20px;font-weight:700;">$title</p>'
        '<p style="margin:0 0 4px;font-size:15px;color:#64748b;line-height:1.8;">'
        '$intro</p>'
        // code block
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">'
        '<tr><td align="center" style="padding:8px 0 4px;">'
        '<div style="display:inline-block;padding:18px 32px;background:#f1f5f9;'
        'border:1px solid #e2e8f0;border-radius:14px;direction:ltr;">'
        '<span style="font-family:\'Courier New\',Consolas,monospace;'
        'font-size:40px;font-weight:700;letter-spacing:4px;color:#1d4ed8;">'
        '$spaced</span></div></td></tr></table>'
        '<p style="margin:6px 0 0;font-size:14px;color:#64748b;line-height:1.8;'
        'text-align:center;">$expiry</p>'
        '<hr style="border:none;border-top:1px solid #e2e8f0;margin:24px 0;">'
        '<p style="margin:0;font-size:13px;color:#64748b;line-height:1.8;">'
        '$ignore</p></td></tr>'
        // footer
        '<tr><td style="background:#f8fafc;border-top:1px solid #e2e8f0;'
        'padding:16px 24px;text-align:center;">'
        '<span style="font-size:12px;color:#64748b;">$brand</span></td></tr>'
        '</table></td></tr></table></body></html>';
  }

  String _buildText({required String code, required bool isAr}) {
    if (isAr) {
      return 'تحكم البوابة\n\n'
          'رمز التحقق الخاص بك: $code\n\n'
          'استخدم هذا الرمز لتأكيد بريدك الإلكتروني داخل التطبيق.\n'
          'ينتهي الرمز خلال 10 دقائق.\n\n'
          'إذا لم تطلب هذا الرمز، تجاهل هذه الرسالة بأمان.';
    }
    return 'Gate Control\n\n'
        'Your verification code: $code\n\n'
        'Use this code to confirm your email address in the app.\n'
        'The code expires in 10 minutes.\n\n'
        "If you didn't request this code, you can safely ignore this email.";
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
