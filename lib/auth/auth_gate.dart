import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../firebase/firebase_update_screen.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'pending_screen.dart';

/// Routes the user to the right screen based on auth + approval state.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _authService.currentDeviceId().then((id) {
      if (mounted) setState(() => _deviceId = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = authSnap.data;
        if (user == null) {
          return LoginScreen(authService: _authService);
        }
        return StreamBuilder<AppUser?>(
          stream: _authService.userProfile(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }
            final profile = profileSnap.data;
            if (profile == null) {
              // Authenticated but no profile record yet → treat as pending.
              return PendingScreen(
                  authService: _authService, rejected: false);
            }
            // Single-device: another device claimed this account → sign out.
            if (_deviceId != null &&
                profile.activeDevice.isNotEmpty &&
                profile.activeDevice != _deviceId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _authService.signOut();
              });
              return const _LoggedOutElsewhere();
            }
            return switch (profile.status) {
              UserStatus.approved => FirebaseUpdateScreen(
                  onThemeToggle: widget.onThemeToggle,
                  isDarkMode: widget.isDarkMode,
                  authService: _authService,
                  isAdmin: profile.isAdmin,
                  userName: profile.name,
                ),
              UserStatus.rejected =>
                PendingScreen(authService: _authService, rejected: true),
              _ => PendingScreen(authService: _authService, rejected: false),
            };
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Shown briefly when the account was claimed by another device.
class _LoggedOutElsewhere extends StatelessWidget {
  const _LoggedOutElsewhere();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.devices_other, size: 80),
                const SizedBox(height: 24),
                Text(
                  'تم تسجيل الدخول على جهاز آخر',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'هذا الحساب يُستخدم الآن على جهاز آخر.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
