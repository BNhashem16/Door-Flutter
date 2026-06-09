import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_scope.dart';

/// Reusable AR/EN switch. Reads the toggle callback from [LocaleScope], so it
/// works on any screen under `MyApp` with no wiring. The label names the
/// language it switches *to* (reuses [AppStrings.languageToggleTooltip]).
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = LocaleScope.of(context);
    final s = AppStrings.of(context);
    return TextButton.icon(
      onPressed: scope.onToggle,
      icon: const Icon(Icons.language, size: 20),
      label: Text(s.languageToggleTooltip),
    );
  }
}
