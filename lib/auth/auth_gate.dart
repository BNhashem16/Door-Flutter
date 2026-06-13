import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../firebase/firebase_update_screen.dart';
import '../gate/gate_widget_callback.dart';
import '../l10n/app_strings.dart';
import '../messaging/messaging_service.dart';
import '../widgets/language_toggle_button.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'pending_screen.dart';

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
  late final _messaging = MessagingService(authService: _authService);
  String? _deviceId;

  /// Uid we last registered an FCM token for — avoids re-registering on every
  /// stream rebuild.
  String? _fcmUid;

  /// Uid we last refreshed the saved-account display name for — avoids a
  /// secure-storage write on every profile-stream rebuild.
  String? _namedUid;

  /// Last value pushed to the home-screen widget lock flag — avoids redundant
  /// SharedPreferences writes on every rebuild.
  bool? _widgetEnabled;

  @override
  void initState() {
    super.initState();
    _authService.currentDeviceId().then((id) {
      if (mounted) setState(() => _deviceId = id);
    });
    unawaited(_messaging.init());
  }

  /// Register this device's push token once per signed-in user. Runs even for
  /// pending users so they receive the approval notification. Guarded so it
  /// fires once per uid despite the auth/profile stream rebuilding often.
  void _ensureFcm(String uid) {
    if (_fcmUid == uid) return;
    _fcmUid = uid;
    unawaited(_messaging.registerForUser(uid));
  }

  /// Push the real display name into the saved-account store once per uid, so
  /// the account switcher shows names instead of bare emails. The email/password
  /// were stored at sign-in time (before the name was known).
  void _ensureAccountName(String uid, String email, String name) {
    if (_namedUid == uid || email.isEmpty || name.isEmpty) return;
    _namedUid = uid;
    unawaited(_authService.accounts.setName(email, name));
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
          _fcmUid = null; // allow re-registration on next sign-in
          _namedUid = null; // re-sync the name after the next sign-in
          return LoginScreen(authService: _authService);
        }
        _ensureFcm(user.uid);
        return StreamBuilder<AppUser?>(
          stream: _authService.userProfile(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }
            final profile = profileSnap.data;
            // Email verification now happens BEFORE the account is created
            // (see RegisterScreen → VerifyEmailScreen → completeRegistration),
            // so any profile that exists here already proved email ownership.
            // Routing is purely by approval status.
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
            _ensureAccountName(user.uid, user.email ?? '', profile.name);
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
