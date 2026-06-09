import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../toast/toast_service.dart';
import '../widgets/language_toggle_button.dart';
import 'auth_service.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final s = AppStrings.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final name = _nameCtrl.text.trim();
    try {
      // Verify-before-create: email the OTP now; the account row is only
      // written once the code is confirmed on the verify screen.
      final result = await widget.authService.sendRegistrationOtp(
        email: email,
        locale: locale,
      );
      if (!mounted) return;
      switch (result) {
        case OtpOk():
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VerifyEmailScreen(
                authService: widget.authService,
                email: email,
                password: password,
                name: name,
              ),
            ),
          );
        case OtpCooldown(:final seconds):
          showToast(context, s.otpCooldown(seconds));
        case OtpWrong() || OtpExpired() || OtpTooMany() || OtpError():
          _showError(s.otpSendFailed);
      }
    } catch (_) {
      if (!mounted) return;
      _showError(s.unexpectedError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.registerTitle),
        actions: const [LanguageToggleButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_alt_1,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: s.name,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? s.enterName : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: s.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? s.emailInvalid : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: s.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? s.passwordTooShort : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(s.registerButton,
                              style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
