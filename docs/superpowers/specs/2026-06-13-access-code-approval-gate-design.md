# Admin Access-Code Approval Gate — Design

**Date:** 2026-06-13
**Status:** Approved
**Goal:** Kill auto-approve. A newly registered user reaches the gate-control
screen only after redeeming an admin-issued, email-bound, time-limited access
code. Removes the biggest trust/fraud hole: an OTP-verified stranger currently
gets gate access immediately, moderated only "after the fact."

## Decisions (locked)

- **Gate point:** After registration. User registers as today (email OTP),
  lands on the pending screen with an access-code field. Account exists while
  waiting (`status=pending`).
- **Code delivery:** Admin generates the code in the admin panel and hands it to
  the resident out-of-band (WhatsApp / verbal / paper). No email-infra change.
- **Redemption mechanism:** Synchronous Cloudflare Worker endpoint. Rejected
  alternatives: outbox/cron (≤1 min lag — bad UX for an interactive moment) and
  rules-only (can't securely validate a secret in RTDB rules without exposing it
  or opening a privilege-escalation surface on the most sensitive field).

## Flow

```
register (email OTP, unchanged)
   → completeRegistration writes status = PENDING        (change: was approved)
   → enqueuePush('new_user')                             (admin alerted, unchanged)
   → PendingScreen: code field + "request code" button
        ↓ admin issues 8-char code for this uid (out-of-band hand-off)
   → user types code → app POSTs Worker /access {uid, code}
        ↓ Worker (service account): validate → status=approved, burn code, push "approved"
   → AuthGate profile stream sees approved → gate screen (automatic)
```

## Code mechanism

- **Format:** 8-char base32 `[a-z2-7]{8}` (~10^12 space — brute-force-safe over
  unauthenticated HTTP; same charset as guest tokens). Hand-typed once.
  4–6 digit rejected (guessable, no Worker rate limit).
- **Expiry:** fixed 24h constant, shared by admin issue + Worker validation.
- **Single-use:** burned (`used:true`) on successful redeem.

## Data model — `/access_codes/{uid}` (single active code per user)

```json
{
  "code": "k7m2p4qx",
  "email": "ahmed@x.com",
  "expiresAt": 0,
  "createdAt": 0,
  "createdBy": "<adminUid>",
  "used": false
}
```

Reissue overwrites. Admin-only read+write in rules; Worker reads/burns via
service account (bypasses rules).

## Security rules diff (`database.rules.json`)

- **Add** `access_codes` node: `.read` admin-only, `$uid/.write` admin-only,
  `.validate hasChildren(['code','expiresAt'])`.
- **Extend** `push_outbox/$pushId` self-enqueue to also allow
  `type==='code_request'` (today only `new_user`) with `targetUid===auth.uid`,
  so a pending user can request a fresh code.
- **No change** to `/app_users` status rule — the Worker service account flips it.
- Deploy: `firebase deploy --only database`.

## Worker (`cloudflare/guest-worker/src/index.js`) — new `/access` POST (JSON)

- Body `{uid, code}` → read `/access_codes/{uid}` → validate:
  exists, `!used`, `now ≤ expiresAt`, `code` matches, **and the profile status
  is currently `pending`** (a rejected user's code is dead).
- Valid → `PATCH /app_users/{uid}/status=approved`, set code `used:true`,
  `pushToUser('approved')` (reuses existing Arabic copy + notification-center
  persist), audit `code_redeemed`.
- Returns `{ok:true}` or `{error:'invalid'|'expired'|'used'|'not_pending'}`.
- Cron `drainPushOutbox`: handle `code_request` → alert all admins (name+email,
  like `new_user`); add `code_request` to `_ALWAYS_SEND`.
- Deploy: `wrangler deploy`.

## App changes

- `auth/auth_service.dart`:
  - `completeRegistration` → `status: pending` + update doc comment.
  - `redeemAccessCode(uid, code)` — http POST to the Worker base URL (reuse the
    guest-link base constant), returns a typed result.
  - `issueAccessCode(uid, email)` — admin write of `/access_codes/{uid}` + audit
    `issue_code`.
  - `requestAccessCode()` — enqueue `push_outbox` `code_request` (targetUid=self).
- `auth/pending_screen.dart`: for `pending` (not `rejected`), add an Arabic code
  input + "تفعيل" + "اطلب رمز" button; toast on error; loading state. Style via
  AppTheme.
- Admin (`admin/admin_user_edit_screen.dart` and/or the user tile): "إصدار رمز
  دخول" action on pending users → generate code, write node, show a copyable
  dialog with the value + 24h note. Audit `issue_code`. Code re-viewable while
  unused and unexpired (admin-read-only).
- `l10n/app_strings.dart`: new Arabic (+ EN) strings.

## Edge cases

- Rejected user enters code → Worker `not_pending`, denied.
- Code reused → `used`, denied; prompt to request a new one.
- Single-device session unaffected (stamped at signIn, separate path).
- enqueue / push failures stay best-effort — never block registration or redeem.

## Deploy checklist

1. `firebase deploy --only database` (rules).
2. `wrangler deploy` in `cloudflare/guest-worker/` (Worker).
3. `flutter build apk` with the matched signing key; bump version per the
   release flow.
