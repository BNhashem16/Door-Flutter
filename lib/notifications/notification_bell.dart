import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'app_notification.dart';
import 'notification_service.dart';
import 'notifications_screen.dart';

/// App-bar bell that shows the live unread-notification count as a badge and
/// opens the [NotificationsScreen]. Streams `/notifications/{uid}`.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().watch(uid),
      builder: (context, snap) {
        final unread = (snap.data ?? const <AppNotification>[])
            .where((n) => !n.read)
            .length;
        return IconButton(
          tooltip: s.notificationsTitle,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotificationsScreen(uid: uid),
            ),
          ),
        );
      },
    );
  }
}
