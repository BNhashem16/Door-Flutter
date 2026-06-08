# Door — Project Conventions

Project-specific overrides on top of the global Dart/Flutter rules (`~/.claude/rules/dart/`).
Where these conflict with global rules, **these win** (they describe the actual codebase).

## Architecture (keep it simple — deliberate)

- Plain `StatefulWidget` + `StreamBuilder`. **No** bloc/riverpod/provider/get_it. Do not
  introduce a state-management package or DI container without explicit approval.
- **No code-gen** (`build_runner`, freezed, json_serializable). Hand-written `fromMap`/`toMap`.
- Feature folders under `lib/` (`auth/`, `admin/`, `profile/`, `firebase/`, `theme/`, `widgets/`,
  `toast/`). New features get their own folder.
- Widgets never call `FirebaseDatabase` directly — always through `AuthService`.

## Imports

- This project uses **relative imports** (`'./auth/auth_gate.dart'`, `'../theme/app_theme.dart'`).
  Global rule prefers `package:` imports; **override** — stay consistent with the file you edit.

## UI

- **Arabic-first.** All user-facing strings in Arabic.
- Style only via `AppTheme` / `AppColors` (ThemeExtension) / `AppSpacing` / `AppRadius`.
  No `Color(0xFF...)`, no `Colors.*`, no raw `EdgeInsets.all(16)` in screens.
- Dark mode is first-class — verify both themes.
- `withOpacity` deprecated (Flutter 3.38) → use `.withValues(alpha: ...)`.

## Async / safety

- Guard `BuildContext` after `await`: `if (!context.mounted) return;`.
- User-facing errors → `ToastService`. Never swallow silently.
- `await` every Future or mark `unawaited()`.

## File hygiene

- Files small + cohesive (<300 lines typical, <800 hard cap). Extract shared UI to `widgets/`.
- `final`/`const` by default. Immutable models with `copyWith`.

## Done means

- `dart format .` clean.
- `flutter analyze` / Dart MCP `analyze_files` → 0 errors. Don't claim done with warnings.
- Structural/routing change → `flutter build apk --debug` passes.
