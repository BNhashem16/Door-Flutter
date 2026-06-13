import 'package:flutter/material.dart';

import '../about/about_developer_screen.dart';
import '../about/legal_content.dart';
import '../about/legal_screen.dart';
import '../admin/admin_screen.dart';
import '../auth/auth_service.dart';
import '../guest/guest_passes_screen.dart';
import '../l10n/app_strings.dart';
import '../notifications/notification_prefs_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../support/my_reports_screen.dart';
import '../support/report_issue_sheet.dart';
import '../theme/app_theme.dart';
import 'initials_avatar.dart';

/// App-wide navigation sidebar: gathers every feature in one place instead of
/// scattering entry points across screens.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.authService,
    required this.isAdmin,
    required this.userName,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onLocaleToggle,
  });

  final AuthService authService;
  final bool isAdmin;
  final String userName;
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final VoidCallback onLocaleToggle;

  /// Closes the drawer, then pushes [screen].
  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = theme.extension<AppColors>()!;
    final s = AppStrings.of(context);
    final user = authService.currentUser;
    final uid = user?.uid ?? '';
    final arabic = Localizations.localeOf(context).languageCode == 'ar';

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            _header(context, theme, colorScheme, user?.email ?? ''),
            const SizedBox(height: AppSpacing.sm),
            _sectionLabel(theme, s.drawerFeaturesSection),
            _tile(
              context,
              icon: Icons.home_rounded,
              title: s.drawerHome,
              onTap: () => Navigator.of(context).pop(),
            ),
            _tile(
              context,
              icon: Icons.person_rounded,
              title: s.profileTitle,
              onTap: () =>
                  _open(context, ProfileScreen(authService: authService)),
            ),
            _tile(
              context,
              icon: Icons.qr_code_2_rounded,
              title: s.guestPassesTitle,
              onTap: () => _open(
                context,
                GuestPassesScreen(authService: authService, userName: userName),
              ),
            ),
            _tile(
              context,
              icon: Icons.notifications_rounded,
              title: s.notificationsTitle,
              onTap: () => _open(context, NotificationsScreen(uid: uid)),
            ),
            _tile(
              context,
              icon: Icons.tune_rounded,
              title: s.notifPrefsTitle,
              onTap: () => _open(
                context,
                NotificationPrefsScreen(authService: authService, uid: uid),
              ),
            ),
            _tile(
              context,
              icon: Icons.support_agent_rounded,
              title: s.reportIssueTitle,
              onTap: () async {
                Navigator.of(context).pop();
                await ReportIssueSheet.show(
                  context,
                  uid: uid,
                  name: userName,
                  email: user?.email ?? '',
                );
              },
            ),
            _tile(
              context,
              icon: Icons.inbox_rounded,
              title: s.myReportsTitle,
              onTap: () => _open(context, MyReportsScreen(uid: uid)),
            ),
            if (isAdmin)
              _tile(
                context,
                icon: Icons.admin_panel_settings_rounded,
                title: s.adminTitle,
                onTap: () => _open(
                  context,
                  AdminScreen(authService: authService, adminName: userName),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            _sectionLabel(theme, s.drawerSettingsSection),
            _tile(
              context,
              icon: isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              title: isDarkMode ? s.lightMode : s.darkMode,
              onTap: onThemeToggle,
            ),
            _tile(
              context,
              icon: Icons.translate_rounded,
              title: s.languageToggleTooltip,
              onTap: onLocaleToggle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            _sectionLabel(theme, s.drawerAboutSection),
            _tile(
              context,
              icon: Icons.privacy_tip_rounded,
              title: s.privacyPolicyTitle,
              onTap: () => _open(
                context,
                LegalScreen(
                  title: s.privacyPolicyTitle,
                  icon: Icons.privacy_tip_rounded,
                  sections: privacySections(arabic: arabic),
                ),
              ),
            ),
            _tile(
              context,
              icon: Icons.gavel_rounded,
              title: s.termsTitle,
              onTap: () => _open(
                context,
                LegalScreen(
                  title: s.termsTitle,
                  icon: Icons.gavel_rounded,
                  sections: termsSections(arabic: arabic),
                ),
              ),
            ),
            _tile(
              context,
              icon: Icons.code_rounded,
              title: s.aboutDeveloperTitle,
              onTap: () => _open(context, const AboutDeveloperScreen()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            _tile(
              context,
              icon: Icons.logout_rounded,
              title: s.signOut,
              color: colors.danger,
              onTap: () {
                Navigator.of(context).pop();
                authService.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String email,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          InitialsAvatar(
            name: userName,
            seed: authService.currentUser?.uid ?? '',
            size: 52,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: theme.textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: color ?? theme.colorScheme.primary, size: 22),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(color: tint),
      ),
      onTap: onTap,
    );
  }
}
