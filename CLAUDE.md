# Door — AI Project Guidelines

Building-gate controller app. Arabic-first UI. Flutter + Firebase (Auth + Realtime Database).
This file is the project's AI context (Laravel Boost equivalent for Flutter). Keep it accurate
when the codebase changes.

## Live Tooling — use the Dart MCP server

The `dart` MCP server is registered in `.mcp.json`. Prefer its tools over guessing:

- `analyze_files` — static analysis (run after edits instead of eyeballing).
- `dart_fix` / `dart_format` — auto-fix and format `.dart` files.
- `run_tests` — execute `flutter test`.
- `pub` — manage dependencies (`pub get`, `add`, `outdated`).
- `hot_reload`, `get_runtime_errors`, `get_widget_tree` — runtime inspection of a running app
  (requires the app launched with the Dart Tooling Daemon / DevTools connected).

After any Dart edit: run `analyze_files` (or `flutter analyze`) and `dart_format`. Don't claim
"done" without a clean analyzer.

## Stack (exact versions — Jan 2026)

- Flutter 3.38.9 (stable) · Dart 3.10.8 · SDK constraint `^3.6.0`
- firebase_core ^4.1.0 · firebase_auth ^6.0.1 · firebase_database ^12.0.0
- shared_preferences ^2.3.2 · http ^1.2.2 · fluttertoast ^8.2.10
- Lints: `package:flutter_lints/flutter.yaml` (flutter_lints ^5.0.0). No extra rules enabled.
- No state-management package. No code-gen (`build_runner`), no freezed/riverpod/bloc.

## Architecture (actual, not aspirational)

Feature-folder layout under `lib/`. Plain `StatefulWidget` + `StreamBuilder` over Firebase
streams. No repository/usecase layers, no DI container.

```
lib/
├── main.dart                 # Firebase.initializeApp → MyApp → AuthGate; theme toggle held in _MyAppState
├── firebase_options.dart     # generated; do not hand-edit
├── auth/
│   ├── auth_service.dart     # AppUser model + AuthService (Auth + RTDB wrapper)
│   ├── auth_gate.dart        # nested StreamBuilder routing: auth state → profile → status
│   ├── device_session.dart   # stable per-install device id via shared_preferences
│   ├── login_screen.dart · register_screen.dart · pending_screen.dart
├── admin/                    # admin_screen (user list, approve/reject; appbar → analytics, support, audit, logs)
│                             #   · admin_user_edit_screen · audit_log.dart (AuditLog) · audit_log_screen.dart
├── profile/                  # profile_screen.dart (live stream) · profile_edit_screen.dart
├── firebase/firebase_update_screen.dart  # gate control screen (main authed screen)
├── gate/gate_service.dart    # gate state read/toggle (SDK + REST); dedicated service exception
├── guest/                    # guest passes: GuestPass(+GuestSchedule) · GuestService · screens (one-shot + recurring)
├── analytics/                # analytics_screen.dart — opens/day bar chart (fl_chart) derived from gate logs
├── support/                  # report-an-issue: SupportTicket · SupportService · report sheet + admin inbox
├── onboarding/               # first-launch Arabic walkthrough (OnboardingScreen + OnboardingStore flag)
├── logs/                     # gate_log.dart (GateLog/GateSource) · logs_screen.dart
├── theme/app_theme.dart      # AppTheme.light/dark + AppColors ThemeExtension, AppSpacing, AppRadius
├── widgets/                  # initials_avatar · status_badge · section_card (shared design system)
└── toast/toast_service.dart  # fluttertoast wrapper
```

**Service-layer exceptions:** widgets normally write through `AuthService`. Dedicated
service wrappers may talk to RTDB directly: `GateService` (gate node), `GuestService`
(`/guest_passes/{ownerUid}`), and `SupportService` (`/support_tickets/{ownerUid}`). Guest
*redemption* and the `usedCount` bump run server-side in the **Cloudflare redeem Worker**
(`cloudflare/guest-worker/`, service-account auth), never the client.

**Recurring guest passes:** a pass with a non-null `GuestSchedule` (weekdays + daily
window + `expiresAt` end date) only opens the gate inside its weekly window. The Worker
enforces the window in Africa/Cairo local time (`scheduleOpenNow`); `GuestPass.openNow`
mirrors it best-effort for the owner UI. Recurrence fields are only written when present,
so the `guest_passes` `.validate` rule is unchanged. **Worker edits require a redeploy**
(`wrangler deploy` in `cloudflare/guest-worker/`).

**Push notifications (send side):** the app's FCM *receive* stack lives in
`messaging/messaging_service.dart` (token saved to `/fcm_tokens/{uid}`, foreground banner,
background handler). The *sender* is the **Cloudflare Worker**, not Cloud Functions:
- **Admin-triggered** (approval / rejection / ticket-resolved): the admin client appends a
  `/push_outbox/{id}` entry (`{type, targetUid, createdAt}`, admin-only rule) via
  `AuthService.enqueuePush`. A Worker **cron** (`wrangler.toml` `[triggers] crontab`, every
  minute) drains the outbox, sends FCM HTTP v1 (Worker owns the Arabic copy, keyed by `type`),
  prunes dead tokens, and deletes the entry. Latency ≤ ~1 min by design — fine for non-urgent
  notices; in-app approval still updates live via the `AuthGate` profile stream.
- **Guest redemption** is inline: after a successful redeem the Worker pushes the host
  (`/fcm_tokens/{ownerUid}`) "تم فتح بوابتك". Real-time, no outbox.
The Worker needs the `firebase.messaging` OAuth scope (already in `SCOPE`). **Any Worker or
rule change here needs both `wrangler deploy` AND `firebase deploy --only database`.**

**Admin audit log:** every admin action (approve/reject/role/edit/delete/resolve-ticket) writes
`/audit_logs/{id}` (`AuthService.recordAudit`, admin-only). Viewable in `audit_log_screen`
(appbar in admin). Actor/target names are denormalized so entries survive user deletion. The
admin's own name threads down as `adminName` from `firebase_update_screen` → `AdminScreen` →
tiles / edit / support screens.

**Gate-open biometric:** opt-in flag in `BiometricService` (`isGateLockEnabled`). When on,
`firebase_update_screen` prompts a fingerprint before the OPEN action (never close, and
skipped when no biometrics are enrolled so it can't lock the user out). Toggle in profile.

## Data model & Firebase

- RTDB instance URL: `https://microiot.firebaseio.com` (hardcoded in `AuthService.databaseUrl`).
- Users live at `/app_users/{uid}`:
  - `email`, `name`, `role` (`user`|`admin`), `status` (`pending`|`approved`|`rejected`),
    `createdAt` (epoch ms), `apartment`, `bio`, `activeDevice`.
- Model: `AppUser` in `auth/auth_service.dart` — immutable, `fromMap`/`toMap`/`copyWith`.
  `copyWith` only exposes `name`/`apartment`/`bio` (the owner-editable fields).
- **Single-device login**: `signIn()` stamps `activeDevice` with this install's id.
  `AuthGate` watches the profile stream; if `activeDevice` no longer matches the local id it
  signs out and shows "logged in elsewhere". Last login wins.

### Security rules (`database.rules.json`) — respect these when changing writes

- Read `/app_users`: admin only. Read `/app_users/$uid`: owner or admin.
- Owner self-write is constrained: on create must be `role=user`, `status=pending`; on update
  CANNOT change `role`, `status`, `email`, `createdAt`. Only admin can change those.
- So profile edits must touch only `name`/`apartment`/`bio` (see `updateProfile`). Do not add
  client writes to protected fields — the rules will reject them.

## Approval flow

register → profile `status=pending` → admin approves in `admin_screen` → `status=approved` →
user reaches gate control screen. Routing handled entirely in `auth_gate.dart` via streams.

## Conventions in this codebase

- UI strings are **Arabic**. Match existing tone when adding screens.
- Imports use relative `./` paths within `lib/` (existing style — keep consistent per file).
- Styling goes through `AppTheme` / `AppColors` / `AppSpacing` / `AppRadius` — no hardcoded
  colors or magic paddings. Use shared widgets (`SectionCard`, `StatusBadge`, `InitialsAvatar`).
- Guard `BuildContext` across `await` with `if (!context.mounted) return;`.
- Errors → user-facing toast via `toast/toast_service.dart`; never silently swallow.

## Commands

```bash
flutter pub get
flutter run                         # debug on connected device/emulator
flutter analyze                     # must be clean before "done"
dart format .
flutter build apk --debug           # build verification (project builds clean)
firebase deploy --only database     # deploy RTDB security rules (database.rules.json)
```

## When implementing

1. Read the relevant feature folder first — patterns here are deliberately simple (no DI/bloc).
2. Reuse `AuthService` methods; don't talk to `FirebaseDatabase` directly from widgets.
3. Keep files small and cohesive; extract shared UI into `widgets/`.
4. Run analyzer + format via the Dart MCP server before reporting completion.

## Project skills (`.claude/skills/`)

Invoke the matching skill before the work:
- `door-firebase` — RTDB / AppUser / security-rule-safe writes / AuthService.
- `door-ui` — AppTheme design system, shared widgets, Arabic, dark mode.
- `door-auth-flow` — AuthGate routing, approval lifecycle, single-device.
- `door-add-screen` — recipe for adding a new screen the project's way.

## Project rules

@.claude/rules/door-conventions.md
@.claude/rules/door-security.md

## Response Language

- Always respond in English, regardless of the language of the incoming message.
- If the user writes in Arabic, translate mentally and answer only in English.
- Use clear, professional language. No bilingual replies, no mirroring.