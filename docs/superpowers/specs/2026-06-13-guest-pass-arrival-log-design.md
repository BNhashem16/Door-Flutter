# Guest-pass Arrival Confirmation + Per-redemption Log — Design

**Date:** 2026-06-13
**Feature:** #7 — Guest-pass arrival confirmation + per-redemption log
**Status:** Approved design, pre-implementation

## Problem

The guest-pass redeem flow bumps `usedCount` and pushes the host an inline
"تم فتح بوابتك" notification on each redemption. But there is **no durable
per-visit history**: the host cannot review *when* each guest arrived. This
leaves "did my delivery actually come?" uncertainty unanswered after the push
is dismissed.

## Goal

Persist one record per successful redemption and surface that history to the
host inside the existing share view. The real-time alert (inline push +
notification center) already exists and is unchanged — this feature adds the
durable log and its UI.

## Scope decisions (confirmed)

- **Storage:** sibling subtree `/guest_redemptions/{ownerUid}/{passId}/{id}`,
  not embedded under the pass. Keeps the `watchPasses` list stream lean —
  history is read lazily only when the host opens a pass.
- **Entry data:** timestamp only (`at`, epoch ms). The visitor label already
  lives on the pass; feature #4 (visitor snapshot) is not built, so no snapshot
  field — YAGNI.
- **UI surface:** an "arrivals" section inside the existing
  `GuestPassShareView` bottom sheet (the pass tile already taps into it). No
  new screen.
- **No badge / unread tracking:** push covers real-time; the history list is
  review-only. No per-tile count (would add reads to the list hot path).

## Out of scope (YAGNI)

- Visitor snapshot / identity capture (feature #4 — not yet built).
- Admin-side aggregate redemption view.
- Retention / pruning of old entries.
- Per-pass unread badge or count on the pass list tile.

## Data model

New owner-scoped subtree, sibling to `/guest_passes`:

```
/guest_redemptions/{ownerUid}/{passId}/{pushId} = { "at": <epoch ms> }
```

- `pushId` is an RTDB push key (chronological).
- Written **only** by the redeem Worker (service-account auth, bypasses rules).
- New Dart model `GuestRedemption` in `lib/guest/guest_pass.dart`:
  immutable, hand-written `fromMap`/`toMap` (no code-gen, per project
  conventions), single field `final int at;`.

## Component changes

### 1. Cloudflare Worker — `cloudflare/guest-worker/src/index.js`

In `redeem()`, after the gate `PATCH` succeeds and the existing best-effort
`gate_logs/{u}` POST, add a second best-effort POST reusing the existing `ts`:

```js
await dbFetch(`guest_redemptions/${u}/${c}`, token, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ at: ts }),
}).catch(() => {});
```

- Non-blocking, never affects the redeem result (same pattern as `gate_logs`).
- Placed before the existing host `pushToUser` call (order irrelevant; both
  best-effort).
- **Requires `wrangler deploy` in `cloudflare/guest-worker/`.**

### 2. Security rules — `database.rules.json`

Add a new top-level block. Owner/admin **read**, **no client write** (the
Worker writes via service account, which bypasses rules):

```json
"guest_redemptions": {
  ".read": "auth != null && root.child('app_users').child(auth.uid).child('role').val() === 'admin'",
  "$uid": {
    ".read": "auth != null && (auth.uid === $uid || root.child('app_users').child(auth.uid).child('role').val() === 'admin')"
  }
}
```

- Absent `.write` ⇒ no authenticated client can forge or tamper with arrivals.
- Mirrors the read shape of `/guest_passes`.
- **Requires `firebase deploy --only database`.**
- Re-check after edit: no client write path, no privilege escalation.

### 3. Dart service — `lib/guest/guest_service.dart`

- Add `Stream<List<GuestRedemption>> watchRedemptions(String ownerUid, String passId)`
  reading `/guest_redemptions/{ownerUid}/{passId}`, mapping children to
  `GuestRedemption`, sorted newest-first (mirrors `watchPasses` shape and its
  empty-on-non-Map fallback).
- Extend cleanup so history doesn't orphan:
  - `delete(ownerUid, passId)` also removes `/guest_redemptions/{ownerUid}/{passId}`.
  - `deleteAll(ownerUid)` also removes `/guest_redemptions/{ownerUid}`.
  - `revoke` leaves history intact (the row stays auditable, same as the pass).

### 4. UI — `lib/guest/guest_pass_share_view.dart`

- Add an "arrivals" section below the existing share content (QR / link /
  copy-share / status), inside the same bottom sheet.
- Nested `StreamBuilder<List<GuestRedemption>>` on
  `service.watchRedemptions(ownerUid, pass.token)`.
- Renders: a header with the arrival count, then each entry's timestamp using
  the existing `_formatExpiry` date style.
- Empty state copy: «لم يصل أحد بعد».
- Styling strictly via `AppTheme` / `AppColors` / `AppSpacing` / `AppRadius`;
  no hardcoded colors or magic paddings. Reuse `SectionCard` if it fits.
- New Arabic strings added to `lib/l10n/app_strings.dart` (count label, empty
  state, section title) following the existing `AppStrings` pattern.

## Error handling

- Worker write is best-effort (`.catch(() => {})`) — a failure never breaks the
  redeem or the gate open.
- `watchRedemptions` falls back to an empty list on a non-`Map` snapshot
  (consistent with `watchPasses`); stream errors surface as the empty state.
- No new `BuildContext`-across-`await` paths (the UI is a pure `StreamBuilder`).

## Testing

- `flutter analyze` / Dart MCP `analyze_files` → 0 errors; `dart format .` clean.
- Manual verification: redeem a live pass via its link, confirm a new arrival
  row appears live in the host's share view and that the timestamp is correct
  (Africa/Cairo wall-clock matches the redeem moment).
- Confirm deleting a pass removes its arrival history (no orphaned subtree).
- Confirm a non-owner / unauthenticated client cannot read another owner's
  `/guest_redemptions/{uid}` and cannot write any entry.

## Deployment checklist

1. Ship Dart changes (model, service, UI, strings) — analyzer clean.
2. `firebase deploy --only database` (new `guest_redemptions` rule).
3. `wrangler deploy` in `cloudflare/guest-worker/` (redeem now logs arrivals).

Rules + Worker must both deploy for the feature to work end-to-end.
