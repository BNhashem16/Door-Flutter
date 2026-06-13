# Access-Code Approval Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace auto-approve. A new user registers (status `pending`), an admin issues an 8-char, 24h, single-use access code out-of-band, the user redeems it on the pending screen, and a Cloudflare Worker flips them to `approved`.

**Architecture:** Registration writes `status=pending` instead of `approved`. Admin generates a code stored at `/access_codes/{uid}` (admin-only RTDB node). The pending user POSTs `{uid, code}` to a new Worker `/access` JSON endpoint; the Worker (service account, bypasses rules) validates and sets `status=approved`, burns the code, and pushes the existing "approved" notification. `AuthGate`'s profile stream then routes to the gate screen automatically. A pending user may request a fresh code via a `push_outbox` `code_request` entry the Worker cron fans out to admins.

**Tech Stack:** Flutter (StatefulWidget + StreamBuilder, no DI), Firebase Auth + RTDB, Cloudflare Worker (JS, service-account REST), `http` package, `flutter_test`, `node --test`.

---

## File Structure

- `cloudflare/guest-worker/src/index.js` — MODIFY: add `accessInvalidReason` pure validator, `jsonResponse`, `handleAccess`, route `/access`, `code_request` cron branch, `_ALWAYS_SEND` entry.
- `cloudflare/guest-worker/test/access.test.mjs` — CREATE: node:test unit tests for `accessInvalidReason`.
- `cloudflare/guest-worker/src/access_validator.mjs` — CREATE: extract `accessInvalidReason` as an importable pure module (so both `index.js` and the test use one source).
- `database.rules.json` — MODIFY: add `access_codes` node; extend `push_outbox/$pushId` self-enqueue.
- `lib/auth/auth_service.dart` — MODIFY: `completeRegistration` → pending; add `AccessRedeemResult` enum, `generateAccessCode`, `parseAccessResult`, `issueAccessCode`, `redeemAccessCode`, `requestAccessCode`, constants.
- `test/auth/access_code_test.dart` — CREATE: unit tests for `generateAccessCode` + `parseAccessResult`.
- `lib/l10n/app_strings.dart` — MODIFY: add abstract getters + AR + EN overrides; reword `pendingBody`.
- `lib/auth/pending_screen.dart` — MODIFY: pending case becomes a stateful redeem form.
- `lib/admin/admin_screen.dart` — MODIFY: add "issue access code" action to `_UserTile` for pending users.

---

## Task 1: Worker pure validator + unit test

**Files:**
- Create: `cloudflare/guest-worker/src/access_validator.mjs`
- Create: `cloudflare/guest-worker/test/access.test.mjs`

- [ ] **Step 1: Write the pure validator module**

Create `cloudflare/guest-worker/src/access_validator.mjs`:

```js
'use strict';

// Pure validator for the access-code redeem endpoint. Returns an error reason
// string ('invalid' | 'used' | 'expired' | 'not_pending') or null when the
// redemption is allowed. Kept in its own ESM module so the node:test unit test
// and the Worker (`index.js`) share one source of truth.
//
// rec     — the /access_codes/{uid} record (or null)
// profile — the /app_users/{uid} record (or null)
// code    — the code the caller submitted (already lowercased/trimmed)
// now     — Date.now() epoch ms
export function accessInvalidReason(rec, profile, code, now) {
  if (!rec || typeof rec !== 'object') return 'invalid';
  if (typeof code !== 'string' || rec.code !== code) return 'invalid';
  if (rec.used === true) return 'used';
  if (typeof rec.expiresAt !== 'number' || now > rec.expiresAt) return 'expired';
  if (!profile || typeof profile !== 'object' || profile.status !== 'pending') {
    return 'not_pending';
  }
  return null;
}
```

- [ ] **Step 2: Write the failing test**

Create `cloudflare/guest-worker/test/access.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { accessInvalidReason } from '../src/access_validator.mjs';

const future = 10_000;
const okRec = { code: 'k7m2p4qx', expiresAt: future, used: false };
const pending = { status: 'pending' };

test('valid pending redemption returns null', () => {
  assert.equal(accessInvalidReason(okRec, pending, 'k7m2p4qx', 0), null);
});

test('missing record is invalid', () => {
  assert.equal(accessInvalidReason(null, pending, 'k7m2p4qx', 0), 'invalid');
});

test('wrong code is invalid', () => {
  assert.equal(accessInvalidReason(okRec, pending, 'wrong123', 0), 'invalid');
});

test('used code is used', () => {
  assert.equal(
    accessInvalidReason({ ...okRec, used: true }, pending, 'k7m2p4qx', 0),
    'used',
  );
});

test('expired code is expired', () => {
  assert.equal(
    accessInvalidReason({ ...okRec, expiresAt: 5 }, pending, 'k7m2p4qx', 10),
    'expired',
  );
});

test('approved/rejected profile is not_pending', () => {
  assert.equal(
    accessInvalidReason(okRec, { status: 'rejected' }, 'k7m2p4qx', 0),
    'not_pending',
  );
  assert.equal(
    accessInvalidReason(okRec, null, 'k7m2p4qx', 0),
    'not_pending',
  );
});
```

- [ ] **Step 3: Run the test**

Run: `cd cloudflare/guest-worker && node --test`
Expected: PASS — all 6 tests pass (the module already exists from Step 1).

- [ ] **Step 4: Commit**

```bash
git add cloudflare/guest-worker/src/access_validator.mjs cloudflare/guest-worker/test/access.test.mjs
git commit -m "feat(worker): add access-code pure validator + tests"
```

---

## Task 2: Worker `/access` endpoint + `code_request` cron

**Files:**
- Modify: `cloudflare/guest-worker/src/index.js`

> Note: `index.js` is a plain Worker script (not ESM-importing today). Inline a copy of `accessInvalidReason` here rather than importing the `.mjs` (the Worker bundles a single file; an extra runtime import risks the deploy). The `.mjs` exists only as the tested reference — keep the two bodies identical.

- [ ] **Step 1: Add the inline validator + JSON helper + handler**

In `cloudflare/guest-worker/src/index.js`, immediately AFTER the `htmlResponse` function (around line 341), add:

```js
function jsonResponse(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}

// Mirror of src/access_validator.mjs (kept identical; that module is the tested
// reference). Returns an error reason or null when redemption is allowed.
function accessInvalidReason(rec, profile, code, now) {
  if (!rec || typeof rec !== 'object') return 'invalid';
  if (typeof code !== 'string' || rec.code !== code) return 'invalid';
  if (rec.used === true) return 'used';
  if (typeof rec.expiresAt !== 'number' || now > rec.expiresAt) return 'expired';
  if (!profile || typeof profile !== 'object' || profile.status !== 'pending') {
    return 'not_pending';
  }
  return null;
}

// POST /access {uid, code} — a pending user redeems an admin-issued access
// code. Validates against /access_codes/{uid} + /app_users/{uid}; on success
// flips status to approved (service-account write bypasses the owner-can't-set-
// status rule), burns the code, pushes the "approved" notice, and audits.
async function handleAccess(request, env, token) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'invalid' }, 400);
  }
  const uid = (body.uid || '').toString();
  const code = (body.code || '').toString().trim().toLowerCase();
  if (!uid || !/^[a-z2-7]{8}$/.test(code)) {
    return jsonResponse({ error: 'invalid' }, 400);
  }

  const recRes = await dbFetch(`access_codes/${uid}`, token);
  const profRes = await dbFetch(`app_users/${uid}`, token);
  const rec = recRes.ok ? await recRes.json() : null;
  const profile = profRes.ok ? await profRes.json() : null;

  const reason = accessInvalidReason(rec, profile, code, Date.now());
  if (reason) return jsonResponse({ error: reason }, 200);

  // Approve + burn the code.
  await dbFetch(`app_users/${uid}/status`, token, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify('approved'),
  });
  await dbFetch(`access_codes/${uid}/used`, token, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: 'true',
  });

  const name = (profile && profile.name) || '';
  await pushToUser(
    env,
    token,
    uid,
    _PUSH_COPY.approved[0],
    _PUSH_COPY.approved[1],
    'approved',
  );
  await dbFetch('audit_logs', token, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      actorUid: uid,
      actorName: name,
      action: 'code_redeemed',
      targetUid: uid,
      targetName: name,
      timestamp: Date.now(),
    }),
  }).catch(() => {});

  return jsonResponse({ ok: true }, 200);
}
```

- [ ] **Step 2: Route `/access` in the fetch handler**

In `cloudflare/guest-worker/src/index.js`, inside `fetch`, immediately AFTER the `/ring` block (after its closing `}` near line 715) and BEFORE the `let u = url.searchParams.get('u')` line, add:

```js
    // Access-code redeem (in-app JSON API): pending user → approved.
    if (url.pathname.endsWith('/access')) {
      if (request.method !== 'POST') {
        return jsonResponse({ error: 'invalid' }, 405);
      }
      let token;
      try {
        token = await getAccessToken(env);
      } catch (_) {
        return jsonResponse({ error: 'error' }, 500);
      }
      return handleAccess(request, env, token);
    }
```

- [ ] **Step 3: Add `code_request` cron branch**

In `drainPushOutbox`, AFTER the `new_user` branch's closing `}` and BEFORE the `} else if (item.targetUid) {` line, add:

```js
      } else if (item.type === 'code_request' && item.targetUid) {
        // Pending user asked for a fresh access code → alert every admin.
        const profRes = await dbFetch(
          `app_users/${item.targetUid}`,
          accessToken,
        );
        const prof = profRes.ok ? await profRes.json() : null;
        const name = (prof && prof.name) || 'مستخدم';
        const email = (prof && prof.email) || '';
        const admins = await adminUids(accessToken);
        for (const uid of admins) {
          await pushToUser(
            env,
            accessToken,
            uid,
            'طلب رمز دخول',
            `${name}${email ? ` (${email})` : ''} يطلب رمز دخول. أصدر رمزًا من شاشة الإدارة.`,
            'code_request',
          );
        }
```

- [ ] **Step 4: Add `code_request` to always-send set**

In `cloudflare/guest-worker/src/index.js`, change the `_ALWAYS_SEND` set (around line 474) from:

```js
const _ALWAYS_SEND = new Set([
  'approved',
  'rejected',
  'ticket_resolved',
  'new_user',
]);
```

to:

```js
const _ALWAYS_SEND = new Set([
  'approved',
  'rejected',
  'ticket_resolved',
  'new_user',
  'code_request',
]);
```

- [ ] **Step 5: Sanity-check syntax**

Run: `cd cloudflare/guest-worker && node --check src/index.js`
Expected: no output (exit 0).

- [ ] **Step 6: Commit**

```bash
git add cloudflare/guest-worker/src/index.js
git commit -m "feat(worker): add /access redeem endpoint and code_request alerts"
```

---

## Task 3: Security rules

**Files:**
- Modify: `database.rules.json`

- [ ] **Step 1: Add the `access_codes` node**

In `database.rules.json`, AFTER the `audit_logs` block's closing `}` (line 90) and the comma, add a new sibling node. Insert BEFORE the final `}` that closes `"rules"`:

```json
    "access_codes": {
      ".read": "auth != null && root.child('app_users').child(auth.uid).child('role').val() === 'admin'",
      "$uid": {
        ".write": "auth != null && root.child('app_users').child(auth.uid).child('role').val() === 'admin'",
        ".validate": "newData.hasChildren(['code', 'expiresAt'])"
      }
    }
```

(Add a comma after the `audit_logs` block's closing brace so the JSON stays valid.)

- [ ] **Step 2: Extend `push_outbox` self-enqueue for `code_request`**

In `database.rules.json`, change the `push_outbox/$pushId` `.write` (line 56) from:

```json
        ".write": "auth != null && !data.exists() && newData.child('type').val() === 'new_user' && newData.child('targetUid').val() === auth.uid",
```

to:

```json
        ".write": "auth != null && !data.exists() && (newData.child('type').val() === 'new_user' || newData.child('type').val() === 'code_request') && newData.child('targetUid').val() === auth.uid",
```

- [ ] **Step 3: Validate JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('database.rules.json','utf8')); console.log('ok')"`
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add database.rules.json
git commit -m "feat(rules): add access_codes node and code_request self-enqueue"
```

---

## Task 4: AuthService — registration change + access-code methods

**Files:**
- Modify: `lib/auth/auth_service.dart`
- Test: `test/auth/access_code_test.dart`

- [ ] **Step 1: Write the failing unit test**

Create `test/auth/access_code_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:door_app/auth/auth_service.dart';

void main() {
  group('generateAccessCode', () {
    test('produces 8 base32 [a-z2-7] chars', () {
      for (var i = 0; i < 50; i++) {
        final code = AuthService.generateAccessCode();
        expect(code, matches(RegExp(r'^[a-z2-7]{8}$')));
      }
    });

    test('is not constant across calls', () {
      final a = AuthService.generateAccessCode();
      final b = AuthService.generateAccessCode();
      expect(a == b, isFalse);
    });
  });

  group('parseAccessResult', () {
    test('ok=true → ok', () {
      expect(AuthService.parseAccessResult({'ok': true}),
          AccessRedeemResult.ok);
    });
    test('maps each error string', () {
      expect(AuthService.parseAccessResult({'error': 'expired'}),
          AccessRedeemResult.expired);
      expect(AuthService.parseAccessResult({'error': 'used'}),
          AccessRedeemResult.used);
      expect(AuthService.parseAccessResult({'error': 'not_pending'}),
          AccessRedeemResult.notPending);
      expect(AuthService.parseAccessResult({'error': 'invalid'}),
          AccessRedeemResult.invalid);
    });
    test('unknown error → invalid', () {
      expect(AuthService.parseAccessResult({'error': 'weird'}),
          AccessRedeemResult.invalid);
      expect(AuthService.parseAccessResult({}), AccessRedeemResult.invalid);
    });
  });
}
```

> The package import is `package:door_app/...` — confirm the package name in `pubspec.yaml` (`name:` field) and adjust the import if it differs.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/auth/access_code_test.dart`
Expected: FAIL — `generateAccessCode`/`parseAccessResult`/`AccessRedeemResult` undefined.

- [ ] **Step 3: Add imports + enum at the top of `auth_service.dart`**

In `lib/auth/auth_service.dart`, add to the import block (after line 6):

```dart
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
```

Then, immediately AFTER the `enum UserRole { user, admin }` line (line 20), add:

```dart
/// Outcome of redeeming an access code through the Worker `/access` endpoint.
enum AccessRedeemResult { ok, invalid, expired, used, notPending, networkError }
```

- [ ] **Step 4: Flip registration to pending**

In `completeRegistration`, change the status (lines 200-203) from:

```dart
      // Auto-approve on signup: the email OTP already proved ownership, so new
      // residents get access immediately. The admin reviews the user list and
      // suspends (rejects) anyone who shouldn't be there.
      status: UserStatus.approved,
```

to:

```dart
      // No auto-approve: a new resident lands on the pending screen and must
      // redeem an admin-issued access code (see issueAccessCode /
      // redeemAccessCode) before reaching the gate. The 'new_user' push below
      // alerts admins to issue a code.
      status: UserStatus.pending,
```

- [ ] **Step 5: Add the access-code methods**

In `lib/auth/auth_service.dart`, immediately BEFORE the `static String _roleRaw` line (line 558), add:

```dart
  // --- Access codes (/access_codes/{uid}) ---
  // Admin issues a single-use, 24h, email-bound code out-of-band; the pending
  // user redeems it through the Worker, which (service account) flips status to
  // approved. The status write itself can never happen client-side — the rules
  // forbid an owner changing their own status.

  /// Public Cloudflare Worker base (shared with the guest redeem links).
  static const String _workerBase = 'https://door-gate.hashem-codes.workers.dev';

  /// How long an issued access code stays valid.
  static const Duration accessCodeTtl = Duration(hours: 24);

  static const String _codeAlphabet = 'abcdefghijklmnopqrstuvwxyz234567';

  /// Cryptographically-strong 8-char base32 code (~40 bits), hand-typed once.
  static String generateAccessCode() {
    final rng = Random.secure();
    return List.generate(
      8,
      (_) => _codeAlphabet[rng.nextInt(_codeAlphabet.length)],
    ).join();
  }

  /// Map the Worker `/access` JSON body to a typed result. Pure — unit-tested.
  static AccessRedeemResult parseAccessResult(Map<String, dynamic> body) {
    if (body['ok'] == true) return AccessRedeemResult.ok;
    return switch (body['error']) {
      'expired' => AccessRedeemResult.expired,
      'used' => AccessRedeemResult.used,
      'not_pending' => AccessRedeemResult.notPending,
      _ => AccessRedeemResult.invalid,
    };
  }

  /// Admin: issue (or reissue, overwriting) an access code for [uid]. Returns
  /// the plaintext code so the caller can show it for out-of-band hand-off.
  Future<String> issueAccessCode({
    required String uid,
    required String email,
  }) async {
    final code = generateAccessCode();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.ref('access_codes/$uid').set({
      'code': code,
      'email': email.trim(),
      'createdAt': now,
      'expiresAt': now + accessCodeTtl.inMilliseconds,
      'createdBy': _auth.currentUser?.uid ?? '',
      'used': false,
    });
    return code;
  }

  /// Pending user: redeem [code] via the Worker. On [AccessRedeemResult.ok] the
  /// profile stream observed by [AuthGate] flips to approved and routes onward.
  Future<AccessRedeemResult> redeemAccessCode({
    required String uid,
    required String code,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_workerBase/access'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid, 'code': code.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 && res.statusCode != 400) {
        return AccessRedeemResult.networkError;
      }
      final body = jsonDecode(res.body);
      if (body is! Map) return AccessRedeemResult.invalid;
      return parseAccessResult(body.cast<String, dynamic>());
    } on Exception {
      return AccessRedeemResult.networkError;
    }
  }

  /// Pending user: ask admins to issue a fresh code. The Worker cron fans this
  /// out to every admin. Best-effort — a thrown future is the caller's to toast.
  Future<void> requestAccessCode() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Future<void>.value();
    return _db.ref('push_outbox').push().set({
      'type': 'code_request',
      'targetUid': uid,
      'createdAt': ServerValue.timestamp,
    });
  }

```

- [ ] **Step 6: Run the unit test**

Run: `flutter test test/auth/access_code_test.dart`
Expected: PASS.

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/auth/auth_service.dart`
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/auth/auth_service.dart test/auth/access_code_test.dart
git commit -m "feat(auth): pending-by-default + access-code issue/redeem/request"
```

---

## Task 5: Localized strings

**Files:**
- Modify: `lib/l10n/app_strings.dart`

- [ ] **Step 1: Add abstract getters**

In `lib/l10n/app_strings.dart`, replace the `// Pending / rejected` block (lines 88-92) with:

```dart
  // Pending / rejected
  String get pendingTitle;
  String get pendingBody;
  String get rejectedTitle;
  String get rejectedBody;
  String get accessCodeLabel;
  String get activateCodeButton;
  String get requestCodeButton;
  String get codeRequested;
  String get codeRequestError;
  String get codeInvalid;
  String get codeExpired;
  String get codeUsed;
  String get codeNetworkError;
  // Admin: issue access code
  String get issueCodeButton;
  String get issueCodeTitle;
  String issueCodeBody(String code);
  String get issueCodeError;
  String get copyCode;
  String get codeCopied;
```

- [ ] **Step 2: Add Arabic overrides + reword pendingBody**

In `lib/l10n/app_strings.dart`, replace the Arabic `pendingBody` (lines 558-559) and add the new getters right after `rejectedBody` (after line 564). Replace lines 556-564 with:

```dart
  @override
  String get pendingTitle => 'بانتظار التفعيل';
  @override
  String get pendingBody =>
      'تم إنشاء حسابك. أدخل رمز الدخول الذي حصلت عليه من إدارة المبنى لتفعيل حسابك.';
  @override
  String get rejectedTitle => 'تم رفض الحساب';
  @override
  String get rejectedBody =>
      'تم رفض حسابك. تواصل مع المسؤول لمزيد من المعلومات.';
  @override
  String get accessCodeLabel => 'رمز الدخول';
  @override
  String get activateCodeButton => 'تفعيل';
  @override
  String get requestCodeButton => 'اطلب رمز دخول';
  @override
  String get codeRequested => 'تم إرسال طلبك. سيصلك رمز قريبًا من الإدارة.';
  @override
  String get codeRequestError => 'تعذّر إرسال الطلب. حاول مرة أخرى.';
  @override
  String get codeInvalid => 'رمز غير صحيح.';
  @override
  String get codeExpired => 'انتهت صلاحية الرمز. اطلب رمزًا جديدًا.';
  @override
  String get codeUsed => 'تم استخدام هذا الرمز من قبل.';
  @override
  String get codeNetworkError => 'تعذّر الاتصال. تأكد من الإنترنت وحاول مجددًا.';
  @override
  String get issueCodeButton => 'إصدار رمز';
  @override
  String get issueCodeTitle => 'رمز الدخول';
  @override
  String issueCodeBody(String code) =>
      'الرمز: $code\nصالح لمدة ٢٤ ساعة ولمرة واحدة. سلّمه للمستخدم لتفعيل حسابه.';
  @override
  String get issueCodeError => 'تعذّر إصدار الرمز. حاول مرة أخرى.';
  @override
  String get copyCode => 'نسخ الرمز';
  @override
  String get codeCopied => 'تم نسخ الرمز';
```

- [ ] **Step 3: Add English overrides + reword pendingBody**

In `lib/l10n/app_strings.dart`, replace the English block (lines 1298-1306) with:

```dart
  @override
  String get pendingTitle => 'Awaiting activation';
  @override
  String get pendingBody =>
      'Your account was created. Enter the access code you received from the building admin to activate it.';
  @override
  String get rejectedTitle => 'Account rejected';
  @override
  String get rejectedBody =>
      'Your account was rejected. Contact the administrator for more information.';
  @override
  String get accessCodeLabel => 'Access code';
  @override
  String get activateCodeButton => 'Activate';
  @override
  String get requestCodeButton => 'Request a code';
  @override
  String get codeRequested => 'Request sent. The admin will send you a code soon.';
  @override
  String get codeRequestError => 'Could not send the request. Try again.';
  @override
  String get codeInvalid => 'Invalid code.';
  @override
  String get codeExpired => 'The code expired. Request a new one.';
  @override
  String get codeUsed => 'This code was already used.';
  @override
  String get codeNetworkError => 'Connection failed. Check your internet and retry.';
  @override
  String get issueCodeButton => 'Issue code';
  @override
  String get issueCodeTitle => 'Access code';
  @override
  String issueCodeBody(String code) =>
      'Code: $code\nValid for 24 hours, single use. Hand it to the user to activate their account.';
  @override
  String get issueCodeError => 'Could not issue the code. Try again.';
  @override
  String get copyCode => 'Copy code';
  @override
  String get codeCopied => 'Code copied';
```

- [ ] **Step 4: Analyze (catches any missing override)**

Run: `flutter analyze lib/l10n/app_strings.dart`
Expected: No issues. (If a concrete class is missing an override, the analyzer flags it here — add it to that class.)

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat(l10n): access-code strings (AR/EN)"
```

---

## Task 6: Pending screen redeem form

**Files:**
- Modify: `lib/auth/pending_screen.dart`

- [ ] **Step 1: Replace the file with a stateful redeem form**

Replace the entire contents of `lib/auth/pending_screen.dart` with:

```dart
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/language_toggle_button.dart';
import 'auth_service.dart';

/// Shown to authenticated users whose account is not yet approved.
///
/// `rejected` users see a terminal message. `pending` users get an access-code
/// redeem form: enter the admin-issued code → Worker flips status to approved →
/// [AuthGate]'s profile stream routes onward automatically.
class PendingScreen extends StatefulWidget {
  const PendingScreen({
    super.key,
    required this.authService,
    required this.rejected,
  });

  final AuthService authService;
  final bool rejected;

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  final _codeCtrl = TextEditingController();
  bool _redeeming = false;
  bool _requesting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String _errorText(AppStrings s, AccessRedeemResult r) => switch (r) {
        AccessRedeemResult.expired => s.codeExpired,
        AccessRedeemResult.used => s.codeUsed,
        AccessRedeemResult.networkError => s.codeNetworkError,
        AccessRedeemResult.notPending ||
        AccessRedeemResult.invalid =>
          s.codeInvalid,
        AccessRedeemResult.ok => '',
      };

  Future<void> _redeem() async {
    final s = AppStrings.of(context);
    final uid = widget.authService.currentUser?.uid;
    final code = _codeCtrl.text.trim();
    if (uid == null || code.isEmpty) return;
    setState(() => _redeeming = true);
    try {
      final result =
          await widget.authService.redeemAccessCode(uid: uid, code: code);
      if (!mounted) return;
      // On success the AuthGate stream routes away; just toast on failure.
      if (result != AccessRedeemResult.ok) {
        showToast(context, _errorText(s, result));
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _requestCode() async {
    final s = AppStrings.of(context);
    setState(() => _requesting = true);
    try {
      await widget.authService.requestAccessCode();
      if (!mounted) return;
      showToast(context, s.codeRequested);
    } on Exception {
      if (!mounted) return;
      showToast(context, s.codeRequestError);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final rejected = widget.rejected;
    final icon = rejected ? Icons.block : Icons.hourglass_top;
    final color = rejected ? Colors.red : Colors.orange;
    final title = rejected ? s.rejectedTitle : s.pendingTitle;
    final body = rejected ? s.rejectedBody : s.pendingBody;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 96, color: color),
                    const SizedBox(height: AppSpacing.lg),
                    Text(title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(body, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    if (!rejected) ...[
                      TextField(
                        controller: _codeCtrl,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: s.accessCodeLabel,
                          counterText: '',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _redeeming ? null : _redeem,
                          child: _redeeming
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(s.activateCodeButton),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: _requesting ? null : _requestCode,
                        child: Text(s.requestCodeButton),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: widget.authService.signOut,
                      icon: const Icon(Icons.logout),
                      label: Text(s.signOut),
                    ),
                  ],
                ),
              ),
            ),
            const PositionedDirectional(
              top: 8,
              end: 8,
              child: LanguageToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
}
```

> Confirm `AppSpacing.xl` exists in `lib/theme/app_theme.dart`. If only `lg` exists, use `AppSpacing.lg` for the padding/spacers instead.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/auth/pending_screen.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/auth/pending_screen.dart
git commit -m "feat(auth): access-code redeem form on pending screen"
```

---

## Task 7: Admin issue-code action

**Files:**
- Modify: `lib/admin/admin_screen.dart`

- [ ] **Step 1: Add the clipboard import**

In `lib/admin/admin_screen.dart`, add after the `package:flutter/material.dart` import:

```dart
import 'package:flutter/services.dart';
```

- [ ] **Step 2: Add the issue-code method to `_UserTile`**

In `lib/admin/admin_screen.dart`, inside `_UserTile`, immediately AFTER the `_toggleRole` method (before `Widget build`), add:

```dart
  /// Issue (or reissue) an access code for a pending user, audit it, and show
  /// the value in a copyable dialog for out-of-band hand-off.
  Future<void> _issueCode(BuildContext context) async {
    final s = AppStrings.of(context);
    try {
      final code = await authService.issueAccessCode(
        uid: user.uid,
        email: user.email,
      );
      await authService.recordAudit(
        actorName: adminName,
        action: 'issue_code',
        targetUid: user.uid,
        targetName: user.name,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.issueCodeTitle),
          content: SelectableText(s.issueCodeBody(code)),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                showToast(context, s.codeCopied);
              },
              icon: const Icon(Icons.copy),
              label: Text(s.copyCode),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.cancel),
            ),
          ],
        ),
      );
    } on Exception {
      if (!context.mounted) return;
      showToast(context, s.issueCodeError);
    }
  }
```

- [ ] **Step 3: Add the issue-code button to the action `Wrap`**

In `lib/admin/admin_screen.dart`, inside the `Wrap`'s `children` list, immediately AFTER the approve button (`if (user.status != UserStatus.approved) TextButton.icon(... s.approve ...)`) and BEFORE the reject button, add:

```dart
                if (user.status == UserStatus.pending)
                  TextButton.icon(
                    onPressed: () => _issueCode(context),
                    icon: const Icon(Icons.vpn_key_outlined,
                        color: Color(0xFF2563EB)),
                    label: Text(s.issueCodeButton,
                        style: const TextStyle(color: Color(0xFF2563EB))),
                  ),
```

> `Color(0xFF2563EB)` matches the inline action-button colors already used in this file (the file predates the no-hardcoded-color convention; stay consistent with its siblings rather than introducing a lone themed button).

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/admin/admin_screen.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/admin_screen.dart
git commit -m "feat(admin): issue access code for pending users"
```

---

## Task 8: Full verification + deploy

**Files:** none (verification + deploy)

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: only the touched files reformatted (if any).

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Run all unit tests**

Run: `flutter test`
Expected: all pass (includes `test/auth/access_code_test.dart`).

Run: `cd cloudflare/guest-worker && node --test`
Expected: all pass.

- [ ] **Step 4: Build verification (structural change)**

Run: `flutter build apk --debug`
Expected: build succeeds.

- [ ] **Step 5: Deploy the rules**

Run: `firebase deploy --only database`
Expected: rules deployed. (Required before the Worker can read/write `access_codes` end-to-end, and before pending users can enqueue `code_request`.)

- [ ] **Step 6: Deploy the Worker**

Run: `cd cloudflare/guest-worker && wrangler deploy`
Expected: `door-gate` deployed.

- [ ] **Step 7: Manual end-to-end smoke (real devices)**

1. Register a new user → lands on the pending screen with a code field.
2. As admin, open Manage users → the new pending user shows an "Issue code" button → tap → dialog shows an 8-char code → copy it.
3. Back as the new user, type the code → "Activate" → routes to the gate screen within a second.
4. Re-enter the same code on a second pending account → toast "already used / invalid".
5. On a fresh pending account, tap "Request a code" → admins receive a `code_request` push.
6. Let a code sit > 24h (or temporarily lower `accessCodeTtl` in a throwaway build) → redeem → toast "expired".

- [ ] **Step 8: Release (only when shipping a build)**

Per CLAUDE.md release flow: bump `version: x.y.z+N` in `pubspec.yaml`, build/sign with the SAME key, upload the APK, then set `/app_config` `latestBuild=N` and `apkUrl`.

---

## Notes for the implementer

- **No DI / no state-management package** — the project uses plain `StatefulWidget` + `StreamBuilder`. Do not introduce one.
- **Relative imports** within `lib/` — match each file's existing style.
- **Guard `BuildContext` across `await`** with `if (!context.mounted) return;` / `if (!mounted) return;`.
- **`withOpacity` is deprecated** — use `.withValues(alpha: ...)` if you touch any color.
- **Done means:** `dart format .` clean, `flutter analyze` 0 issues, `flutter test` green, `flutter build apk --debug` passes.
- **Worker + rules both ship together** — a change to one without the other half-breaks the flow.
