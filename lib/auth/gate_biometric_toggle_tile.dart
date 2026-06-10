import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'biometric_service.dart';

/// SwitchListTile that toggles the "require fingerprint to open the gate"
/// guard. Independent of the app-open lock: this only adds a biometric scan
/// before the gate OPEN action. Disabled when the device has no enrolled
/// biometrics so it can never lock the user out of their own gate.
class GateBiometricToggleTile extends StatefulWidget {
  const GateBiometricToggleTile({super.key});

  @override
  State<GateBiometricToggleTile> createState() =>
      _GateBiometricToggleTileState();
}

class _GateBiometricToggleTileState extends State<GateBiometricToggleTile> {
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
    final enabled = await _bio.isGateLockEnabled();
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
      });
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    // Enabling: confirm the user can actually pass the scan, so they don't
    // lock themselves out of opening the gate.
    if (value) {
      final s = AppStrings.of(context);
      final ok = await _bio.authenticate(s.gateBiometricReason);
      if (!ok) {
        if (mounted) setState(() => _busy = false);
        return;
      }
    }
    await _bio.setGateLockEnabled(value);
    if (mounted) {
      setState(() {
        _enabled = value;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SwitchListTile(
      value: _enabled,
      onChanged: (_available && !_busy) ? _onChanged : null,
      secondary: const Icon(Icons.verified_user_outlined),
      title: Text(s.gateBiometricLabel),
      subtitle: Text(
        _available ? s.gateBiometricSubtitle : s.biometricUnavailable,
      ),
    );
  }
}
