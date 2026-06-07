import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import 'profile_edit_screen.dart';

/// Read-only profile view with an entry point to edit.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final uid = authService.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: uid == null
          ? const Center(child: Text('لا يوجد مستخدم'))
          : StreamBuilder<AppUser?>(
              stream: authService.userProfile(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final user = snap.data;
                if (user == null) {
                  return const Center(child: Text('تعذّر تحميل الملف'));
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
            user.name.isEmpty ? '(بدون اسم)' : user.name,
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
                  label: 'رقم الشقة',
                  value: user.apartment.isEmpty ? 'لم يُضف بعد' : user.apartment,
                ),
                Divider(color: theme.dividerColor, height: AppSpacing.lg),
                InfoRow(
                  label: 'نبذة',
                  value: user.bio.isEmpty ? 'لم تُضف بعد' : user.bio,
                ),
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
              label: const Text('تعديل الملف'),
            ),
          ),
        ],
      ),
    );
  }
}
