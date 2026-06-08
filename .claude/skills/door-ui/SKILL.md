---
name: door-ui
description: Use when building or restyling any Door screen or widget — colors, spacing, theme, dark mode, Arabic text, or shared components. Enforces the AppTheme design system and Arabic-first UI; bans hardcoded colors and magic numbers.
---

# Door — UI & Design System

Arabic-first building-gate app. All styling flows through the token system in
`lib/theme/app_theme.dart`. No hardcoded colors, no magic paddings.

## Tokens — always use these

- `AppTheme.light` / `AppTheme.dark` — wired in `main.dart`. Don't build `ThemeData` ad hoc.
- `AppColors` — `ThemeExtension`. Read via `Theme.of(context).extension<AppColors>()!`
  (or the local `final colors = ...` pattern already in screens). Separate light/dark accents.
- `AppSpacing` — spacing scale. Use instead of raw `EdgeInsets.all(16)`.
- `AppRadius` — corner radii. Use instead of raw `BorderRadius.circular(12)`.

## Shared widgets — reuse, don't reinvent

- `InitialsAvatar` (`widgets/initials_avatar.dart`) — avatar from a name's initials.
- `StatusBadge` (`widgets/status_badge.dart`) — named ctors for status + role.
- `SectionCard` + `InfoRow` (`widgets/section_card.dart`) — card sections and label/value rows.

Before adding a new card/badge/avatar, check these first.

## Rules

- **Arabic strings.** All user-facing text is Arabic. Match the existing tone/voice.
- **No hardcoded colors.** Never `Color(0xFF...)` or `Colors.blue` in screens — pull from `AppColors`.
- **No magic numbers** for spacing/radius — use `AppSpacing` / `AppRadius`.
- **Dark mode is first-class.** Every new surface must look intentional in both themes. Test the
  dark variant — the dark accent is defined separately, not auto-derived.
- **`withOpacity` is deprecated** in this Flutter (3.38) — use `.withValues(alpha: ...)`.
- Animate compositor-friendly props (`opacity`, `transform`) — not `width`/`height`/`padding`.

## Adding a styled widget

1. Grab tokens: `final colors = Theme.of(context).extension<AppColors>()!;`
2. Compose from shared widgets where possible.
3. Spacing via `AppSpacing`, radius via `AppRadius`, color via `colors.*`.
4. Verify both light + dark visually.
5. `dart_format` + `analyze_files` (Dart MCP) before done.

## Theme toggle

Held in `_MyAppState` (`main.dart`) via `themeMode`; `AuthGate` receives `onThemeToggle` +
`isDarkMode` and threads them down. If you add a screen needing the toggle, pass these through —
don't introduce a second source of truth.
