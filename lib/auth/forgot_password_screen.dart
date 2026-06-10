import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../toast/toast_service.dart';
import '../widgets/language_toggle_button.dart';
import 'auth_service.dart';

/// Signed-out forgot-password flow. Collects the email and triggers Firebase's
/// built-in password-reset email (a secure link the user follows to set a new
/// password). To avoid revealing which emails are registered, a `user-not-found`
/// result is reported the same as success.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final s = AppStrings.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final email = _emailCtrl.text.trim();
    try {
      await widget.authService.sendPasswordResetEmail(
        email: email,
        locale: locale,
      );
      if (!mounted) return;
      showToast(context, s.resetLinkSent);
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Don't disclose whether the email is registered.
      if (e.code == 'user-not-found') {
        showToast(context, s.resetLinkSent);
        Navigator.of(context).pop();
      } else {
        showToast(context, s.otpSendFailed);
      }
    } catch (_) {
      if (!mounted) return;
      showToast(context, s.unexpectedError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.forgotPasswordTitle),
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
                  Icon(Icons.lock_reset,
                      size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    s.forgotPasswordBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
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
                          : Text(s.sendResetLinkButton,
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
