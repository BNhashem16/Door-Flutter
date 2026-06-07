# Lite Redesign + User Profile — Design

**Date:** 2026-06-08
**Project:** Door-Flutter (Arabic RTL gate-control app)
**Status:** Approved

## Goal

1. Refresh the UI to a clean, minimal, light look ("lite").
2. Add profile data fields (apartment/unit, bio) on top of existing name/email.
3. Add screens to view and edit profile data.

## Current State

- Flutter, Material 3, blue seed color, light/dark toggle living inline in `main.dart`.
- Auth + RTDB profiles in `lib/auth/auth_service.dart`. `AppUser` model: `uid, email, name, role, status, createdAt`, stored at `/app_users/{uid}`.
- Screens: login, register, pending, admin, `firebase_update_screen` (main gate control).
- Visual style is generic/template-looking: heavy cards, default Material widgets.

## Design Direction

**Clean minimal light:** near-white scaffold, soft-gray surfaces, subtle 1px borders, single accent color, flat (no/low shadows), generous whitespace. Dark mode kept via toggle but refined to match. Design tokens centralized.

## Components

### 1. Theme — `lib/theme/app_theme.dart`
- Extract `_lightTheme`/`_darkTheme` out of `main.dart` into a dedicated file.
- Define shared tokens: spacing scale, corner radius, border colors, accent.
- Light: near-white scaffold, soft-gray cards, hairline borders, flat. Dark: refined equivalent.
- `main.dart` consumes `AppTheme.light` / `AppTheme.dark`.

### 2. Data model — `lib/auth/auth_service.dart`
- Extend `AppUser` with `apartment` (String) and `bio` (String), default empty.
- Update `fromMap` (backward-safe: missing keys → `''`), `toMap`, add `copyWith`.
- New method `AuthService.updateProfile(uid, {name, apartment, bio})` that writes ONLY those three keys via `update(...)` — never touches `role`/`status`/`email`/`createdAt`.

### 3. Reusable widgets — `lib/widgets/`
- `InitialsAvatar` — circle showing first letter of name; background color derived deterministically from `uid` hash. Configurable size.
- `StatusBadge` — pill rendering approval status (approved/pending/rejected) and role (admin/user).
- `SectionCard` — flat surface with hairline border + padding (replaces heavy `Card`).
- `InfoRow` — label/value row used in profile + system info.

### 4. Profile view — `lib/profile/profile_screen.dart`
- Streams `authService.userProfile(uid)`.
- Shows: `InitialsAvatar` (large), name, email, role + status badges, apartment, bio.
- "Edit" button → profile edit screen.
- Empty fields show a muted placeholder (e.g., "لم يُضف بعد").

### 5. Profile edit — `lib/profile/profile_edit_screen.dart`
- Form: name (required), apartment (optional), bio (optional, multiline). Email shown read-only/disabled.
- Save → `authService.updateProfile(...)`, then pop with success snackbar.
- Validation: name non-empty. Uses lite-styled inputs.

### 6. Entry point
- Replace/extend main control (`firebase_update_screen`) AppBar: add a profile action using `InitialsAvatar` (small) → pushes `ProfileScreen`. Keep theme toggle, logout, admin (if admin).

### 7. Restyle existing screens to lite tokens
- `login_screen`, `register_screen`, `pending_screen`, `admin_screen`, `firebase_update_screen`: adopt `SectionCard`, hairline borders, spacing tokens, flat surfaces. Preserve all existing behavior, Arabic strings, RTL, and logic.

### 8. Security — RTDB rules (`database.rules.json`)
- Under `/app_users/{uid}`: the authenticated owner may write `name`, `apartment`, `bio`.
- `role` and `status` writable only by admin (existing rule pattern preserved).
- `email`, `createdAt` immutable after creation (or admin-only).
- Rules must be deployed (`firebase deploy --only database`).

## Data Flow

- Edit profile: ProfileEdit form → `AuthService.updateProfile` → `update()` on `/app_users/{uid}` (3 keys) → live `userProfile` stream pushes update → ProfileScreen + AppBar avatar refresh.
- No new external dependencies. No Firebase Storage.

## Error Handling

- `updateProfile` wrapped in try/catch; surface Arabic error via snackbar on failure.
- Check `context.mounted` after `await` before using context (Flutter 3.7+).
- Stream null/empty profile → show loading or graceful empty state.

## Testing

- Unit: `AppUser.fromMap` backward compatibility (missing apartment/bio → ''), `copyWith`, `toMap` round-trip.
- Widget: ProfileEdit validates empty name; ProfileScreen renders fields + placeholders; `InitialsAvatar` shows correct letter.
- Manual: edit profile end-to-end against RTDB; verify role/status cannot be changed by a normal user (rules).

## Out of Scope

- Profile photo upload (Firebase Storage) — using initials avatar instead.
- Phone number field.
- Fixing the pre-existing hardcoded Firebase URL + auth token in `firebase_update_screen.dart:33` (flagged; separate task).

## File Summary

| Action | File |
|--------|------|
| New | `lib/theme/app_theme.dart` |
| New | `lib/widgets/initials_avatar.dart` |
| New | `lib/widgets/status_badge.dart` |
| New | `lib/widgets/section_card.dart` |
| New | `lib/profile/profile_screen.dart` |
| New | `lib/profile/profile_edit_screen.dart` |
| Edit | `lib/auth/auth_service.dart` (model + updateProfile) |
| Edit | `lib/main.dart` (use AppTheme) |
| Edit | `lib/firebase/firebase_update_screen.dart` (profile entry + restyle) |
| Edit | `lib/auth/login_screen.dart`, `register_screen.dart`, `pending_screen.dart` (restyle) |
| Edit | `lib/admin/admin_screen.dart` (restyle) |
| Edit | `database.rules.json` (profile field rules) |
