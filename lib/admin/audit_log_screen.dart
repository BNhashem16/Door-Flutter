import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import 'audit_log.dart';

/// Admin-only history of admin actions (approve / reject / role / edit / delete
/// / ticket-resolve), newest first. Read from `/audit_logs` via
/// [AuthService.watchAuditLogs].
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.auditLogTitle)),
      body: StreamBuilder<List<AuditLog>>(
        stream: authService.watchAuditLogs(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? const <AuditLog>[];
          if (entries.isEmpty) {
            return Center(child: Text(s.auditLogEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _AuditTile(entry: entries[i]),
          );
        },
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditLog entry;

  String _formatTime(int ms) {
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final actor = entry.actorName.isEmpty ? s.noName : entry.actorName;
    final target = entry.targetName.isEmpty ? '' : entry.targetName;

    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: actor, seed: entry.actorUid, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: actor,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' ${s.auditAction(entry.action)} '),
                      TextSpan(
                        text: target,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatTime(entry.timestamp),
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
