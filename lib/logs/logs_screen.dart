import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import 'gate_log.dart';

/// Whose logs the screen shows.
enum LogScope { own, all }

/// Live list of gate access logs. `own` → the signed-in user's own log,
/// `all` → every user's log (admin only).
class LogsScreen extends StatelessWidget {
  const LogsScreen({
    super.key,
    required this.authService,
    required this.scope,
    this.uid,
  });

  final AuthService authService;
  final LogScope scope;

  /// Required for [LogScope.own]; falls back to the current user.
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final showUser = scope == LogScope.all;
    final stream = showUser
        ? authService.watchAllLogs()
        : authService.watchUserLogs(uid ?? authService.currentUser?.uid ?? '');

    return Scaffold(
      appBar: AppBar(title: Text(s.logsTitle)),
      body: StreamBuilder<List<GateLog>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(s.logsLoadError));
          }
          final logs = snap.data ?? const <GateLog>[];
          if (logs.isEmpty) {
            return Center(child: Text(s.noLogs));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _LogTile(log: logs[i], showUser: showUser),
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.showUser});

  final GateLog log;
  final bool showUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final s = AppStrings.of(context);
    final isOpen = log.action == GateAction.open;
    final actionColor = isOpen ? colors.success : colors.danger;

    return SectionCard(
      child: Row(
        children: [
          if (showUser) ...[
            InitialsAvatar(name: log.name, seed: log.uid, size: 40),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showUser) ...[
                  Text(
                    log.name.isEmpty ? s.noName : log.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  _formatTimestamp(log.timestamp),
                  style: theme.textTheme.labelMedium,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 4),
                Text(
                  log.source == GateSource.widget
                      ? s.logSourceWidget
                      : s.logSourceApp,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          _ActionPill(
            label: isOpen ? s.logActionOpen : s.logActionClose,
            color: actionColor,
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
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
    );
  }
}

/// Locale-neutral `yyyy/MM/dd HH:mm` from epoch ms.
String _formatTimestamp(int ms) {
  if (ms == 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}
