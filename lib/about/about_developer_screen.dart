import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';

const _developerPhone = '+201157569289';
const _developerEmail = 'hashem.codes@gmail.com';

/// About-the-developer page: identity card plus direct call/email actions.
class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) showToast(context, AppStrings.of(context).aboutLaunchFailed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.aboutDeveloperTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: InitialsAvatar(
                name: s.developerName,
                seed: _developerEmail,
                size: 88,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              s.developerName,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.developerRole,
              style: theme.textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(s.aboutContactHint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            _contactTile(
              context: context,
              theme: theme,
              colorScheme: colorScheme,
              icon: Icons.phone_rounded,
              label: s.aboutCallAction,
              value: _developerPhone,
              onTap: () => _launch(context, Uri.parse('tel:$_developerPhone')),
            ),
            const SizedBox(height: AppSpacing.md),
            _contactTile(
              context: context,
              theme: theme,
              colorScheme: colorScheme,
              icon: Icons.email_rounded,
              label: s.aboutEmailAction,
              value: _developerEmail,
              onTap: () =>
                  _launch(context, Uri.parse('mailto:$_developerEmail')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.labelMedium,
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
