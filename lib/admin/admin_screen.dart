import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/analytics_screen.dart';
import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../support/admin_support_screen.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import '../logs/logs_screen.dart';
import 'admin_user_detail_screen.dart';
import 'admin_user_edit_screen.dart';
import 'announcement_compose_sheet.dart';
import 'audit_log_screen.dart';

/// Admin view: list all users and approve/reject pending ones.
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
    return Scaffold(
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
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: authService.watchAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(s.loadUsersError));
          }
          final users = snapshot.data ?? const <AppUser>[];
          if (users.isEmpty) {
            return Center(child: Text(s.noUsers));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _UserTile(
              authService: authService,
              adminName: adminName,
              user: users[i],
            ),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.authService,
    required this.adminName,
    required this.user,
  });

  final AuthService authService;
  final String adminName;
  final AppUser user;

  /// Flip approval status, record the audit entry, and enqueue a push so the
  /// affected user is told even with their app closed.
  Future<void> _setStatus(UserStatus status) async {
    await authService.setStatus(user.uid, status);
    final approved = status == UserStatus.approved;
    await authService.recordAudit(
      actorName: adminName,
      action: approved ? 'approve' : 'reject',
      targetUid: user.uid,
      targetName: user.name,
    );
    await authService.enqueuePush(
      type: approved ? 'approved' : 'rejected',
      targetUid: user.uid,
    );
  }

  /// Promote/demote and record the audit entry.
  Future<void> _toggleRole() async {
    final makeAdmin = !user.isAdmin;
    await authService.setRole(
      user.uid,
      makeAdmin ? UserRole.admin : UserRole.user,
    );
    await authService.recordAudit(
      actorName: adminName,
      action: makeAdmin ? 'make_admin' : 'remove_admin',
      targetUid: user.uid,
      targetName: user.name,
    );
  }

  /// Issue (or reissue) an access code for a pending user, audit it, and show
  /// the value in a copyable dialog for out-of-band hand-off.
  Future<void> _issueCode(BuildContext context) async {
    final s = AppStrings.of(context);
    try {
      final code = await authService.issueAccessCode(
        uid: user.uid,
        email: user.email,
      );
      await authService.recordAudit(
        actorName: adminName,
        action: 'issue_code',
        targetUid: user.uid,
        targetName: user.name,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.issueCodeTitle),
          content: SelectableText(s.issueCodeBody(code)),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                showToast(context, s.codeCopied);
              },
              icon: const Icon(Icons.copy),
              label: Text(s.copyCode),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.cancel),
            ),
          ],
        ),
      );
    } on Exception {
      if (!context.mounted) return;
      showToast(context, s.issueCodeError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final me = authService.currentUser?.uid == user.uid;
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: SectionCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: user.name, seed: user.uid, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.isEmpty ? s.noName : user.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(user.email,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              StatusBadge.status(user.status),
            ],
          ),
          if (user.isAdmin)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge.role(UserRole.admin),
              ),
            ),
          if (!me) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              children: [
                if (user.status != UserStatus.approved)
                  TextButton.icon(
                    onPressed: () => _setStatus(UserStatus.approved),
                    icon: const Icon(Icons.check, color: Color(0xFF059669)),
                    label: Text(s.approve,
                        style: const TextStyle(color: Color(0xFF059669))),
                  ),
                if (user.status == UserStatus.pending)
                  TextButton.icon(
                    onPressed: () => _issueCode(context),
                    icon: const Icon(Icons.vpn_key_outlined,
                        color: Color(0xFF2563EB)),
                    label: Text(s.issueCodeButton,
                        style: const TextStyle(color: Color(0xFF2563EB))),
                  ),
                if (user.status != UserStatus.rejected)
                  TextButton.icon(
                    onPressed: () => _setStatus(UserStatus.rejected),
                    icon: const Icon(Icons.close, color: Color(0xFFDC2626)),
                    label: Text(s.reject,
                        style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
                TextButton.icon(
                  onPressed: _toggleRole,
                  icon: Icon(
                    user.isAdmin
                        ? Icons.remove_moderator_outlined
                        : Icons.admin_panel_settings_outlined,
                    color: const Color(0xFF7C3AED),
                  ),
                  label: Text(
                    user.isAdmin ? s.removeAdmin : s.makeAdmin,
                    style: const TextStyle(color: Color(0xFF7C3AED)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openEdit(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s.edit),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFDC2626)),
                  label: Text(s.delete,
                      style: const TextStyle(color: Color(0xFFDC2626))),
                ),
              ],
            ),
          ],
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminUserDetailScreen(
          authService: authService,
          adminName: adminName,
          user: user,
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminUserEditScreen(
          authService: authService,
          adminName: adminName,
          user: user,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final s = AppStrings.of(context);
    final name = user.name.isEmpty ? user.email : user.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteUserTitle),
        content: Text(s.deleteUserConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete,
                style: const TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await authService.deleteUser(user.uid);
      await authService.recordAudit(
        actorName: adminName,
        action: 'delete_user',
        targetUid: user.uid,
        targetName: user.name,
      );
      if (!context.mounted) return;
      showToast(context, s.userDeleted);
    } on Exception {
      if (!context.mounted) return;
      showToast(context, s.userDeleteFailed);
    }
  }
}
