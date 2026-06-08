---
name: door-firebase
description: Use when reading or writing Firebase data in Door — touching AppUser, /app_users, RTDB streams, security rules, register/login, single-device, or admin approval. Ensures writes respect the security rules and go through AuthService.
---

# Door — Firebase (Auth + Realtime Database)

RTDB instance: `https://microiot.firebaseio.com` (hardcoded in `AuthService.databaseUrl`).
All user data lives at `/app_users/{uid}`. Never talk to `FirebaseDatabase` from a widget —
go through `AuthService` in `lib/auth/auth_service.dart`.

## Data model — `/app_users/{uid}`

| field | type | who can write |
|-------|------|---------------|
| `email` | string | set on register only; immutable after |
| `name` | string | owner + admin |
| `role` | `user`\|`admin` | **admin only** |
| `status` | `pending`\|`approved`\|`rejected` | **admin only** |
| `createdAt` | int (epoch ms) | set on register only; immutable |
| `apartment` | string | owner + admin |
| `bio` | string | owner + admin |
| `activeDevice` | string | owner (stamped on signIn) |

Model is `AppUser` — immutable, `fromMap`/`toMap`/`copyWith`. `copyWith` intentionally only
exposes `name`/`apartment`/`bio`.

## Security rules (`database.rules.json`) — the hard constraints

- Read `/app_users` (whole list): **admin only**.
- Read `/app_users/$uid`: owner or admin.
- Owner **create**: must be `role=user`, `status=pending`.
- Owner **update**: CANNOT change `role`, `status`, `email`, `createdAt`. Rules reject the write.
- Only admin changes `role`/`status`.
- `.validate` requires children `['email','name','role','status','createdAt']` to exist.

### Rule: never write protected fields from a non-admin path
If you add a client write that includes `role`/`status`/`email`/`createdAt` for the owner, the
RTDB rejects the whole update. Owner edits must be limited to `name`/`apartment`/`bio` —
mirror `AuthService.updateProfile()`.

## AuthService methods — reuse these

- `register({email, password, name})` → creates Auth user + pending profile via `.set(toMap())`.
- `signIn({email, password})` → signs in, then stamps `activeDevice` with this install's id.
- `userProfile(uid)` → `Stream<AppUser?>` (live).
- `watchAllUsers()` → `Stream<List<AppUser>>` (admin; sorted newest first).
- `setStatus(uid, status)` → admin approve/reject.
- `updateProfile(uid, {name, apartment, bio})` → owner edit (safe fields only).
- `currentDeviceId()` → this install's id (`DeviceSession.id()`).

## Single-device login

`signIn()` writes `activeDevice = DeviceSession.id()`. `AuthGate` watches the profile stream;
if `activeDevice` ≠ local id → sign out + "logged in elsewhere". Last login wins. If you change
device logic, keep the write inside `signIn` and the watch inside `AuthGate`.

## Workflow

1. Read data via a `Stream` + `StreamBuilder` (existing pattern), not one-shot `.get()` unless
   genuinely one-shot.
2. Map snapshots with `AppUser.fromMap` — always null-check `snapshot.value is Map` first.
3. For writes, pick the matching `AuthService` method; add a new one rather than inlining `_db`.
4. Guard `BuildContext` after `await`: `if (!context.mounted) return;`.
5. Run `analyze_files` (Dart MCP) before done. Deploy rule changes: `firebase deploy --only database`.
