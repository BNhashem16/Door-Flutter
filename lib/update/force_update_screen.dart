import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import 'update_info.dart';

/// Hard block shown when this install's build is below `/app_config/minBuild`.
/// No way past it except downloading the new APK — which installs over the
/// old version in place (same package + signature), so users never uninstall.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.info});

  final UpdateInfo info;

  Future<void> _download(BuildContext context) async {
    final s = AppStrings.of(context);
    final uri = Uri.tryParse(info.apkUrl);
    final ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) showToast(context, s.updateOpenFailed);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.elevatedSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  s.updateRequiredTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  s.updateRequiredBody,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
                  textAlign: TextAlign.center,
                ),
                if (info.notes != null && info.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.elevatedSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      info.notes!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.muted),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _download(context),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(s.updateDownloadButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
