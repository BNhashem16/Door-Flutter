# Guest-pass Arrival Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist one timestamped record per successful guest-pass redemption and show that arrival history to the host inside the existing share view.

**Architecture:** The redeem Cloudflare Worker writes a best-effort entry to a new owner-scoped RTDB subtree `/guest_redemptions/{ownerUid}/{passId}/{pushId} = {at}` on each successful redeem. A new Dart model + `GuestService.watchRedemptions` stream feeds an "arrivals" section nested in `GuestPassShareView`. Security rules grant owner/admin read and no client write (the Worker writes via service account, bypassing rules). Pass deletion cascades into the redemption subtree.

**Tech Stack:** Flutter 3.38 / Dart 3.10 · firebase_database ^12 · Cloudflare Worker (vanilla JS, `wrangler`) · Firebase RTDB security rules.

**Spec:** `docs/superpowers/specs/2026-06-13-guest-pass-arrival-log-design.md`

---

## File Structure

- **Create** `lib/guest/guest_redemption.dart` — immutable `GuestRedemption` model (`at` epoch ms), hand-written `fromMap`/`toMap`.
- **Create** `test/guest_redemption_test.dart` — model round-trip + fallback unit tests.
- **Modify** `lib/guest/guest_service.dart` — add `watchRedemptions`, cascade `delete`/`deleteAll`.
- **Modify** `lib/l10n/app_strings.dart` — 3 new strings in the abstract class + `_Ar` + `_En`.
- **Modify** `lib/guest/guest_pass_share_view.dart` — nested arrivals `StreamBuilder` section.
- **Modify** `database.rules.json` — new `guest_redemptions` read-only block.
- **Modify** `cloudflare/guest-worker/src/index.js` — best-effort redemption write inside `redeem()`.

Order: model → strings → service → UI → rules → worker. Dart first (compiles + tests green), then the two deploy-gated changes (rules, worker) last.

---

### Task 1: `GuestRedemption` model

**Files:**
- Create: `lib/guest/guest_redemption.dart`
- Test: `test/guest_redemption_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/guest_redemption_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:Door/guest/guest_redemption.dart';

void main() {
  group('GuestRedemption', () {
    test('fromMap reads at', () {
      final r = GuestRedemption.fromMap('push1', const {'at': 1700000000000});
      expect(r.id, 'push1');
      expect(r.at, 1700000000000);
    });

    test('fromMap defaults at to 0 when missing', () {
      final r = GuestRedemption.fromMap('push2', const {});
      expect(r.at, 0);
    });

    test('toMap round-trips at', () {
      const r = GuestRedemption(id: 'push3', at: 42);
      expect(r.toMap(), {'at': 42});
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/guest_redemption_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:Door/guest/guest_redemption.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/guest/guest_redemption.dart`:

```dart
/// One guest-pass redemption (a visitor arrival).
///
/// Stored under `/guest_redemptions/{ownerUid}/{passId}/{pushId}` in the
/// Realtime Database, written only by the redeem Worker (service-account auth).
/// Hand-written `fromMap`/`toMap` — no code-gen, per project conventions.
library;

/// Immutable record of a single successful redemption.
class GuestRedemption {
  const GuestRedemption({required this.id, required this.at});

  /// RTDB push key for this entry.
  final String id;

  /// Epoch ms the redemption was committed (Worker `ts`).
  final int at;

  factory GuestRedemption.fromMap(String id, Map<dynamic, dynamic> map) {
    return GuestRedemption(id: id, at: (map['at'] ?? 0) as int);
  }

  Map<String, Object?> toMap() => {'at': at};
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/guest_redemption_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format + analyze**

Run: `dart format lib/guest/guest_redemption.dart test/guest_redemption_test.dart`
Run: `flutter analyze lib/guest/guest_redemption.dart test/guest_redemption_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/guest/guest_redemption.dart test/guest_redemption_test.dart
git commit -m "feat: GuestRedemption model for per-pass arrival log"
```

---

### Task 2: Arrival strings (AR + EN)

**Files:**
- Modify: `lib/l10n/app_strings.dart` (abstract class `AppStrings`, `_Ar`, `_En`)

Three strings: a section title, an empty-state line, a count formatter.

- [ ] **Step 1: Add abstract declarations**

In the abstract `AppStrings` class, immediately after the line `String get guestPassesCountLabel;`, add:

```dart
  String get guestArrivalsTitle;
  String get guestArrivalsEmpty;
  String guestArrivalsCount(int n);
```

- [ ] **Step 2: Add Arabic implementations**

In `class _Ar implements AppStrings`, immediately after its `String get guestPassesCountLabel => 'تصاريح الزوار';` line, add:

```dart
  @override
  String get guestArrivalsTitle => 'سجل الوصول';
  @override
  String get guestArrivalsEmpty => 'لم يصل أحد بعد';
  @override
  String guestArrivalsCount(int n) => 'عدد مرات الوصول: $n';
```

- [ ] **Step 3: Add English implementations**

In `class _En implements AppStrings`, immediately after its `String get guestPassesCountLabel => 'Guest passes';` line, add:

```dart
  @override
  String get guestArrivalsTitle => 'Arrivals';
  @override
  String get guestArrivalsEmpty => 'No arrivals yet';
  @override
  String guestArrivalsCount(int n) => '$n arrivals';
```

> Note: existing `_Ar`/`_En` members may or may not use explicit `@override`. Match the surrounding lines in each class — if neighbours omit `@override`, omit it here too. The analyzer (Step 4) will confirm.

- [ ] **Step 4: Format + analyze**

Run: `dart format lib/l10n/app_strings.dart`
Run: `flutter analyze lib/l10n/app_strings.dart`
Expected: No issues found. (If analyzer reports `_Ar`/`_En` missing a member, a declaration/impl is out of sync — fix the mismatch.)

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat: arrival-log strings (AR/EN)"
```

---

### Task 3: `watchRedemptions` + delete cascade in `GuestService`

**Files:**
- Modify: `lib/guest/guest_service.dart`

- [ ] **Step 1: Add the redemption import**

At the top of `lib/guest/guest_service.dart`, alongside `import 'guest_pass.dart';`, add:

```dart
import 'guest_redemption.dart';
```

- [ ] **Step 2: Add a ref helper + watch stream**

Immediately after the existing `DatabaseReference _ownerRef(String ownerUid) => _db.ref('guest_passes/$ownerUid');` method, add:

```dart
  DatabaseReference _redemptionsRef(String ownerUid) =>
      _db.ref('guest_redemptions/$ownerUid');

  /// Live arrival history for one pass, newest first. Empty when the Worker has
  /// logged nothing yet (or on a non-Map snapshot, mirroring [watchPasses]).
  Stream<List<GuestRedemption>> watchRedemptions(
      String ownerUid, String passId) {
    return _redemptionsRef(ownerUid).child(passId).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <GuestRedemption>[];
      return value.entries
          .where((e) => e.value is Map)
          .map((e) =>
              GuestRedemption.fromMap(e.key as String, e.value as Map))
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
    });
  }
```

- [ ] **Step 3: Cascade `delete` into the redemption subtree**

Replace the existing one-line `delete` method:

```dart
  /// Permanently remove a pass row.
  Future<void> delete(String ownerUid, String passId) =>
      _ownerRef(ownerUid).child(passId).remove();
```

with:

```dart
  /// Permanently remove a pass row and its arrival history.
  Future<void> delete(String ownerUid, String passId) async {
    await _ownerRef(ownerUid).child(passId).remove();
    await _redemptionsRef(ownerUid).child(passId).remove();
  }
```

- [ ] **Step 4: Cascade `deleteAll` into the redemption subtree**

Replace the existing `deleteAll` method:

```dart
  /// Permanently remove ALL of [ownerUid]'s passes in one write. Every shared
  /// link stops working immediately (the Worker finds no pass row).
  Future<void> deleteAll(String ownerUid) => _ownerRef(ownerUid).remove();
```

with:

```dart
  /// Permanently remove ALL of [ownerUid]'s passes and arrival history. Every
  /// shared link stops working immediately (the Worker finds no pass row).
  Future<void> deleteAll(String ownerUid) async {
    await _ownerRef(ownerUid).remove();
    await _redemptionsRef(ownerUid).remove();
  }
```

- [ ] **Step 5: Format + analyze**

Run: `dart format lib/guest/guest_service.dart`
Run: `flutter analyze lib/guest/guest_service.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/guest/guest_service.dart
git commit -m "feat: watchRedemptions stream + delete cascade in GuestService"
```

---

### Task 4: Arrivals section in `GuestPassShareView`

**Files:**
- Modify: `lib/guest/guest_pass_share_view.dart`

The widget is a `StatelessWidget` returning a single outer `StreamBuilder<List<GuestPass>>`. Add a self-contained arrivals section widget and render it at the bottom of the existing `Column`.

- [ ] **Step 1: Import the model**

Add to the imports (next to `import 'guest_pass.dart';`):

```dart
import 'guest_redemption.dart';
```

- [ ] **Step 2: Render the arrivals section in the Column**

In `build`, the outer Column ends with the `Row(...)` of Copy/Share buttons, then `],` closing the Column `children`. Immediately after that `Row(...)` (before the `],` that closes `children`), add:

```dart
              const SizedBox(height: AppSpacing.lg),
              _Arrivals(service: service, ownerUid: ownerUid, passId: pass.token),
```

- [ ] **Step 3: Add the `_Arrivals` widget**

At the end of the file (after the closing brace of `GuestPassShareView`), add a private widget. It uses `AppColors`/`AppSpacing` only, formats each timestamp with the same convention as the view's existing `_formatExpiry`, and shows the empty state when there are no arrivals:

```dart
/// Live arrival history for the pass: a count header + newest-first timestamps.
/// Empty until the redeem Worker logs the first visit.
class _Arrivals extends StatelessWidget {
  const _Arrivals({
    required this.service,
    required this.ownerUid,
    required this.passId,
  });

  final GuestService service;
  final String ownerUid;
  final String passId;

  String _formatAt(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final colors = theme.extension<AppColors>()!;

    return StreamBuilder<List<GuestRedemption>>(
      stream: service.watchRedemptions(ownerUid, passId),
      builder: (context, snap) {
        final arrivals = snap.data ?? const <GuestRedemption>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.login_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(s.guestArrivalsTitle,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (arrivals.isNotEmpty)
                  Text(s.guestArrivalsCount(arrivals.length),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: colors.muted)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (arrivals.isEmpty)
              Text(s.guestArrivalsEmpty,
                  style:
                      theme.textTheme.labelMedium?.copyWith(color: colors.muted))
            else
              ...arrivals.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: colors.success),
                      const SizedBox(width: AppSpacing.sm),
                      Text(_formatAt(a.at),
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

> `colors.success` and `colors.muted` are existing `AppColors` members (used elsewhere in the guest UI, e.g. `_PassTile` uses `colors.danger`; `_Empty` uses `colors.muted`). If the analyzer reports `success` is undefined, substitute `theme.colorScheme.primary` and note it.

- [ ] **Step 4: Format + analyze**

Run: `dart format lib/guest/guest_pass_share_view.dart`
Run: `flutter analyze lib/guest/guest_pass_share_view.dart`
Expected: No issues found.

- [ ] **Step 5: Build verification (UI/structural change)**

Run: `flutter build apk --debug`
Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add lib/guest/guest_pass_share_view.dart
git commit -m "feat: arrival history section in guest pass share view"
```

---

### Task 5: Security rule for `guest_redemptions`

**Files:**
- Modify: `database.rules.json`

Owner/admin read, no client write. Mirrors the `/guest_passes` read shape.

- [ ] **Step 1: Add the rule block**

In `database.rules.json`, locate the existing `"guest_passes": { ... }` block (under top-level `"rules"`). Immediately after its closing brace and comma, add a sibling block:

```json
    "guest_redemptions": {
      ".read": "auth != null && root.child('app_users').child(auth.uid).child('role').val() === 'admin'",
      "$uid": {
        ".read": "auth != null && (auth.uid === $uid || root.child('app_users').child(auth.uid).child('role').val() === 'admin')"
      }
    },
```

Ensure surrounding commas are valid JSON (the new block needs a trailing comma if another sibling key follows it, none if it is the last key before the `rules` closing brace).

- [ ] **Step 2: Validate JSON**

Run: `python -c "import json; json.load(open('database.rules.json')); print('valid')"`
Expected: `valid`.

- [ ] **Step 3: Security re-check (manual)**

Confirm by reading the block:
- No `.write` anywhere under `guest_redemptions` → no authenticated client can create/modify/forge an arrival (Worker writes via service account, which bypasses rules).
- `$uid` read is owner-or-admin only → no resident can read another resident's arrival history.
- No privilege-escalation path opened.

- [ ] **Step 4: Commit**

```bash
git add database.rules.json
git commit -m "feat: guest_redemptions read-only security rule"
```

- [ ] **Step 5: Deploy (gated — see deployment checklist)**

Run: `firebase deploy --only database`
Expected: `Deploy complete!`. Do this as part of the deploy step, not before the Dart UI ships.

---

### Task 6: Worker logs each redemption

**Files:**
- Modify: `cloudflare/guest-worker/src/index.js`

Inside `redeem()`, the success path (after the `if (!putRes.ok) return 'error';` ETag commit) opens the gate, then does a best-effort `gate_logs/${u}` POST, then `pushToUser`. Add the redemption write between the `gate_logs` POST and the `pushToUser` call, reusing the existing `ts`.

- [ ] **Step 1: Add the redemption write**

Find this existing block in `redeem()`:

```js
    await dbFetch(`gate_logs/${u}`, token, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: label,
        action: 'open',
        source: 'guest',
        timestamp: ts,
      }),
    }).catch(() => {});
```

Immediately after it (before the `// Notify the host ...` comment / `await pushToUser(...)` call), add:

```js
    // Per-pass arrival log so the host can review who/when (feature #7). The
    // visitor label already lives on the pass — store only the timestamp.
    // Best-effort: a failure must never break the redeem.
    await dbFetch(`guest_redemptions/${u}/${c}`, token, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ at: ts }),
    }).catch(() => {});
```

- [ ] **Step 2: Syntax check**

Run: `node --check cloudflare/guest-worker/src/index.js`
Expected: no output (exit 0).

- [ ] **Step 3: Commit**

```bash
git add cloudflare/guest-worker/src/index.js
git commit -m "feat: log guest-pass redemptions to guest_redemptions (worker)"
```

- [ ] **Step 4: Deploy (gated — see deployment checklist)**

Run: `cd cloudflare/guest-worker && wrangler deploy`
Expected: `Uploaded` + `Deployed`. The Worker now logs arrivals on each redeem.

---

## Deployment Checklist (run after all Dart tasks are merged + analyzer clean)

Both the rule and the Worker must deploy for the feature to work end-to-end:

1. `firebase deploy --only database` — publishes the `guest_redemptions` read rule.
2. `cd cloudflare/guest-worker && wrangler deploy` — redeem now logs arrivals.

---

## Manual Verification (after deploy)

- [ ] Open a live pass in the host app → share view shows «لم يصل أحد بعد» (empty arrivals).
- [ ] Redeem the pass via its link in a browser → gate opens, success page shows.
- [ ] Without reloading, the host's open share view shows a new arrival row with the correct Africa/Cairo-local timestamp, and the count header reads `1`.
- [ ] Redeem again (if uses remain) → a second row appears, newest first.
- [ ] Delete the pass → confirm `/guest_redemptions/{uid}/{passId}` is gone (no orphan) via the Firebase console.
- [ ] (Security) In the Firebase console rules playground: a non-owner authed read of `/guest_redemptions/{otherUid}` is denied; any client write to `/guest_redemptions/...` is denied.

---

## Self-Review

**Spec coverage:**
- Data model `/guest_redemptions/{ownerUid}/{passId}/{id}={at}` → Tasks 1, 3, 6. ✓
- Worker best-effort write reusing `ts` → Task 6. ✓
- Read-only rule (owner/admin read, no client write) → Task 5. ✓
- `watchRedemptions` + delete/deleteAll cascade → Task 3. ✓
- Arrivals section in share view, count + timestamps + empty state, AppTheme styling → Tasks 2, 4. ✓
- Best-effort error handling / empty-list fallback → Tasks 3 (stream), 6 (`.catch`). ✓
- Deploy gating (firebase + wrangler) → Deployment Checklist, Tasks 5/6 deploy steps. ✓
- Out of scope (snapshot, admin aggregate, pruning, badge) → not implemented. ✓

**Type consistency:** `GuestRedemption(id, at)` + `fromMap(id, map)` + `toMap()` defined in Task 1; consumed identically in Task 3 (`GuestRedemption.fromMap`) and Task 4 (`a.at`). Stream type `Stream<List<GuestRedemption>>` matches between Task 3 (service) and Task 4 (`_Arrivals`). String members `guestArrivalsTitle` / `guestArrivalsEmpty` / `guestArrivalsCount(int)` defined in Task 2, used in Task 4. Path `guest_redemptions/{u}/{c}` (Worker, Task 6) == `guest_redemptions/$ownerUid` child `passId` (service, Task 3), since `passId == token == c`. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; flagged the two `AppColors` member assumptions (`success`/`muted`) with concrete fallbacks. ✓
