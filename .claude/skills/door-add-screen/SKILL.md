---
name: door-add-screen
description: Use when adding a new screen or feature folder to Door. Step-by-step recipe matching the existing pattern — feature folder, AppTheme styling, Firebase via AuthService stream, Arabic strings, toast errors, AuthGate wiring.
---

# Door — Add a New Screen (recipe)

Door uses plain `StatefulWidget` + `StreamBuilder`, feature folders, and the `AppTheme` token
system. No DI, no bloc, no router package. Match that.

## Steps

1. **Folder.** Create `lib/<feature>/<feature>_screen.dart`. One feature per folder. Keep files
   small (<300 lines); extract widgets into `lib/widgets/` if shared.

2. **Data.** Need Firebase data? Add a method to `AuthService` (or a sibling service) returning a
   `Stream<...>` — don't touch `FirebaseDatabase` from the widget. Consume with `StreamBuilder`,
   null-checking `snapshot.value is Map` before `AppUser.fromMap`. (See skill `door-firebase`.)

3. **UI.** Style only via tokens:
   ```dart
   final colors = Theme.of(context).extension<AppColors>()!;
   ```
   Use `AppSpacing` / `AppRadius`, shared widgets (`SectionCard`, `StatusBadge`, `InitialsAvatar`).
   Arabic strings. Both light + dark must look intentional. (See skill `door-ui`.)

4. **Errors.** User-facing failures → `ToastService` (`lib/toast/toast_service.dart`). Never
   swallow silently. Guard context: `if (!context.mounted) return;` after every `await`.

5. **Routing.** If the screen is gated by auth/role/status, add the branch in
   `lib/auth/auth_gate.dart` — not inside the screen. (See skill `door-auth-flow`.) For a
   push-navigation screen, `Navigator.push` from the parent.

6. **Verify.** `dart_format` → `analyze_files` (Dart MCP) clean → `flutter build apk --debug`
   if structural. Don't report done with analyzer warnings.

## Skeleton

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('عنوان الشاشة')),
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: const SizedBox.shrink(), // build with SectionCard etc.
      ),
    );
  }
}
```

Adjust token names (`colors.background`, `AppSpacing.md`) to whatever `app_theme.dart` actually
defines — read it first.
