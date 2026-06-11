import 'package:flutter/material.dart';

/// Immutable in-app notification stored under `/notifications/{uid}/{id}`.
///
/// Written by the Cloudflare Worker whenever it sends an FCM push (approval,
/// guest redemption, broadcast, doorbell ring, …) so the app keeps a history
/// even when the OS push is missed or dismissed. Owner read/write per
/// `database.rules.json` (the owner may mark-read / clear).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
  });

  final String id;

  /// Stable category key (`approved` | `rejected` | `ticket_resolved` |
  /// `guest` | `broadcast` | `ring` | `info`). Drives only the leading icon.
  final String type;
  final String title;
  final String body;
  final int createdAt;
  final bool read;

  factory AppNotification.fromMap(String id, Map<dynamic, dynamic> map) {
    return AppNotification(
      id: id,
      type: (map['type'] ?? 'info') as String,
      title: (map['title'] ?? '') as String,
      body: (map['body'] ?? '') as String,
      createdAt: (map['createdAt'] ?? 0) as int,
      read: map['read'] == true,
    );
  }

  /// Leading icon for this notification's category.
  IconData get icon => switch (type) {
        'approved' => Icons.verified_user_rounded,
        'rejected' => Icons.block_rounded,
        'ticket_resolved' => Icons.task_alt_rounded,
        'guest' => Icons.qr_code_2_rounded,
        'broadcast' => Icons.campaign_rounded,
        'ring' => Icons.notifications_active_rounded,
        _ => Icons.notifications_rounded,
      };
}
