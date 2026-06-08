# Biometric App Lock + Saved Credentials — Design

**Date:** 2026-06-09
**Status:** Approved (pending spec review)
**Feature folder:** `lib/auth/`

## Summary

Add a fingerprint **app-open lock** to the Door app plus secure **saved
credentials**. Firebase Auth already persists the session across launches, so
the fingerprint is a UI gate over the already-authenticated gate-control screen,
not a re-authentication against Firebase. Saved credentials serve two roles:
a password **fallback** to unlock when fingerprint fails/unavailable, and
**pre-filling** the login form after a sign-out.

## Decisions (locked)

| Question | Decision |
|----------|----------|
| Fingerprint role | App-open lock over the authenticated UI (session stays in Firebase). |
| Saved password role | Both: lock fallback **and** login-form pre-fill. |
| Lock trigger | Cold start + resume from background after a 60s timeout. Quick app-switches do not re-prompt. |
| Opt-in | Settings toggle in the profile screen, **off by default**. |
| Logout behavior | Keep saved credentials + lock enabled. Manual sign-out does NOT wipe. |

## Architecture

Top-level `AppLock` widget wraps `AuthGate` in `main.dart`. The lock is active
only when `biometricEnabled == true && FirebaseAuth.currentUser != null`. The
login screen is therefore never locked (no signed-in user). `AppLock` owns the
lifecycle observer and the single source of truth for "locked" state.

```
MyApp
└── AppLock                  // lifecycle observer, locked-state owner
    └── AuthGate             // existing routing (unchanged logic)
        ├── LoginScreen      // never locked; pre-fills from saved creds
        ├── PendingScreen
        └── FirebaseUpdateScreen
```

When locked, `AppLock` renders `LockScreen` on top of its child (the child stays
mounted underneath so Firebase streams keep warm).

## Components

### 1. `lib/auth/biometric_service.dart`

Wraps `local_auth`, `flutter_secure_storage`, and `shared_preferences`. Single
boundary for all biometric/credential operations — widgets never touch the
plugins directly (mirrors the `AuthService` convention).

```dart
class BiometricService {
  static const lockTimeout = Duration(seconds: 60);

  Future<bool> isEnabled();                 // shared_preferences flag
  Future<void> setEnabled(bool value);

  Future<bool> canUseBiometrics();          // supported + fingerprint enrolled
  Future<bool> authenticate(String reason); // shows OS fingerprint prompt

  Future<void> saveCredentials(String email, String password); // secure storage
  Future<({String email, String password})?> readCredentials();
  Future<void> clearCredentials();

  Future<void> markBackgrounded();          // stamp epoch ms (shared_preferences)
  Future<bool> lockTimedOut();              // now - stamp > lockTimeout
}
```

- Password is stored **only** in `flutter_secure_storage`
  (Keychain on iOS, EncryptedSharedPreferences on Android). Never in
  `shared_preferences` or plaintext — per `door-security.md` and
  `dart/security.md`.
- The `enabled` flag and the background timestamp are non-sensitive and live in
  `shared_preferences`.

### 2. `lib/auth/app_lock.dart`

`StatefulWidget` + `WidgetsBindingObserver` wrapping a `child`.

- **initState (cold start):** if `isEnabled()` and a user is signed in → start
  in locked state.
- **`AppLifecycleState.paused`:** call `markBackgrounded()`.
- **`AppLifecycleState.resumed`:** if enabled, signed in, and `lockTimedOut()`
  → lock.
- **Render:** locked → `LockScreen(onUnlocked: ...)` over the child; otherwise
  the child.
- Exposes a way to mark "unlocked for this session" so a manual sign-in does not
  immediately re-prompt (the login flow sets the session unlocked).

### 3. `lib/auth/lock_screen.dart`

Full-screen lock UI, styled via `AppTheme`/`AppColors` (no hardcoded colors),
Arabic-first strings.

- Auto-invokes `authenticate()` once when shown (if `canUseBiometrics()`).
- Primary action: fingerprint button (re-trigger scan).
- Fallback: password field → compare against `readCredentials()` password →
  unlock on match.
- Escape hatch: "sign out" button → `AuthService.signOut()` (returns to login).
- On success → `onUnlocked()`.

### 4. `lib/profile/profile_screen.dart` (edit)

Add a `SwitchListTile` ("قفل البصمة" / "Fingerprint lock"):

- **Enable:** prompt for current account password → verify via
  `reauthenticateWithCredential` (rejects a wrong password before anything is
  stored) → `saveCredentials` + `setEnabled(true)` → confirm with one
  `authenticate()` scan. Any failure aborts and leaves the toggle off.
- **Disable:** `clearCredentials()` + `setEnabled(false)`.
- Toggle hidden/disabled if `canUseBiometrics()` is false (with an explanatory
  subtitle).

### 5. `lib/auth/login_screen.dart` (edit)

On init, read saved credentials and pre-fill `_emailCtrl` + `_passwordCtrl` when
present. Purely a convenience pre-fill; the user still taps sign-in.

### 6. `lib/auth/auth_service.dart` (edit)

Add a thin `reauthenticate(String password)` helper (wraps
`EmailAuthProvider.credential` + `currentUser.reauthenticateWithCredential`) so
the profile enable-flow can verify the password without widgets touching
`FirebaseAuth` directly.

### 7. `lib/l10n/app_strings.dart` (edit)

New AR/EN keys: lock screen title, scan prompt/reason, password-fallback label,
wrong-password error, enable/disable toggle label, "no fingerprint enrolled"
subtitle, sign-out-from-lock label.

## Data flow

**Enable (profile):**
password dialog → `reauthenticate` → `saveCredentials` → `setEnabled(true)` →
`authenticate()` confirm.

**Cold start (enabled, signed in):**
`AppLock.initState` → locked → `LockScreen` → fingerprint/fallback → unlocked →
`FirebaseUpdateScreen`.

**Resume after >60s:**
`paused` stamps time → `resumed` sees timeout → locked.

**Logout:** `signOut()` → creds + enabled flag retained → login screen pre-fills.

## Error handling

- `local_auth` exceptions (`PlatformException`: no hardware, not enrolled,
  locked-out) → caught, surface the password fallback + a toast via
  `ToastService`; never crash.
- Wrong fallback password → inline error, stay locked.
- Reauth failure on enable → toast, abort, toggle stays off.
- Guard every `BuildContext` across `await` with `if (!context.mounted) return;`.

## Security

- Stored password lives only in `flutter_secure_storage`.
- Enable path verifies the password against Firebase before storing.
- Single-device enforcement (`activeDevice`) and RTDB security rules untouched —
  no new writes to protected fields.
- No password/PII logging.
- Android `min_sdk 21` already set; `local_auth` + EncryptedSharedPreferences
  require no manifest secrets.

## Testing

- `biometric_service` unit tests with a fake secure-storage + in-memory prefs:
  enabled-flag round-trip, credential save/read/clear, `lockTimedOut` boundary
  (59s vs 61s).
- Widget test: `LockScreen` shows password fallback and unlocks on matching
  password.
- `flutter analyze` clean + `dart format` before done; structural change →
  `flutter build apk --debug`.

## Out of scope (YAGNI)

- PIN-only mode (separate from account password).
- Per-action biometric (e.g. confirm each gate toggle).
- iOS Face ID copy tuning beyond default `local_auth` strings.
- Encrypting the home-screen widget path (widget already auth-gated separately).

## New dependencies

- `local_auth` (official Flutter plugin)
- `flutter_secure_storage`
