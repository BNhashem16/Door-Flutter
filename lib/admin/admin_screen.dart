import 'package:flutter/material.dart';

import '../analytics/analytics_screen.dart';
import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../support/admin_support_screen.dart';
import '../logs/logs_screen.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/section_card.dart';
import 'admin_directory_tab.dart';
import 'admin_users_tab.dart';
import 'announcement_compose_sheet.dart';
import 'audit_log_screen.dart';

/// Admin view: two tabs over the single user stream — a searchable / bulk-
/// actionable user list and a by-unit resident directory. The app-bar actions
/// (announce, analytics, support, audit, logs) are unchanged.
class AdminScreen extends StatelessWidget {
  const AdminScreen({
    super.key,
    required this.authService,
    this.adminName = '',
  });

  final AuthService authService;

  /// The signed-in admin's own name — stamped onto audit-log entries.
  final String adminName;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.adminTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: s.announcementTitle,
              onPressed: () =>
                  AnnouncementComposeSheet.show(context, authService),
            ),
            IconButton(
              icon: const Icon(Icons.insights_outlined),
              tooltip: s.analyticsTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalyticsScreen(
                    authService: authService,
                    scope: AnalyticsScope.all,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.support_agent_outlined),
              tooltip: s.supportInboxTooltip,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminSupportScreen(
                    authService: authService,
                    adminName: adminName,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: s.auditLogTooltip,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AuditLogScreen(authService: authService),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: s.allLogsTooltip,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LogsScreen(
                    authService: authService,
                    scope: LogScope.all,
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: s.adminTabUsers),
              Tab(text: s.adminTabDirectory),
            ],
          ),
        ),
        body: Column(
          children: [
            _gateAlertsToggle(context),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: authService.watchAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(s.loadUsersError));
                  }
                  final users = snapshot.data ?? const <AppUser>[];
                  return TabBarView(
                    children: [
                      AdminUsersTab(
                        authService: authService,
                        adminName: adminName,
                        users: users,
                      ),
                      AdminDirectoryTab(
                        authService: authService,
                        adminName: adminName,
                        users: users,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Master on/off for the gate-activity monitor. Bound live to
  /// `/app_config/gateAlerts`; while on, the Worker cron pushes every admin on
  /// each gate open/close (excluding the actor's own action).
  Widget _gateAlertsToggle(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: StreamBuilder<bool>(
          stream: authService.watchGateAlerts(),
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? false;
            return SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              secondary: Icon(
                enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(s.gateAlertsTitle, style: theme.textTheme.titleMedium),
              subtitle: Text(s.gateAlertsSubtitle,
                  style: theme.textTheme.labelMedium),
              value: enabled,
              onChanged: (next) async {
                try {
                  await authService.setGateAlerts(next);
                } catch (_) {
                  if (!context.mounted) return;
                  showToast(context, s.gateAlertsError);
                }
              },
            );
          },
        ),
      ),
    );
  }
}
