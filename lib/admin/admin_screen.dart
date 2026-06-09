import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import '../logs/logs_screen.dart';
import 'admin_user_edit_screen.dart';

/// Admin view: list all users and approve/reject pending ones.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.adminTitle),
        actions: [
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
            itemBuilder: (context, i) =>
                _UserTile(authService: authService, user: users[i]),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.authService, required this.user});

  final AuthService authService;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final me = authService.currentUser?.uid == user.uid;
    return SectionCard(
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
                    onPressed: () =>
                        authService.setStatus(user.uid, UserStatus.approved),
                    icon: const Icon(Icons.check, color: Color(0xFF059669)),
                    label: Text(s.approve,
                        style: const TextStyle(color: Color(0xFF059669))),
                  ),
                if (user.status != UserStatus.rejected)
                  TextButton.icon(
                    onPressed: () =>
                        authService.setStatus(user.uid, UserStatus.rejected),
                    icon: const Icon(Icons.close, color: Color(0xFFDC2626)),
                    label: Text(s.reject,
                        style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
                TextButton.icon(
                  onPressed: () => authService.setRole(
                    user.uid,
                    user.isAdmin ? UserRole.user : UserRole.admin,
                  ),
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
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminUserEditScreen(
          authService: authService,
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
      if (!context.mounted) return;
      showToast(context, s.userDeleted);
    } on Exception {
      if (!context.mounted) return;
      showToast(context, s.userDeleteFailed);
    }
  }
}
