import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'guest_pass.dart';

/// Pill rendering a [GuestPass]'s derived state. Precedence mirrors the redeem
/// Worker: revoked → paused → expired → used-up → active.
class GuestStatusChip extends StatelessWidget {
  const GuestStatusChip(this.pass, {super.key});

  final GuestPass pass;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final primary = Theme.of(context).colorScheme.primary;
    final (label, color) = switch (pass) {
      _ when pass.revoked => (s.guestStatusRevoked, colors.muted),
      _ when pass.paused => (s.guestStatusPaused, primary),
      _ when pass.expired => (s.guestStatusExpired, colors.danger),
      _ when pass.usedUp => (s.guestStatusUsedUp, colors.muted),
      _ => (s.guestStatusActive, colors.success),
    };

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
