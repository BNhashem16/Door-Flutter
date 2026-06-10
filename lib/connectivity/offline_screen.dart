import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Full-screen, opaque blocker shown whenever the device has no network.
///
/// Rendered as the top layer of [ConnectivityGate]'s stack so it covers the
/// entire app — login, lock, gate, admin and any pushed route — while the
/// Navigator stays alive underneath and resumes exactly where it was once the
/// connection returns.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.onRetry});

  /// Re-runs the platform connectivity check. The overlay disappears on its own
  /// when the check (or the live stream) reports the device is back online.
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final s = AppStrings.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colors.dangerSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 60,
                    color: colors.danger,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  s.offlineTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  s.offlineBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(s.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
