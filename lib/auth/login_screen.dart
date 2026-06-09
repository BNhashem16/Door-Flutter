import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/language_toggle_button.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _bio = BiometricService();
  bool _loading = false;
  bool _obscure = true;
  bool _canBiometric = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final creds = await _bio.readCredentials();
    if (!mounted) return;
    final enabled = await _bio.isEnabled();
    final available = await _bio.canUseBiometrics();
    if (!mounted) return;
    if (creds != null) {
      if (_emailCtrl.text.isEmpty) _emailCtrl.text = creds.email;
      if (_passwordCtrl.text.isEmpty) _passwordCtrl.text = creds.password;
    }
    setState(() => _canBiometric = enabled && available && creds != null);
  }

  Future<void> _biometricSignIn() async {
    if (_loading) return;
    final s = AppStrings.of(context);
    final scanned = await _bio.authenticate(s.biometricUnlockReason);
    if (!scanned || !mounted) return;
    final creds = await _bio.readCredentials();
    if (creds == null || !mounted) return;
    _emailCtrl.text = creds.email;
    _passwordCtrl.text = creds.password;
    await _submit();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.authService.signIn(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      // AuthGate reacts to the auth state change automatically.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(AppStrings.of(context).signInError(e.code));
    } catch (_) {
      if (!mounted) return;
      _showError(AppStrings.of(context).unexpectedError);
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
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.meeting_room,
                          size: 72, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(s.loginTitle,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: s.email,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? s.emailInvalid
                            : null,
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
                            icon: Icon(_obscure
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? s.passwordTooShort
                            : null,
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(s.signInButton,
                                  style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      if (_canBiometric) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _biometricSignIn,
                            icon: const Icon(Icons.fingerprint),
                            label: Text(s.signInWithFingerprint),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(
                                        authService: widget.authService),
                                  ),
                                ),
                        child: Text(s.noAccountRegister),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const PositionedDirectional(
              top: 8,
              end: 8,
              child: LanguageToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
}
