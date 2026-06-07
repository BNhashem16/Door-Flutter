import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

/// Admin view: list all users and approve/reject pending ones.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين')),
      body: StreamBuilder<List<AppUser>>(
        stream: authService.watchAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('تعذّر تحميل المستخدمين'));
          }
          final users = snapshot.data ?? const <AppUser>[];
          if (users.isEmpty) {
            return const Center(child: Text('لا يوجد مستخدمون'));
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
                    Text(user.name.isEmpty ? '(بدون اسم)' : user.name,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (user.status != UserStatus.approved)
                  TextButton.icon(
                    onPressed: () => authService.setStatus(
                        user.uid, UserStatus.approved),
                    icon: const Icon(Icons.check,
                        color: Color(0xFF059669)),
                    label: const Text('موافقة',
                        style: TextStyle(color: Color(0xFF059669))),
                  ),
                if (user.status != UserStatus.rejected)
                  TextButton.icon(
                    onPressed: () => authService.setStatus(
                        user.uid, UserStatus.rejected),
                    icon: const Icon(Icons.close,
                        color: Color(0xFFDC2626)),
                    label: const Text('رفض',
                        style: TextStyle(color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
