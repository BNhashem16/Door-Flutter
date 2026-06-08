---
name: door-auth-flow
description: Use when changing routing, login, registration, admin approval, or single-device session logic in Door. Explains the AuthGate stream routing, pending→approved gating, and activeDevice enforcement so changes don't break the gate.
---

# Door — Auth & Routing Flow

All post-launch routing lives in `lib/auth/auth_gate.dart`. It is a nested `StreamBuilder`
chain. Do not scatter routing decisions into individual screens.

## The flow

```
main() → Firebase.initializeApp → MyApp → AuthGate
AuthGate:
  authStateChanges()  ──► null ──────────────► LoginScreen / RegisterScreen
                      └─► User ─► userProfile(uid) stream:
                            ├─ status pending/unknown ─► PendingScreen
                            ├─ status rejected ────────► (rejected message)
                            ├─ status approved + admin ─► AdminScreen (or gate)
                            └─ status approved + user ──► FirebaseUpdateScreen (gate control)
```

## Approval lifecycle

`register()` → profile `status=pending` → user sees `PendingScreen` → admin opens `AdminScreen`,
calls `setStatus(uid, approved)` → stream pushes new status → user auto-advances to gate. No
manual refresh — it's all live streams.

## Single-device enforcement (`activeDevice`)

- Stable per-install id: `DeviceSession.id()` (`auth/device_session.dart`, backed by
  `shared_preferences`).
- `signIn()` stamps `/app_users/{uid}/activeDevice` with this id.
- `AuthGate` loads the local id at init and watches `activeDevice` in the profile stream.
  If `profile.activeDevice` ≠ local id → `signOut()` + show `_LoggedOutElsewhere`.
- **Last login wins**: a new device displaces the old one in real time.

### When editing this
- Keep the `activeDevice` write inside `signIn` only.
- Keep the comparison + sign-out inside `AuthGate`'s profile stream only.
- Don't write `activeDevice` from admin/profile paths — owner-only.
- Remember the security rules: owner can write `activeDevice` but NOT `role`/`status`/`email`/`createdAt`.

## Rules

- New gated screens: add the branch in `AuthGate`, never gate inside the screen itself.
- Any `BuildContext` use after `await` → `if (!context.mounted) return;`.
- Surface auth errors via `toast/toast_service.dart`.
- After edits: `analyze_files` (Dart MCP) must be clean; build the debug APK if routing changed.
