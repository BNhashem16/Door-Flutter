import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../toast/toast_service.dart';
import 'auth_service.dart';
import 'biometric_service.dart';

/// SwitchListTile that enables/disables the biometric app-open lock.
///
/// Enabling verifies the account password via Firebase reauth before storing
/// it, then confirms with a fingerprint scan. Disabling wipes saved credentials.
class BiometricToggleTile extends StatefulWidget {
  const BiometricToggleTile({super.key, required this.authService});

  final AuthService authService;

  @override
  State<BiometricToggleTile> createState() => _BiometricToggleTileState();
}

class _BiometricToggleTileState extends State<BiometricToggleTile> {
  final _bio = BiometricService();
  bool _enabled = false;
  bool _available = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await _bio.canUseBiometrics();
    final enabled = await _bio.isEnabled();
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
      });
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;
    if (value) {
      await _enable();
    } else {
      await _disable();
    }
  }

  Future<void> _enable() async {
    final s = AppStrings.of(context);
    final password = await _askPassword(s.enableBiometricPasswordPrompt);
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.authService.reauthenticate(password);
      final scanned = await _bio.authenticate(s.biometricEnableScanReason);
      if (!scanned) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final email = widget.authService.currentUser?.email ?? '';
      await _bio.saveCredentials(email, password);
      await _bio.setEnabled(true);
      if (mounted) setState(() => _enabled = true);
    } on FirebaseAuthException {
      if (mounted) showToast(context, s.wrongPassword);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    await _bio.clearCredentials();
    await _bio.setEnabled(false);
    if (mounted) {
      setState(() {
        _enabled = false;
        _busy = false;
      });
    }
  }

  Future<String?> _askPassword(String title) {
    final ctrl = TextEditingController();
    final s = AppStrings.of(context);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          textDirection: TextDirection.ltr,
          autofocus: true,
          decoration: InputDecoration(labelText: s.password),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SwitchListTile(
      value: _enabled,
      onChanged: (_available && !_busy) ? _onChanged : null,
      secondary: const Icon(Icons.fingerprint),
      title: Text(s.biometricLockLabel),
      subtitle: Text(
        _available ? s.biometricLockSubtitle : s.biometricUnavailable,
      ),
    );
  }
}
