import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../analytics/analytics_screen.dart';
import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../notifications/notification_prefs_screen.dart';
import '../support/my_reports_screen.dart';
import '../support/report_issue_sheet.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import '../logs/logs_screen.dart';
import '../auth/biometric_toggle_tile.dart';
import '../auth/gate_biometric_toggle_tile.dart';
import '../auth/change_password_screen.dart';
import 'profile_edit_screen.dart';

/// Read-only profile view with an entry point to edit.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final uid = authService.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: Text(s.profileTitle)),
      body: uid == null
          ? Center(child: Text(s.noUser))
          : StreamBuilder<AppUser?>(
              stream: authService.userProfile(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final user = snap.data;
                if (user == null) {
                  return Center(child: Text(s.loadProfileError));
                }
                return _Body(authService: authService, user: user);
              },
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.authService, required this.user});

  final AuthService authService;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: InitialsAvatar(name: user.name, seed: user.uid, size: 96),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            user.name.isEmpty ? s.noName : user.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user.email,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatusBadge.role(user.role),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge.status(user.status),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            child: Column(
              children: [
                InfoRow(
                  label: s.apartment,
                  value:
                      user.apartment.isEmpty ? s.notAddedYet : user.apartment,
                ),
                Divider(color: theme.dividerColor, height: AppSpacing.lg),
                InfoRow(
                  label: s.bio,
                  value: user.bio.isEmpty ? s.notAddedYet : user.bio,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            child: Column(
              children: [
                BiometricToggleTile(authService: authService),
                Divider(color: theme.dividerColor, height: 1),
                const GateBiometricToggleTile(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileEditScreen(
                    authService: authService,
                    user: user,
                  ),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(s.editProfile),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LogsScreen(
                    authService: authService,
                    scope: LogScope.own,
                    uid: user.uid,
                  ),
                ),
              ),
              icon: const Icon(Icons.history),
              label: Text(s.myLogsButton),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ChangePasswordScreen(authService: authService),
                ),
              ),
              icon: const Icon(Icons.lock_reset),
              label: Text(s.changePassword),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalyticsScreen(
                    authService: authService,
                    scope: AnalyticsScope.own,
                    uid: user.uid,
                  ),
                ),
              ),
              icon: const Icon(Icons.insights_outlined),
              label: Text(s.analyticsButton),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _reportIssue(context),
              icon: const Icon(Icons.report_problem_outlined),
              label: Text(s.reportIssueButton),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MyReportsScreen(uid: user.uid),
                ),
              ),
              icon: const Icon(Icons.inbox_outlined),
              label: Text(s.myReportsButton),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationPrefsScreen(
                    authService: authService,
                    uid: user.uid,
                  ),
                ),
              ),
              icon: const Icon(Icons.notifications_outlined),
              label: Text(s.notifPrefsButton),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: () => _deleteAccount(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.extension<AppColors>()!.danger,
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(s.deleteAccountButton),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final s = AppStrings.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || password.isEmpty) return;
    try {
      await authService.deleteOwnAccount(password);
      // Auth state goes null → AuthGate swaps to LoginScreen underneath; pop the
      // pushed profile route so the login screen is shown.
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      final wrong =
          e.code == 'wrong-password' || e.code == 'invalid-credential';
      showToast(
        context,
        wrong ? s.deleteAccountWrongPassword : s.deleteAccountError,
      );
    } on Exception {
      if (!context.mounted) return;
      showToast(context, s.deleteAccountError);
    }
  }

  Future<void> _reportIssue(BuildContext context) async {
    final s = AppStrings.of(context);
    final sent = await ReportIssueSheet.show(
      context,
      uid: user.uid,
      name: user.name,
      email: user.email,
    );
    if (sent == true && context.mounted) {
      showToast(context, s.reportIssueSent);
    }
  }
}

/// Confirm dialog for self-service account deletion. Requires the password to
/// reauthenticate. Returns the entered password, or null on cancel.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    return AlertDialog(
      icon: Icon(Icons.delete_forever_outlined, color: colors.danger),
      title: Text(s.deleteAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.deleteAccountWarning),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: s.deleteAccountPasswordHint,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          style: TextButton.styleFrom(foregroundColor: colors.danger),
          child: Text(s.deleteAccountConfirm),
        ),
      ],
    );
  }
}
