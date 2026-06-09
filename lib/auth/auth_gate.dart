import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../firebase/firebase_update_screen.dart';
import '../gate/gate_widget_callback.dart';
import '../l10n/app_strings.dart';
import '../widgets/language_toggle_button.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'pending_screen.dart';
import 'verify_email_screen.dart';

/// Routes the user to the right screen based on auth + approval state.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.onLocaleToggle,
  });

  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final VoidCallback onLocaleToggle;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  String? _deviceId;

  /// Last value pushed to the home-screen widget lock flag — avoids redundant
  /// SharedPreferences writes on every rebuild.
  bool? _widgetEnabled;

  @override
  void initState() {
    super.initState();
    _authService.currentDeviceId().then((id) {
      if (mounted) setState(() => _deviceId = id);
    });
  }

  /// Keep the widget lock in sync with the resolved auth state. Only an
  /// approved, signed-in user may control the gate from the home screen. The
  /// uid/name are stashed so headless widget taps can be attributed in logs.
  void _syncWidget(bool enabled, {String uid = '', String name = ''}) {
    if (_widgetEnabled == enabled) return;
    _widgetEnabled = enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setWidgetLoggedIn(enabled, uid: uid, name: name);
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
          _syncWidget(false);
          return LoginScreen(authService: _authService);
        }
        return StreamBuilder<AppUser?>(
          stream: _authService.userProfile(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }
            final profile = profileSnap.data;
            // Email verification gate: any not-yet-approved account must
            // confirm its email before proceeding. Approved users (and admins)
            // are grandfathered so accounts created before this feature aren't
            // locked out.
            final emailVerified = profile?.emailVerified ?? false;
            final isApproved = profile?.status == UserStatus.approved;
            if (!isApproved && !emailVerified) {
              _syncWidget(false);
              return VerifyEmailScreen(
                authService: _authService,
                email: user.email ?? '',
              );
            }
            if (profile == null) {
              // Authenticated but no profile record yet → treat as pending.
              _syncWidget(false);
              return PendingScreen(authService: _authService, rejected: false);
            }
            // Single-device: another device claimed this account → sign out.
            if (_deviceId != null &&
                profile.activeDevice.isNotEmpty &&
                profile.activeDevice != _deviceId) {
              _syncWidget(false);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _authService.signOut();
              });
              return const _LoggedOutElsewhere();
            }
            // Only an approved user may control the gate from the widget.
            _syncWidget(
              profile.status == UserStatus.approved,
              uid: user.uid,
              name: profile.name,
            );
            return switch (profile.status) {
              UserStatus.approved => FirebaseUpdateScreen(
                  onThemeToggle: widget.onThemeToggle,
                  isDarkMode: widget.isDarkMode,
                  onLocaleToggle: widget.onLocaleToggle,
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
    final s = AppStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.devices_other, size: 80),
                    const SizedBox(height: 24),
                    Text(
                      s.loggedOutElsewhereTitle,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.loggedOutElsewhereBody,
                      textAlign: TextAlign.center,
                    ),
                  ],
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
