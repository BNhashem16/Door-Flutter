import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'biometric_service.dart';

/// Full-screen lock shown over the authenticated UI. Unlocks via fingerprint
/// or the saved password fallback.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.service,
    required this.onUnlocked,
    required this.onSignOut,
    this.autoPrompt = true,
  });

  final BiometricService service;
  final VoidCallback onUnlocked;
  final VoidCallback onSignOut;

  /// Auto-trigger the fingerprint prompt on first build. Disabled in tests.
  final bool autoPrompt;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = AppStrings.of(context);
    final ok = await widget.service.authenticate(s.biometricUnlockReason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlocked();
  }

  Future<void> _submitPassword() async {
    final creds = await widget.service.readCredentials();
    if (!mounted) return;
    if (creds != null && _passwordCtrl.text == creds.password) {
      widget.onUnlocked();
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(s.lockTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(s.unlockWithFingerprint),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!_showPassword)
                  TextButton(
                    onPressed: () => setState(() => _showPassword = true),
                    child: Text(s.usePasswordInstead),
                  ),
                if (_showPassword) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) {
                      if (_error) setState(() => _error = false);
                    },
                    onSubmitted: (_) => _submitPassword(),
                    decoration: InputDecoration(
                      labelText: s.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: _error ? s.wrongPassword : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitPassword,
                      child: Text(s.confirm),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: widget.onSignOut,
                  child: Text(s.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
