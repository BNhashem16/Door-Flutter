import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../toast/toast_service.dart';
import 'auth_service.dart';
import 'biometric_service.dart';

/// Signed-in change-password flow. Confirms the current password (reauth) then
/// sets a new one via [AuthService.changePassword]. If biometric unlock holds
/// saved credentials, they are refreshed so fingerprint login keeps working.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _bio = BiometricService();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final s = AppStrings.of(context);
    final newPassword = _newCtrl.text;
    try {
      await widget.authService.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: newPassword,
      );
      await _refreshBiometricCredentials(newPassword);
      if (!mounted) return;
      showToast(context, s.passwordChanged);
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showToast(context, s.changePasswordError(e.code));
    } catch (_) {
      if (!mounted) return;
      showToast(context, s.unexpectedError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Keep biometric login working: if credentials are stored, replace the
  /// password with the new one. Best-effort — never blocks the change.
  Future<void> _refreshBiometricCredentials(String newPassword) async {
    final creds = await _bio.readCredentials();
    if (creds == null) return;
    await _bio.saveCredentials(creds.email, newPassword);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.changePasswordTitle)),
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
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _currentCtrl,
                    obscureText: _obscureCurrent,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: s.currentPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? s.passwordTooShort : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newCtrl,
                    obscureText: _obscureNew,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: s.newPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? s.passwordTooShort : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureNew,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: s.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        (v != _newCtrl.text) ? s.passwordsDoNotMatch : null,
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
                          : Text(s.updatePasswordButton,
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
