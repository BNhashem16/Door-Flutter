# Admin Gate-Activity Monitor — Design

**Date:** 2026-06-17
**Status:** Approved

## Goal

Admin-controlled on/off feature. When ON, every gate **open/close** (from any
source: app, widget, guest) pushes **all admins** a clear Arabic notification so
they can monitor the building. The actor's own action does not alert themselves.

Decisions (confirmed with user):

- Delivery: **FCM push + in-app history** (notification center).
- Events: **open and close**.
- Self actions: **excluded** — an admin is not alerted about their own action.
- Recipients: **all admins** (`role === 'admin'`).

## Architecture

Chosen: **Worker cron scans `/gate_logs`.**

All gate actions already write `/gate_logs/{uid}/{logId}` from every source
(app via `AuthService.logGateAction`, widget via `GateService.logAction` REST,
guest via the redeem Worker). The existing Worker cron (every ~1 min) gains a
second pass that scans new logs and pushes admins. Latency ≤ ~1 min, matching the
existing push-outbox design.

Rejected alternative: client enqueues a `push_outbox` entry on toggle. It would
miss the widget and guest paths and would require loosening the admin-only
`push_outbox` write rule. The cron-scan approach catches every source with no
client toggle-path change and no security-rule change.

## Components

### 1. Toggle — `/app_config/gateAlerts` (bool)

- `/app_config` rule already: `.read:true`, `.write:admin`,
  `.validate: newData.hasChildren(['latestBuild','apkUrl'])`.
- The toggle is written as a **child** path (`/app_config/gateAlerts`). A child
  write does not trigger the parent `.validate` (validate does not cascade up),
  so **no rule change** is required.
- `AuthService`:
  - `Stream<bool> watchGateAlerts()` — streams `/app_config/gateAlerts`,
    defaulting to `false` when missing/non-bool.
  - `Future<void> setGateAlerts(bool enabled)` — `update({'gateAlerts': enabled})`
    on `/app_config`.

### 2. Admin UI

- `SwitchListTile` inside a `SectionCard` near the top of `admin_screen`,
  AppTheme-styled, Arabic:
  - title: `مراقبة البوابة`
  - subtitle: `إشعار لكل المسؤولين عند كل فتح أو إغلاق للباب`
- Bound to `watchGateAlerts()` (via `StreamBuilder`) and `setGateAlerts()`.
- Errors → `ToastService`.

### 3. Worker — `scanGateActivity(env, token)`

Called from `scheduled()` after `drainPushOutbox`. Best-effort, wrapped in
try/catch — must never throw (cron hot path).

Cursor node: `/gate_alert_cursor` (epoch ms). Service-account write bypasses
rules; no client touches it.

Logic:

1. `enabled = (read /app_config/gateAlerts) === true`.
2. If `!enabled` → set cursor = `Date.now()`, return.
   *(Keeps the cursor ≈ now while disabled so re-enabling never floods history.)*
3. `cursor = read /gate_alert_cursor`. If missing → set cursor = `Date.now()`,
   return (don't blast pre-existing logs on first enable).
4. Read `/gate_logs`, flatten to `{actorUid, log}` pairs, keep
   `log.timestamp > cursor`, sort ascending, cap to the newest 50.
5. If none → return (cursor unchanged).
6. `admins = adminUids(token)`. For each new log, push every admin **except**
   the one whose uid `=== actorUid`, with type `gate_activity`.
7. Advance cursor = max processed `timestamp`.

### 4. Copy (Arabic, explicit) — Worker-owned, keyed by action

- open → title `🚪 تم فتح البوابة`, body `{name} فتح البوابة • {source}`
- close → title `🔒 تم إغلاق البوابة`, body `{name} أغلق البوابة • {source}`
- `name` falls back to `مستخدم` when empty.
- `source`: `app → عبر التطبيق`, `widget → عبر الأداة`, `guest → تصريح ضيف`,
  unknown → omitted.

### 5. Notification plumbing (reuse)

`pushToUser(env, token, adminUid, title, body, 'gate_activity')` already:

- persists to `/notifications/{adminUid}` (history + bell badge), and
- fans the FCM push to every device token, pruning dead ones.

`gate_activity` is **not** added to `_ALWAYS_SEND`; it honours the per-type pref
(default allowed). The master toggle is the real on/off. Add a `gate_activity`
icon/label to the app's `AppNotification` rendering so history entries render
cleanly instead of a default fallback.

## Deploy

- `wrangler deploy` in `cloudflare/guest-worker/` (Worker change).
- **No** `firebase deploy --only database` — no rule change.

## Out of scope (YAGNI)

Per-admin granularity, quiet hours, a dedicated entry in `NotificationPrefsScreen`
(the master toggle already governs this).

## Verification

- `flutter analyze` clean, `dart format .`.
- Build: `flutter build apk --debug` (admin screen + AuthService touched).
- Manual: toggle on → open gate from a second account → admin receives push +
  history entry within ~1 min; actor admin does not self-alert; toggle off →
  no alerts, and re-enabling does not replay history.
