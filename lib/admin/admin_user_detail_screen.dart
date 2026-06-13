import 'package:flutter/material.dart';

import '../analytics/analytics_screen.dart';
import '../auth/auth_service.dart';
import '../guest/guest_pass.dart';
import '../guest/guest_service.dart';
import '../l10n/app_strings.dart';
import '../logs/gate_log.dart';
import '../logs/logs_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import 'admin_user_edit_screen.dart';

/// Admin per-user "open their account" view: profile, single-device binding,
/// gate open/close totals, recent activity, and the visitor passes they issued.
///
/// Everything is read-only and live — three streams the admin is already
/// allowed to read by the RTDB rules (`/app_users`, `/gate_logs/{uid}`,
/// `/guest_passes/{uid}`). No new backend, no rule change.
class AdminUserDetailScreen extends StatelessWidget {
  AdminUserDetailScreen({
    super.key,
    required this.authService,
    required this.user,
    this.adminName = '',
    GuestService? guestService,
  }) : guestService = guestService ?? GuestService();

  final AuthService authService;
  final AppUser user;
  final String adminName;
  final GuestService guestService;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.adminUserDetailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: s.edit,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AdminUserEditScreen(
                  authService: authService,
                  adminName: adminName,
                  user: user,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Header(user: user),
          const SizedBox(height: AppSpacing.md),
          _Overview(user: user),
          const SizedBox(height: AppSpacing.md),
          _Activity(authService: authService, uid: user.uid),
          const SizedBox(height: AppSpacing.md),
          _GuestPasses(guestService: guestService, uid: user.uid),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return SectionCard(
      child: Row(
        children: [
          InitialsAvatar(name: user.name, seed: user.uid, size: 52),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? s.noName : user.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusBadge.status(user.status),
                    StatusBadge.role(user.role),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(s.userOverviewTitle),
          InfoRow(
            label: s.joinedLabel,
            value: _formatDate(user.createdAt),
            valueLtr: true,
          ),
          InfoRow(
            label: s.apartment,
            value: user.apartment.isEmpty ? s.notAddedYet : user.apartment,
          ),
          InfoRow(
            label: s.bio,
            value: user.bio.isEmpty ? s.notAddedYet : user.bio,
          ),
          InfoRow(
            label: s.emailVerifiedLabel,
            value: user.emailVerified ? s.yesLabel : s.noLabel,
          ),
          InfoRow(
            label: s.activeDeviceLabel,
            value: user.activeDevice.isEmpty ? s.deviceNone : s.deviceBound,
          ),
        ],
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity({required this.authService, required this.uid});

  final AuthService authService;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    return SectionCard(
      child: StreamBuilder<List<GateLog>>(
        stream: authService.watchUserLogs(uid),
        builder: (context, snap) {
          final logs = snap.data ?? const <GateLog>[];
          final opens = logs.where((l) => l.action == GateAction.open).length;
          final closes = logs.length - opens;
          final recent = logs.take(5).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(s.recentActivityTitle),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: s.analyticsTotalOpens,
                      value: '$opens',
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatTile(
                      label: s.totalClosesLabel,
                      value: '$closes',
                      color: colors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(s.noLogs,
                      style: Theme.of(context).textTheme.labelMedium),
                )
              else
                ...recent.map((l) => _ActivityRow(log: l)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LogsScreen(
                          authService: authService,
                          scope: LogScope.own,
                          uid: uid,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(s.viewFullLog),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AnalyticsScreen(
                          authService: authService,
                          scope: AnalyticsScope.own,
                          uid: uid,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.insights_outlined, size: 18),
                    label: Text(s.analyticsButton),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.log});

  final GateLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final colors = theme.extension<AppColors>()!;
    final isOpen = log.action == GateAction.open;
    final color = isOpen ? colors.success : colors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.lock_open_outlined : Icons.lock_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _formatDateTime(log.timestamp),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              style: theme.textTheme.labelMedium,
            ),
          ),
          Text(
            switch (log.source) {
              GateSource.widget => s.logSourceWidget,
              GateSource.guest => s.logSourceGuest,
              GateSource.app => s.logSourceApp,
            },
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _GuestPasses extends StatelessWidget {
  const _GuestPasses({required this.guestService, required this.uid});

  final GuestService guestService;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      child: StreamBuilder<List<GuestPass>>(
        stream: guestService.watchPasses(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Text(s.guestPassLoadError,
                style: theme.textTheme.labelMedium);
          }
          final passes = snap.data ?? const <GuestPass>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('${s.guestPassesCountLabel} (${passes.length})'),
              if (passes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(s.guestPassesEmpty,
                      style: theme.textTheme.labelMedium),
                )
              else
                ...passes.map((p) => _GuestRow(pass: p)),
            ],
          );
        },
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({required this.pass});

  final GuestPass pass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final colors = theme.extension<AppColors>()!;
    final (label, color) = _status(s, colors);
    final uses = pass.usesLeft == null
        ? s.guestUsesUnlimited
        : s.guestUsesLeft(pass.usesLeft!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pass.label.isEmpty ? s.guestPassesTitle : pass.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(uses, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _status(AppStrings s, AppColors colors) {
    if (pass.revoked) return (s.guestStatusRevoked, colors.muted);
    if (pass.expired) return (s.guestStatusExpired, colors.muted);
    if (pass.usedUp) return (s.guestStatusUsedUp, colors.muted);
    return (s.guestStatusActive, colors.success);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}

/// `yyyy/MM/dd` from epoch ms.
String _formatDate(int ms) {
  if (ms == 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}/${two(dt.month)}/${two(dt.day)}';
}

/// `yyyy/MM/dd HH:mm` from epoch ms.
String _formatDateTime(int ms) {
  if (ms == 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}
