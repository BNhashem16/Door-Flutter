# Design — 4-Digit OTP Email Verification + Global Language Toggle

**Date:** 2026-06-09
**Status:** Approved (pending written-spec review)
**Branch:** feat/biometric-app-lock (current)

Two independent features:

- **A — Global language toggle:** the AR/EN switch must be reachable from *every*
  screen, including the pre-login auth screens, not only the inner gate screen.
- **B — 4-digit OTP email verification:** replace Firebase's email-verification
  *link* with a custom 4-digit code delivered in a branded, locale-matched HTML
  email. Sent from a Cloud Function via Brevo (no domain needed — single verified
  sender). Verification state tracked in RTDB.

The two slices share no code and can be built/reviewed independently.

---

## Decisions (locked)

| Topic | Decision |
|---|---|
| Language toggle scope | All screens (global) |
| Language toggle mechanism | A1 — `LocaleScope` InheritedWidget + reusable `LanguageToggleButton` |
| OTP backend | Firebase Cloud Functions (v2 callable, **JavaScript**) |
| Email provider | **Brevo** transactional API, single verified sender (no domain) |
| Verify model | **Replace** Firebase link; track `emailVerified` in RTDB |
| OTP rules | 4 digits · 10-min expiry · max 5 wrong attempts · 60s resend cooldown |
| Email language | Match app locale (AR RTL template / EN LTR template) |

---

## Feature A — Global Language Toggle

### Current state
`onLocaleToggle` is threaded `MyApp → AuthGate → FirebaseUpdateScreen`, and the
toggle button is rendered **only** inside `FirebaseUpdateScreen` (post-login,
post-approval). Login / register / verify / pending / logged-out-elsewhere have
no language switch.

### Design (A1)
1. **`lib/l10n/locale_scope.dart`** — `LocaleScope` (InheritedWidget) holding
   `onToggle` (VoidCallback) and the current `Locale`. Wrapped around `home:` in
   `MyApp.build` so any descendant resolves it via `LocaleScope.of(context)`.
   Immutable; `updateShouldNotify` compares the locale.
2. **`lib/widgets/language_toggle_button.dart`** — reusable `LanguageToggleButton`
   reading `LocaleScope.of(context)`. Renders an `IconButton`/`TextButton` showing
   the language it switches *to* (reuse `AppStrings.languageToggleTooltip`). Styled
   via `AppTheme`/`AppColors` only.
3. **Placement** — drop `LanguageToggleButton` into:
   - `LoginScreen`, `RegisterScreen`, `VerifyEmailScreen`, `PendingScreen`,
     `_LoggedOutElsewhere` — as an AppBar action where an AppBar exists, else a
     `Positioned`/`Align` top-corner button inside `SafeArea` (direction-aware).
   - `FirebaseUpdateScreen` — **replace** its existing bespoke toggle with the
     shared widget (no behaviour change, removes duplication).
4. **Prop cleanup** — `onLocaleToggle` no longer needs to be prop-drilled through
   `AuthGate`/`FirebaseUpdateScreen`; screens read it from `LocaleScope`. Keep
   `MyApp._toggleLocale` + `LocaleStore.save` exactly as-is (persistence unchanged).

### Why A1 over a `MaterialApp.builder` overlay
A floating global pill overlaps AppBar actions and fights RTL edges. Per-screen
placement looks native and keeps each screen self-describing. Cost is one widget
line per screen.

---

## Feature B — 4-Digit OTP Email Verification

### Flow
```
register → FirebaseAuth account + profile { ..., emailVerified: false }
        → client calls sendEmailOtp(locale)            [first code]
        → AuthGate routes unverified/unapproved → VerifyEmailScreen (OTP entry)
        → user types 4 digits → verifyEmailOtp(code)
              success → Admin SDK sets /app_users/{uid}/emailVerified = true
                      → deletes /email_verifications/{uid}
        → profile stream pushes emailVerified=true → AuthGate auto-routes forward
        → [Resend] re-calls sendEmailOtp(locale), 60s cooldown (UI + server)
```

No client-side polling and no `_verifiedOverride` flag: the existing
`userProfile` stream already pushes the `emailVerified` flip live.

### Backend — Cloud Functions (`functions/`, JavaScript, v2 callable)

New `functions/` folder (Node 20). Firebase Admin SDK initialised once.

**`sendEmailOtp(data, context)`**
- Require `context.auth` (else `unauthenticated`). `uid = context.auth.uid`.
- Read `/email_verifications/{uid}`; if `cooldownUntil > now` → throw
  `resource-exhausted` with remaining seconds.
- Generate 4-digit code (`crypto.randomInt(0, 10000)` zero-padded). Generate a
  random salt; `hash = sha256(salt + code)`.
- Write `/email_verifications/{uid} = { hash, salt, expiresAt: now+10min,
  attempts: 0, cooldownUntil: now+60s }` via Admin SDK.
- Resolve locale (`data.locale` ∈ {ar,en}, default ar). Build the matching HTML
  template. POST to Brevo `https://api.brevo.com/v3/smtp/email` with header
  `api-key: <secret>`, body `{ sender, to:[{email}], subject, htmlContent }`.
  Sender email + name from config; recipient from `context.auth.token.email`.
- Return `{ ok: true, cooldownSeconds: 60 }`.

**`verifyEmailOtp(data, context)`**
- Require `context.auth`. Load record; if missing/expired → `failed-precondition`
  (`expired`). If `attempts >= 5` → `failed-precondition` (`too_many`).
- `sha256(salt + data.code) === hash` ?
  - **yes** → `admin.database().ref('/app_users/{uid}/emailVerified').set(true)`,
    delete `/email_verifications/{uid}`, return `{ ok: true }`.
  - **no** → increment `attempts`; return `{ ok: false, attemptsLeft }`.
- All comparisons constant-time.

**Secret/config**
- `BREVO_API_KEY` via `defineSecret('BREVO_API_KEY')` (set with
  `firebase functions:secrets:set`). Sender email/name + region in
  `functions/config.js` (placeholders until Brevo sender verified).

**Region:** default `us-central1`; client must target the same region.

### Data model & security rules

`database.rules.json` changes:

1. `/app_users/$uid` **owner-update** branch — add, alongside the existing
   role/status/email/createdAt guards:
   ```
   newData.child('emailVerified').val() === data.child('emailVerified').val()
   ```
   so an owner can never self-set `emailVerified`. (Admin branch unchanged — the
   Function uses the Admin SDK, which bypasses rules anyway; the admin-role branch
   keeps console/admin edits working.)
2. `/app_users/$uid` **owner-create** branch — add
   `newData.child('emailVerified').val() === false` so new accounts start
   unverified and cannot self-register as verified.
3. New top-level node:
   ```json
   "email_verifications": { ".read": false, ".write": false }
   ```
   Client cannot read codes or write the node; only the Admin SDK (Function)
   touches it.
4. `.validate` `hasChildren([...])` — left as-is (does **not** add `emailVerified`
   to the required list, so existing nodes and admin patches don't break).

**Grandfathering:** existing accounts have no `emailVerified` child → `fromMap`
defaults to `false`. They are only routed to OTP if *not approved*; approved users
and admins skip the gate entirely (unchanged condition). Profile edits on legacy
nodes still pass (null === null).

### Client changes

- **`pubspec.yaml`** — add `cloud_functions` via `flutter pub add cloud_functions`
  (let the resolver pick the version compatible with firebase_core ^4.1.0).
- **`AppUser`** (`auth/auth_service.dart`) — add `final bool emailVerified`
  (default false); include in `fromMap` (`map['emailVerified'] == true`) and
  `toMap` (`'emailVerified': emailVerified`). `copyWith` unchanged (not
  owner-editable).
- **`AuthService`**
  - `register()` — profile map now carries `emailVerified: false`; after
    `set(profile.toMap())`, call `sendEmailOtp(locale)` instead of
    `sendEmailVerification()`.
  - Remove `sendEmailVerification`, `isEmailVerified`, `reloadAndCheckVerified`.
  - Add `Future<void> sendEmailOtp(String locale)` and
    `Future<OtpResult> verifyEmailOtp(String code)` wrapping
    `FirebaseFunctions.instanceFor(region: ...).httpsCallable(...)`. Map
    `FirebaseFunctionsException.code`/`details` to typed results
    (`ok` / `wrong(attemptsLeft)` / `expired` / `tooMany` / `cooldown(seconds)`).
- **`AuthGate`** — `emailVerified` now comes from `profile?.emailVerified ?? false`
  (not `user.emailVerified`). Delete `_verifiedOverride` field + its resets.
  `VerifyEmailScreen` no longer needs `onVerified` (stream re-routes). Keep the
  `!isApproved && !emailVerified` gate.
- **`VerifyEmailScreen`** — rebuilt as OTP entry:
  - 4 single-digit boxes with auto-advance on input and backspace-to-previous;
    assembles a 4-char string. (Hand-rolled with `TextField` + `FocusNode`s — no
    new package, per project no-extra-deps convention.)
  - **Verify** button → `verifyEmailOtp(code)`; toast on wrong
    (`attemptsLeft`), expired, too-many; on `ok` the stream routes forward.
  - **Resend** button → `sendEmailOtp(locale)`, 60s cooldown (existing UI timer;
    server also enforces and returns remaining seconds).
  - Remove the 4-second poll timer.
  - Locale read from `Localizations.localeOf(context).languageCode` to pass to the
    Function.

### Strings (`l10n/app_strings.dart`, AR + EN)
Repurpose/extend the `verifyEmail*` block:
- `verifyEmailBody(email)` → "We sent a 4-digit code to {email}".
- New: `enterCodeHint`, `otpSentToast`, `otpWrong(attemptsLeft)`, `otpExpired`,
  `otpTooManyAttempts`, `otpCooldown(seconds)`, `verifyCodeButton`.
- Keep `verifyEmailResend*`, `signOut`, `unexpectedError`.

### Email template
Two inline-CSS HTML strings (AR RTL `dir="rtl"`, EN LTR), brand header
("تحكم البوابة" / "Gate Control"), large spaced 4-digit code block, a "expires in
10 minutes" line, and a "ignore if you didn't request this" footer. Plain,
client-compatible inline styles (no external CSS/JS).

---

## Setup checklist (must complete before live sending)
1. Brevo account → **verify a single sender** (your Gmail) → copy API key.
2. Upgrade Firebase project to **Blaze** (Functions outbound network requires it).
3. `firebase functions:secrets:set BREVO_API_KEY` ; set sender email/name in
   `functions/config.js`.
4. `firebase deploy --only functions` ; `firebase deploy --only database` (rules).
Until done, the app builds and routes correctly but OTP emails won't deliver.

---

## Testing
- **Functions (unit, `functions/test/`, jest):** code gen format, hash match,
  expiry rejection, attempt cap, cooldown, unauthenticated rejection, Brevo call
  payload (mock fetch).
- **Dart unit:** `AppUser.fromMap/toMap` round-trip incl. `emailVerified`;
  `AuthService` OTP result mapping (fake `FirebaseFunctions`).
- **Widget:** `VerifyEmailScreen` — wrong-code toast, resend disabled during
  cooldown, code assembly.
- **Manual:** register → receive AR email (app in Arabic) → enter code → routes to
  pending; switch to EN, resend → EN email; wrong code ×5 → too-many; language
  toggle visible & working on login/register/verify/pending.
- `flutter analyze` clean, `dart format .`, `flutter build apk --debug` (routing
  change).

---

## File inventory

**New**
- `lib/l10n/locale_scope.dart`
- `lib/widgets/language_toggle_button.dart`
- `functions/index.js`, `functions/email_templates.js`, `functions/config.js`,
  `functions/package.json`, `functions/.gitignore`
- `functions/test/otp.test.js`
- `firebase.json` (add `functions` + `database` config if absent)

**Modified**
- `lib/main.dart` (wrap `LocaleScope`)
- `lib/auth/auth_gate.dart` (emailVerified source, remove override, place toggle)
- `lib/auth/auth_service.dart` (AppUser field, OTP methods)
- `lib/auth/verify_email_screen.dart` (OTP UI)
- `lib/auth/login_screen.dart`, `register_screen.dart`, `pending_screen.dart`
  (toggle placement)
- `lib/firebase/firebase_update_screen.dart` (use shared toggle)
- `lib/l10n/app_strings.dart` (OTP strings)
- `pubspec.yaml` (`cloud_functions`)
- `database.rules.json` (emailVerified guards + email_verifications node)

---

## Out of scope (YAGNI)
- SMS / phone OTP.
- Rich email design system / MJML.
- Rate limiting beyond per-user cooldown + attempt cap.
- Deleting the Firebase Auth account on admin delete (still needs Admin SDK,
  separate concern).
