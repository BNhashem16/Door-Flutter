import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/language_toggle_button.dart';
import 'auth_service.dart';

/// Shown to authenticated users whose account is not yet approved
/// (pending) or has been rejected by an admin.
class PendingScreen extends StatelessWidget {
  const PendingScreen({
    super.key,
    required this.authService,
    required this.rejected,
  });

  final AuthService authService;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final icon = rejected ? Icons.block : Icons.hourglass_top;
    final color = rejected ? Colors.red : Colors.orange;
    final title = rejected ? s.rejectedTitle : s.pendingTitle;
    final body = rejected ? s.rejectedBody : s.pendingBody;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 96, color: color),
                    const SizedBox(height: 24),
                    Text(title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(body, textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: authService.signOut,
                      icon: const Icon(Icons.logout),
                      label: Text(s.signOut),
                    ),
                  ],
                ),
              ),
            ),
            const PositionedDirectional(
              top: 8,
              end: 8,
              child: LanguageToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
}
