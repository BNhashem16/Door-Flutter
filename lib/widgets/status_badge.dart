import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/app_theme.dart';

/// Small pill rendering an approval status or a role label.
class StatusBadge extends StatelessWidget {
  const StatusBadge.status(this.status)
      : role = null,
        super(key: null);

  const StatusBadge.role(this.role)
      : status = null,
        super(key: null);

  final UserStatus? status;
  final UserRole? role;

  (String, Color) _content() {
    if (role != null) {
      return switch (role!) {
        UserRole.admin => ('مسؤول', const Color(0xFF7C3AED)),
        UserRole.user => ('مستخدم', const Color(0xFF6B7280)),
      };
    }
    return switch (status!) {
      UserStatus.approved => ('مقبول', const Color(0xFF059669)),
      UserStatus.rejected => ('مرفوض', const Color(0xFFDC2626)),
      UserStatus.pending => ('قيد الانتظار', const Color(0xFFD97706)),
      UserStatus.unknown => ('غير معروف', const Color(0xFF6B7280)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _content();
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
