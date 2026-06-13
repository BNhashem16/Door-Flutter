import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import 'admin_user_detail_screen.dart';
import 'admin_user_filter.dart';

/// Directory tab: residents grouped by apartment, read-only. Tap a resident to
/// open their detail screen. Receives the resolved user list from the parent.
class AdminDirectoryTab extends StatelessWidget {
  const AdminDirectoryTab({
    super.key,
    required this.authService,
    required this.adminName,
    required this.users,
  });

  final AuthService authService;
  final String adminName;
  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (users.isEmpty) {
      return Center(child: Text(s.noUsers));
    }
    final groups = groupByUnit(users);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final entry = groups[i];
        final residents = entry.value;
        final unitLabel = entry.key == kUnspecifiedUnit
            ? s.unspecifiedUnit
            : '${s.apartment}: ${entry.key}';
        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.home_outlined, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      unitLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Text(
                    s.unitResidents(residents.length),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              for (final u in residents)
                _ResidentRow(
                  authService: authService,
                  adminName: adminName,
                  user: u,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ResidentRow extends StatelessWidget {
  const _ResidentRow({
    required this.authService,
    required this.adminName,
    required this.user,
  });

  final AuthService authService;
  final String adminName;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminUserDetailScreen(
            authService: authService,
            adminName: adminName,
            user: user,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Row(
          children: [
            InitialsAvatar(name: user.name, seed: user.uid, size: 32),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name.isEmpty ? s.noName : user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(user.email,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.labelMedium),
                ],
              ),
            ),
            StatusBadge.status(user.status),
          ],
        ),
      ),
    );
  }
}
