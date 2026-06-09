/// EmailJS configuration for the free, client-side 4-digit OTP email.
///
/// These three values are NOT secrets — the public key is designed to be
/// embedded in client apps. Fill them from your EmailJS dashboard, or pass
/// them at build time with `--dart-define` (overrides the defaults below):
///
/// ```
/// flutter build apk --dart-define=EMAILJS_SERVICE_ID=service_xxx \
///   --dart-define=EMAILJS_TEMPLATE_ID=template_xxx \
///   --dart-define=EMAILJS_PUBLIC_KEY=xxxxxxxx
/// ```
///
/// Dashboard setup (one time):
/// 1. Email Services → add a service (e.g. Gmail) → copy the **Service ID**.
/// 2. Email Templates → create a template whose body contains `{{passcode}}`
///    and whose "To Email" field is `{{email}}` → copy the **Template ID**.
/// 3. Account → General → copy the **Public Key**.
/// 4. Account → Security → enable **"Allow EmailJS API for non-browser
///    applications"** (required so the mobile app can call the API without a
///    private key).
class EmailJsConfig {
  const EmailJsConfig._();

  static const String serviceId = String.fromEnvironment('EMAILJS_SERVICE_ID',
      defaultValue: 'YOUR_SERVICE_ID');
  static const String templateId = String.fromEnvironment('EMAILJS_TEMPLATE_ID',
      defaultValue: 'YOUR_TEMPLATE_ID');
  static const String publicKey = String.fromEnvironment('EMAILJS_PUBLIC_KEY',
      defaultValue: 'YOUR_PUBLIC_KEY');

  /// True once all three values have been filled (not left as placeholders).
  static bool get isConfigured =>
      !serviceId.startsWith('YOUR_') &&
      !templateId.startsWith('YOUR_') &&
      !publicKey.startsWith('YOUR_');
}
