import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import 'app_notification.dart';
import 'notification_service.dart';

/// In-app notification center: a user's notification history with mark-read and
/// clear-all. Opened from the bell in the gate screen's app bar.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.uid});

  final String uid;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  List<AppNotification> _current = const [];

  Future<void> _clearAll() async {
    final s = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.notificationsClearTitle),
        content: Text(s.notificationsClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.notificationsClear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.clearAll(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.notificationsTitle),
        actions: [
          IconButton(
            tooltip: s.notificationsMarkAllRead,
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () => _service.markAllRead(widget.uid, _current),
          ),
          IconButton(
            tooltip: s.notificationsClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _current.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _service.watch(widget.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          _current = snap.data ?? const <AppNotification>[];
          if (_current.isEmpty) {
            return Center(child: Text(s.notificationsEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: _current.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _NotificationTile(
              note: _current[i],
              onTap: () => _service.markRead(widget.uid, _current[i].id),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.note, required this.onTap});

  final AppNotification note;
  final VoidCallback onTap;

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
    final colors = theme.extension<AppColors>()!;
    final colorScheme = theme.colorScheme;
    final accent = note.read ? colors.muted : colorScheme.primary;

    return SectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: note.read ? null : onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(note.icon, color: accent, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                note.read ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!note.read)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (note.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(note.body, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _formatTime(note.createdAt),
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
