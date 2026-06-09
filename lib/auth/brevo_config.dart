import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Brevo (Sendinblue) transactional-email configuration for the free,
/// client-side 4-digit OTP email.
///
/// ⚠️ SECURITY: unlike the old EmailJS public key, the Brevo `api-key` is a
/// real secret. It is read from the bundled `.env` file (kept out of git via
/// .gitignore) — but note `.env` ships inside the APK as an asset and can be
/// extracted in plaintext. There is no way to fully hide a sender secret in a
/// client-only app; the proper fix is a server proxy. We accept this tradeoff
/// deliberately because the project has no paid backend and OTP here is only a
/// light "did you receive the email" confirmation (real gate access is still
/// gated by admin approval).
///
/// `.env` keys (project root, gitignored, bundled as a Flutter asset):
/// ```
/// BREVO_API_KEY=xkeysib-xxxxx
/// BREVO_SENDER_EMAIL=you@verified-domain.com
/// BREVO_SENDER_NAME=Door
/// ```
///
/// Dashboard setup (one time):
/// 1. Brevo → Senders, Domains & Dedicated IPs → add and **verify** the sender
///    email. Brevo rejects transactional sends from unverified senders.
/// 2. Brevo → SMTP & API → API Keys → create an API key → copy it.
class BrevoConfig {
  const BrevoConfig._();

  static String get apiKey => dotenv.env['BREVO_API_KEY'] ?? '';
  static String get senderEmail => dotenv.env['BREVO_SENDER_EMAIL'] ?? '';
  static String get senderName => dotenv.env['BREVO_SENDER_NAME'] ?? 'Door';

  static const String endpoint = 'https://api.brevo.com/v3/smtp/email';

  /// True once the API key and a sender email are present in the loaded `.env`.
  static bool get isConfigured => apiKey.isNotEmpty && senderEmail.isNotEmpty;
}
