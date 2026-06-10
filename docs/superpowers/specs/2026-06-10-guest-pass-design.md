# Guest Pass — Design Spec

**Date:** 2026-06-10
**Status:** Approved (design) — pending implementation plan
**Feature:** Temporary guest access. An approved resident generates a time-limited
code/QR for a visitor; the visitor opens the gate from a web link without an account.

---

## 1. Problem & goals

A building resident wants to let a visitor through the gate without being present
or handing over their own login. The gate is controlled only by an RTDB write
(`state:ON`) — there is no physical keypad or scanner — so redemption must happen
in software.

**Goals**
- Resident self-serves a pass for their own visitor (no admin in the loop).
- Visitor opens the gate with **zero app install** and **no account**.
- Pass is time-limited, optionally use-limited, labelled, and revocable.
- The gate device token is never exposed to the visitor.
- Every guest open is logged and attributed to the issuing resident.

**Non-goals (YAGNI)** — see §10.

---

## 2. Chosen approach

| Decision | Choice |
|----------|--------|
| Redemption channel | **Web link** served by an HTTP Cloud Function |
| Pass options | Validity **window** + optional **max-uses** + **label** + **revoke** |
| QR | Yes (`qr_flutter`) |
| Sharing | System share sheet (`share_plus`) |
| Who can issue | **Any approved user** |

Rejected alternatives: in-app visitor redemption (forces app install + anonymous
auth, weaker UX); Firebase Hosting static page + callable (callable-from-browser
needs the Firebase JS SDK + App Check — more moving parts than one `onRequest`).

---

## 3. End-to-end flow

1. Resident (approved) opens **تصاريح الزوار** from the gate screen, taps **+**,
   sets label + duration + max-opens, confirms.
2. App generates a `Random.secure()` token and writes **one** RTDB record to
   `/guest_passes/{ownerUid}/{token}`.
3. App shows a share view: **QR** + redeem URL + Copy/Share + live status.
   Resident sends the link via WhatsApp/SMS.
4. Visitor opens the link in any browser → themed Arabic page: label,
   "صالح حتى …", and a large **افتح البوابة** button (or a reason it is invalid).
5. Tapping the button POSTs to the same function. Server-side (Admin SDK):
   re-validate → atomic `usedCount` bump (transaction, double-spend safe) →
   write `state:ON` to the gate node → push a gate log → render success.

---

## 4. Data model — `/guest_passes/{ownerUid}/{passId}`

`passId == token`. Stored under `ownerUid` to mirror the existing
`/gate_logs/{uid}` ownership pattern (keeps the security rules trivial).

```json
{
  "token":         "<passId, redundant copy for reads>",
  "label":         "أخويا",
  "createdBy":     "<ownerUid>",
  "createdByName": "محمد",
  "createdAt":     1749500000000,
  "expiresAt":     1749510000000,
  "maxUses":       1,
  "usedCount":     0,
  "status":        "active"
}
```

- `maxUses: 0` ⇒ unlimited opens within the window.
- `status`: `active` | `revoked`.
- `createdByName` / `label` are **denormalized** so logs and the admin view stay
  readable even after a profile edit.

**Derived (not stored):**
- `expired  = now > expiresAt`
- `usedUp   = maxUses > 0 && usedCount >= maxUses`
- `valid    = status == active && !expired && !usedUp`

**Redeem URL** (owner uid is not sensitive):
```
https://us-central1-project-5203370022845167706.cloudfunctions.net/guestPass?u=<ownerUid>&c=<token>
```

---

## 5. Cloud Function `guestPass` (functions/index.js)

Firebase Functions **v2 `onRequest`**, region `us-central1`, Admin SDK (bypasses
RTDB rules — same pattern as the OTP callables). Self-contained: renders the page
**and** processes the open.

- **GET** `?u&c` → read `/guest_passes/{u}/{c}`. Render HTML:
  - valid → label, `expiresAt` (formatted), uses-left, **Open** form (POST).
  - invalid → Arabic reason: `expired` / `revoked` / `used_up` / `not_found`.
- **POST** (Open) →
  1. `runTransaction` on the pass: abort unless still `valid`; else `usedCount++`.
  2. On commit, write the gate node `state:ON` (plus the existing
     `apikey/changedby/name/type/timestamp` fields GateService writes).
  3. Push `/gate_logs/{ownerUid}`: `{ action:'open', source:'guest',
     name:label, timestamp: ServerValue.timestamp }`.
  4. Render success (تم فتح البوابة) or a failure reason.
- Pure helpers (`passIsValid`, `usesLeft`, token-format check) exported under
  `_internal` for jest, mirroring the OTP helpers.

The gate node path and device write shape are the ones already defined in
`lib/gate/gate_service.dart` (`users/1BEy97EhEObAeP7U6s4CFM66IPr2/devices/D`).

---

## 6. Security rules — `database.rules.json`

Add a `guest_passes` node following the `gate_logs` shape:

```json
"guest_passes": {
  ".read": "auth != null && root.child('app_users').child(auth.uid).child('role').val() === 'admin'",
  "$uid": {
    ".read":  "auth != null && (auth.uid === $uid || root.child('app_users').child(auth.uid).child('role').val() === 'admin')",
    ".write": "auth != null && (auth.uid === $uid || root.child('app_users').child(auth.uid).child('role').val() === 'admin')",
    "$passId": {
      ".validate": "newData.hasChildren(['token','createdBy','expiresAt','status'])"
    }
  }
}
```

- Owner reads/writes only their own subtree; admin can read all (oversight).
- Redemption + `usedCount` increment happen in the function via the Admin SDK, so
  no public read/write rule is needed for visitors.
- A resident editing their own pass counters is **not** a privilege escalation —
  they already control the gate directly. Acceptable, keeps rules simple.

Deploy: `firebase deploy --only database`.

---

## 7. Flutter — resident side (`lib/guest/`)

New feature folder, plain `StatefulWidget` + `StreamBuilder`, no state-mgmt pkg.

| File | Purpose |
|------|---------|
| `guest_pass.dart` | Immutable model, hand-written `fromMap`/`toMap`, derived getters (`expired`/`usedUp`/`valid`). No code-gen. |
| `guest_service.dart` | Focused RTDB wrapper: `createPass(...)`, `watchPasses(uid)`, `revoke(uid, passId)`. Follows the **GateService** precedent (dedicated service, not `AuthService` bloat). |
| `guest_passes_screen.dart` | Live list of the resident's passes with `StatusBadge`; **+** to create; per-row Share / QR / Revoke. |
| `create_guest_pass_sheet.dart` | Label field; duration presets (1h / 3h / حتى الليل / مخصص); max-opens (مرة واحدة / 5 / غير محدود). |
| `guest_pass_share_view.dart` | QR (`qr_flutter`) + URL + Copy/Share (`share_plus`) + live status. |

- **Entry point:** a "تصاريح الزوار" action/card on `FirebaseUpdateScreen`,
  visible to approved users.
- **Styling:** only `AppTheme` / `AppColors` / `AppSpacing` / `AppRadius`; reuse
  `SectionCard`, `StatusBadge`. Arabic-first; both light/dark verified.
- **Strings:** add to `AppStrings` (ar + en), matching the existing l10n pattern.
- **Token:** `Random.secure()` → base32, ~50 bits. `passId = token`.

**CLAUDE.md:** add one line documenting `GuestService` as a second
service-layer exception alongside `GateService`.

---

## 8. New dependencies

- `qr_flutter` — pure-Dart QR painter (QR display).
- `share_plus` — system share sheet (WhatsApp/SMS).

`cloud_functions` is already present but **not** needed here: pass creation is a
direct RTDB write, and redemption is the public web function called by the browser,
not the app.

---

## 9. Testing

- **functions/test (jest):** `passIsValid` / `usesLeft` / token-format across
  expiry, revoked, used-up, unlimited, and boundary cases. Mirrors `otp.test.js`.
- **Dart unit:** `GuestPass` map round-trip + derived status; `GuestService`
  against a fake `FirebaseDatabase`.
- **Widget:** `create_guest_pass_sheet` validation (empty label, non-future
  duration), and `guest_passes_screen` rendering of active/expired/revoked rows.

---

## 10. Out of scope (YAGNI)

- QR **scanning** — visitor uses the link; no kiosk/scanner.
- FCM "your guest just opened the gate" push — easy follow-up since
  `firebase_messaging` is already wired; not in MVP.
- Hosting pretty-URL rewrite — the raw function URL is acceptable.
- Guest **close** action — open-only; the motor gate auto-closes.
- Per-pass passwords / PIN on top of the token.

---

## 11. Open risks

- **Function URL aesthetics:** `…cloudfunctions.net/guestPass?u=…&c=…` is long.
  Acceptable for MVP; a Hosting rewrite to `/g` is a later polish.
- **Clock skew:** expiry is server-evaluated (`Date.now()` in the function), not
  the visitor's device — correct by construction.
- **Token in URL history:** the redeem link is bearer-capability. Mitigated by
  expiry + max-uses + revoke. Document that residents should share it privately.
