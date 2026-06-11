import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

/// Per-type notification opt-out. Approval/rejection/ticket-resolved always
/// send (not shown); only the non-critical categories are toggleable. Backed by
/// `/notification_prefs/{uid}` which the Worker reads before each push.
class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({
    super.key,
    required this.authService,
    required this.uid,
  });

  final AuthService authService;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.notifPrefsTitle)),
      body: StreamBuilder<Map<String, bool>>(
        stream: authService.watchNotificationPrefs(uid),
        builder: (context, snap) {
          final prefs = snap.data ?? const <String, bool>{};
          bool on(String type) => prefs[type] ?? true;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _tile(context, 'guest', Icons.qr_code_2_rounded,
                      s.notifPrefGuest, on('guest')),
                  const Divider(height: 1),
                  _tile(context, 'broadcast', Icons.campaign_rounded,
                      s.notifPrefBroadcast, on('broadcast')),
                  const Divider(height: 1),
                  _tile(context, 'ring', Icons.notifications_active_rounded,
                      s.notifPrefRing, on('ring')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, String type, IconData icon, String label,
      bool value) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(label),
      value: value,
      onChanged: (v) => authService.setNotificationPref(uid, type, v),
    );
  }
}
