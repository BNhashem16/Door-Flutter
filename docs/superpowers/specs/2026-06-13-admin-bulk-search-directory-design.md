# Admin: Bulk Actions + Search + Resident Directory — Design

**Date:** 2026-06-13
**Feature:** Operational admin tooling — search/filter the user list, bulk approve/suspend,
and browse residents grouped by unit.
**Impact:** Medium · **Complexity:** Low–Medium · **Risk:** Low (no new security rules).

## Problem

Admin reviews users one tile at a time. No search, no filters, no directory by unit. As the
resident count grows, the linear list becomes unusable for the single operator who keeps the
building running.

## Goals

1. Find a user fast — search by name, email, or apartment; filter by status.
2. Act on many users at once — bulk approve / suspend from a selection.
3. Browse residents by unit — "who lives in apartment X" overview.

## Non-Goals (YAGNI)

- No separate unit dropdown filter (units are free-text; the search box covers it).
- No bulk role change (promote/demote stays per-user — rare, high-consequence).
- No bulk delete (too destructive for a multi-select gesture).
- No "select all filtered" button (can add later if needed).

## Decisions (from brainstorming)

- **Scope:** all three parts in one spec.
- **Bulk selection UX:** long-press a tile to enter selection mode (Gmail-style). Normal tap
  opens detail; in selection mode, tap toggles the checkbox.
- **Directory presentation:** two tabs on the admin screen — "Users" and "Directory" — sharing
  one stream.

## Architecture & Files

`admin_screen.dart` today is a `StatelessWidget` with one `StreamBuilder<List<AppUser>>` and an
inline `_UserTile` (319 lines). Three features inline would bust the 800-line cap and tangle
concerns. Split into focused files:

- **`admin/admin_screen.dart`** (slim) — `Scaffold` + existing `AppBar` (keep all 5 action
  icons) + `TabBar` / `TabBarView` with two tabs. Subscribes to `watchAllUsers()` **once** and
  passes the resolved `List<AppUser>` down to both tabs (no double subscription). Owns the
  loading / error / empty states.
- **`admin/admin_users_tab.dart`** *(new)* — `StatefulWidget`. Holds search query, status
  filter, and selection state (`Set<String> selectedUids`, `bool selectionMode`). Renders
  search field + status filter chips + selectable list + contextual bulk action bar. Hosts the
  moved `_UserTile`.
- **`admin/admin_directory_tab.dart`** *(new)* — read-only list grouped by `apartment`, sorted,
  with a per-unit header + resident count. Tap a resident → existing `AdminUserDetailScreen`.
- **`admin/admin_user_filter.dart`** *(new, pure Dart — no Flutter import)* —
  `filterUsers(users, query, status)` and `groupByUnit(users)`. Unit-testable; keeps UI files
  thin.

`_UserTile` moves into `admin_users_tab.dart` and gains `selected`, `selectionMode`,
`onLongPress`, `onSelectToggle`. Tap = open detail when not selecting; toggle checkbox when
selecting. Single-user action buttons (approve/reject/role/edit/delete) are hidden in selection
mode and otherwise unchanged.

## Users Tab — Behavior

- **Search:** `TextField` matches name OR email OR apartment, case-insensitive substring. Email
  rendered LTR (existing convention).
- **Status filter chips:** `All / Pending / Approved / Rejected` (single-select chip row).
- **Combined:** search query AND status filter both apply (`filterUsers`).
- **Empty states:** no users at all → existing `noUsers`; filtered-to-zero → new
  "no matching results" string (distinct).
- Single-user actions unchanged when not in selection mode.

## Bulk Selection (long-press)

- Long-press any tile (except self) → selection mode on: checkboxes appear; the `AppBar` is
  replaced by a contextual bar showing selected count + **Approve all / Suspend all / Clear**.
- Back gesture or Clear exits selection mode and empties the set.
- Self (`authService.currentUser?.uid`) is never selectable — mirrors the existing `if (!me)`
  guard.
- A **confirmation dialog** (count + action) precedes applying any bulk action.

## Bulk Data Flow & Safety

New service method:

```dart
Future<void> setStatusForUsers(List<String> uids, UserStatus status);
```

- One RTDB **multi-path update** — `{ '/app_users/$uid/status': statusString, ... }` for each
  uid — atomic, single round-trip.
- Touches only `status`; never `role` / `email` / `createdAt`. Respects the admin write rule.
  **No new security rules needed** (admin already writes status today).
- After the update succeeds, loop per-uid `recordAudit(action: approve|reject, ...)` and
  `enqueuePush(type: approved|rejected, targetUid)` so history and notifications stay per-user
  (matching the single-user path's audit/push semantics).
- On failure → user-facing toast (`ToastService`); never swallow. Guard `context.mounted`
  after awaits.

## Directory Tab

- `groupByUnit(users)` → `Map<String, List<AppUser>>` keyed by apartment.
- Units sorted numeric-aware (so "2" < "10"); residents within a unit sorted by name.
- Empty / blank apartment → bucketed under a "غير محدد" (unspecified) group, shown last.
- Each unit renders a `SectionCard` with a header (unit label + resident count) and resident
  rows (`InitialsAvatar` + name + `StatusBadge`). Read-only; tap → `AdminUserDetailScreen`.

## Conventions

- Arabic-first UI strings added to `l10n/app_strings.dart` (search hint, filter labels, bulk
  action labels, confirm-dialog copy, "no matching results", "unspecified unit", selected-count).
- Styling only via `AppTheme` / `AppColors` / `AppSpacing` / `AppRadius`; reuse `SectionCard`,
  `StatusBadge`, `InitialsAvatar`. No hardcoded colors / magic paddings.
- Relative imports (existing file style).
- Widgets never touch `FirebaseDatabase` directly — bulk goes through the new `AuthService`
  method.

## Testing

- Unit-test `admin_user_filter.dart`:
  - `filterUsers`: name / email / apartment match, case-insensitivity, status filter, combined
    query + status, empty result.
  - `groupByUnit`: grouping, numeric-aware unit sort, blank-apartment bucket placement,
    within-unit name sort.
- `flutter analyze` clean (0 errors/warnings) + `dart format .`.
- Structural change (tabs, new screens) → `flutter build apk --debug` passes.

## Out-of-Scope / Future

- Select-all-filtered, bulk role/delete, dedicated unit dropdown, directory export.
