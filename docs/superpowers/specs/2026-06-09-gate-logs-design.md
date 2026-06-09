# Gate Access Logs — Design

**Date:** 2026-06-09
**Feature:** Track who opens/closes the gate. Each user sees their own logs; admin sees all.

## Goal

Record every gate state change with who/when/how. Surface logs:
- **User** → own logs only (from profile screen).
- **Admin** → all users' logs (from admin screen).

## Data model — `GateLog`

New `lib/logs/gate_log.dart`. Immutable, hand-written `fromMap`/`toMap` (no code-gen, per project rules).

| field | type | notes |
|---|---|---|
| `id` | String | RTDB push key |
| `uid` | String | who triggered |
| `name` | String | denormalized name for display (survives profile edit/delete) |
| `action` | `GateAction.open` \| `close` | enum |
| `source` | `GateSource.app` \| `widget` | enum |
| `timestamp` | int (epoch ms) | SDK path uses `ServerValue.timestamp`; REST path uses `DateTime.now().millisecondsSinceEpoch` |

## Storage layout

`/gate_logs/{uid}/{logId}` — mirrors the existing `/app_users/{uid}` ownership model.

- User reads own subtree `/gate_logs/{uid}`.
- Admin reads root `/gate_logs` (nested map keyed by uid), flattened client-side.

## Security rules (`database.rules.json`)

Add a `gate_logs` node:

```json
"gate_logs": {
  ".read": "auth != null && root.child('app_users').child(auth.uid).child('role').val() === 'admin'",
  "$uid": {
    ".read": "auth != null && (auth.uid === $uid || root.child('app_users').child(auth.uid).child('role').val() === 'admin')",
    ".write": "auth != null && (auth.uid === $uid || root.child('app_users').child(auth.uid).child('role').val() === 'admin')",
    "$logId": {
      ".validate": "newData.hasChildren(['action', 'timestamp'])"
    }
  }
}
```

- In-app SDK writes pass as `auth.uid === $uid`.
- Widget REST path writes with the embedded DB token (rule bypass) → not blocked.

## Write paths (two writers, one node)

1. **In-app** — `AuthService.logGateAction(uid, name, action, source: GateSource.app)` via SDK.
   Called in `firebase_update_screen.dart` `_toggleGate` after `setOpen` succeeds.
   Keeps widgets off `FirebaseDatabase` directly (project convention).

2. **Widget (headless)** — `GateService.logAction(uid, name, open, source: widget)` REST push.
   GateService already owns the REST transport + embedded token.
   Called in `gate_widget_callback.dart` `gateWidgetTapped` after `toggle` succeeds.
   Needs `uid`+`name` — stashed via `HomeWidget` shared data at sign-in.

## uid/name plumbing for headless widget

- Extend `setWidgetLoggedIn` (gate_widget_callback.dart): also save `widget_uid` + `widget_name` on login; clear on logout.
- Where `setWidgetLoggedIn(true)` is called (AuthGate) pass uid+name.

## UI (new `lib/logs/`)

- `logs_screen.dart` — `StreamBuilder` over logs. Param `scope`:
  - `own` → `AuthService.watchUserLogs(uid)`
  - `all` → `AuthService.watchAllLogs()` (flattens uid map)
  - Newest-first. Reuses `SectionCard`, `StatusBadge`, `InitialsAvatar`, `AppColors`, Arabic strings.
- User entry: row/button in `profile_screen.dart` → `LogsScreen(scope: own)`.
- Admin entry: history icon in `admin_screen.dart` AppBar → `LogsScreen(scope: all)`.

## Service methods (`AuthService`)

- `Stream<List<GateLog>> watchUserLogs(String uid)`
- `Stream<List<GateLog>> watchAllLogs()`
- `Future<void> logGateAction({required String uid, required String name, required GateAction action, required GateSource source})`

## Localization

New `AppStrings` keys (Arabic + English): logs title, action open/close labels, source app/widget labels, empty-state, date formatting.

## Retention

Unlimited for now (YAGNI). Future option: cap to last N entries per user.

## Testing

- `GateLog.fromMap`/`toMap` round-trip unit test.
- `watchAllLogs` flatten correctness.
- Localization key sanity (Arabic + English present).

## Done means

- `dart format .` clean.
- `flutter analyze` → 0 errors.
- Rules deployed (`firebase deploy --only database`).
- `flutter build apk --debug` passes (routing/structural change).
