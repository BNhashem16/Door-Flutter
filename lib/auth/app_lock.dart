import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'biometric_service.dart';
import 'lock_screen.dart';

/// Wraps the app and enforces the biometric app-open lock. The lock is active
/// only when biometric is enabled AND a user is signed in, so the login screen
/// is never locked. The [child] stays mounted under the lock so Firebase
/// streams keep warm.
class AppLock extends StatefulWidget {
  const AppLock({
    super.key,
    required this.child,
    required this.authService,
    this.biometricService,
  });

  final Widget child;
  final AuthService authService;
  final BiometricService? biometricService;

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  late final BiometricService _bio =
      widget.biometricService ?? BiometricService();

  bool _locked = false;

  bool get _signedIn => widget.authService.currentUser != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybeLockOnStart();
  }

  Future<void> _maybeLockOnStart() async {
    if (_signedIn && await _bio.isEnabled()) {
      if (mounted) setState(() => _locked = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bio.markBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _maybeLockOnResume();
    }
  }

  Future<void> _maybeLockOnResume() async {
    if (_locked) return;
    if (_signedIn && await _bio.isEnabled() && await _bio.lockTimedOut()) {
      if (mounted) setState(() => _locked = true);
    }
  }

  void _unlock() {
    if (mounted) setState(() => _locked = false);
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
    _unlock();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          LockScreen(
            service: _bio,
            onUnlocked: _unlock,
            onSignOut: _signOut,
          ),
      ],
    );
  }
}
