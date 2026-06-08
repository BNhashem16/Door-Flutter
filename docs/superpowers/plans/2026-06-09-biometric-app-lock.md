# Biometric App Lock + Saved Credentials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fingerprint app-open lock over the authenticated UI plus secure saved credentials (fallback unlock + login pre-fill).

**Architecture:** A top-level `AppLock` widget wraps `AuthGate` in `main.dart`, owns lifecycle observation, and renders a `LockScreen` over its child when locked. A single `BiometricService` is the boundary over `local_auth`, `flutter_secure_storage`, and `shared_preferences`; the password store is abstracted behind `SecureStore` so logic is unit-testable with an in-memory fake. Firebase session is never re-authenticated — the lock is a UI gate only.

**Tech Stack:** Flutter 3.38 / Dart 3.10, `local_auth`, `flutter_secure_storage`, `shared_preferences`, `firebase_auth`, hand-written `AppStrings` l10n.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/auth/secure_store.dart` (create) | `SecureStore` interface + `FlutterSecureStore` impl wrapping `flutter_secure_storage`. |
| `lib/auth/biometric_service.dart` (create) | Enabled flag, timeout logic, credential round-trip, biometric prompt. Boundary over plugins. |
| `lib/auth/lock_screen.dart` (create) | Lock UI: fingerprint + password fallback + sign-out escape. |
| `lib/auth/app_lock.dart` (create) | Lifecycle observer, locked-state owner, wraps `AuthGate`. |
| `lib/auth/biometric_toggle_tile.dart` (create) | Stateful `SwitchListTile` for the profile screen (enable/disable flow). |
| `lib/auth/auth_service.dart` (modify) | Add `reauthenticate(password)`. |
| `lib/auth/login_screen.dart` (modify) | Pre-fill email+password from saved creds. |
| `lib/profile/profile_screen.dart` (modify) | Mount `BiometricToggleTile`. |
| `lib/main.dart` (modify) | Wrap `AuthGate` with `AppLock`. |
| `lib/l10n/app_strings.dart` (modify) | New AR/EN keys. |
| `android/.../MainActivity.kt` (modify) | Extend `FlutterFragmentActivity` (local_auth requirement). |
| `android/app/src/main/AndroidManifest.xml` (modify) | `USE_BIOMETRIC` permission. |
| `ios/Runner/Info.plist` (modify) | `NSFaceIDUsageDescription`. |
| `test/biometric_service_test.dart` (create) | Unit tests: enabled flag, timeout boundary, credential round-trip. |
| `test/lock_screen_test.dart` (create) | Widget test: password fallback unlocks. |

---

## Task 1: Add dependencies

**Files:**
- Modify: `pubspec.yaml:24` (after `home_widget: ^0.9.3`)

- [ ] **Step 1: Add the two packages**

Run:
```bash
flutter pub add local_auth flutter_secure_storage
```
Expected: `pubspec.yaml` gains `local_auth` and `flutter_secure_storage` under `dependencies`; `flutter pub get` runs clean.

- [ ] **Step 2: Verify resolution**

Run: `flutter pub get`
Expected: "Got dependencies!" with no version conflicts.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add local_auth + flutter_secure_storage deps"
```

---

## Task 2: Android + iOS platform setup

`local_auth` on Android requires the host Activity to extend `FlutterFragmentActivity`, the `USE_BIOMETRIC` permission, and on iOS a Face ID usage description.

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/project/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Read MainActivity to confirm current base class**

Run: open `android/app/src/main/kotlin/com/example/project/MainActivity.kt`
Expected: it currently extends `FlutterActivity`.

- [ ] **Step 2: Change MainActivity to FlutterFragmentActivity**

Replace the file body with:
```kotlin
package com.example.project

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

- [ ] **Step 3: Add the biometric permission**

In `android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` above the `<application>` tag:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

- [ ] **Step 4: Add the iOS Face ID usage description**

In `ios/Runner/Info.plist`, add inside the top-level `<dict>`:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to unlock the app.</string>
```

- [ ] **Step 5: Verify Android build still compiles**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL (confirms the FragmentActivity swap is valid).

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/example/project/MainActivity.kt android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore: platform config for local_auth (FragmentActivity, biometric permission, Face ID)"
```

---

## Task 3: SecureStore abstraction

A thin interface so `BiometricService` can be unit-tested with an in-memory fake instead of the platform Keychain.

**Files:**
- Create: `lib/auth/secure_store.dart`

- [ ] **Step 1: Write the interface + default impl**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value secure storage boundary. Lets [BiometricService] be unit
/// tested with an in-memory fake instead of the platform Keychain.
abstract interface class SecureStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// Production implementation backed by the OS secure store
/// (Keychain on iOS, EncryptedSharedPreferences on Android).
class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore([this._storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  )]);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/auth/secure_store.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/auth/secure_store.dart
git commit -m "feat: add SecureStore abstraction over flutter_secure_storage"
```

---

## Task 4: BiometricService — enabled flag (TDD)

**Files:**
- Create: `lib/auth/biometric_service.dart`
- Test: `test/biometric_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:Door/auth/biometric_service.dart';
import 'package:Door/auth/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory SecureStore for tests.
class FakeSecureStore implements SecureStore {
  final Map<String, String> _data = {};
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

BiometricService _build() => BiometricService(
      store: FakeSecureStore(),
      localAuth: LocalAuthentication(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('enabled flag', () {
    test('defaults to false', () async {
      expect(await _build().isEnabled(), isFalse);
    });

    test('persists after setEnabled(true)', () async {
      final svc = _build();
      await svc.setEnabled(true);
      expect(await svc.isEnabled(), isTrue);
    });

    test('setEnabled(false) clears it', () async {
      final svc = _build();
      await svc.setEnabled(true);
      await svc.setEnabled(false);
      expect(await svc.isEnabled(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/biometric_service_test.dart`
Expected: FAIL — `BiometricService` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_store.dart';

/// Boundary over biometric auth + secure credential storage. Widgets talk to
/// this, never to the plugins directly (mirrors the AuthService convention).
class BiometricService {
  BiometricService({
    SecureStore store = const FlutterSecureStore(),
    LocalAuthentication? localAuth,
  })  : _store = store,
        _localAuth = localAuth ?? LocalAuthentication();

  final SecureStore _store;
  final LocalAuthentication _localAuth;

  /// How long the app may sit in the background before it re-locks on resume.
  static const lockTimeout = Duration(seconds: 60);

  static const _kEnabled = 'biometric_enabled';
  static const _kBackgroundedAt = 'biometric_backgrounded_at';
  static const _kEmail = 'biometric_email';
  static const _kPassword = 'biometric_password';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/biometric_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/auth/biometric_service.dart test/biometric_service_test.dart
git commit -m "feat: BiometricService enabled flag"
```

---

## Task 5: BiometricService — timeout logic (TDD)

**Files:**
- Modify: `lib/auth/biometric_service.dart`
- Test: `test/biometric_service_test.dart`

- [ ] **Step 1: Add the failing tests**

Add this group inside the existing `main()`:
```dart
  group('lock timeout', () {
    test('not timed out when never backgrounded', () async {
      expect(await _build().lockTimedOut(), isFalse);
    });

    test('not timed out at 59s', () async {
      final svc = _build();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      await svc.markBackgrounded(t0);
      final at59 = t0.add(const Duration(seconds: 59));
      expect(await svc.lockTimedOut(at59), isFalse);
    });

    test('timed out at 61s', () async {
      final svc = _build();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      await svc.markBackgrounded(t0);
      final at61 = t0.add(const Duration(seconds: 61));
      expect(await svc.lockTimedOut(at61), isTrue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/biometric_service_test.dart`
Expected: FAIL — `markBackgrounded` / `lockTimedOut` not defined.

- [ ] **Step 3: Add the implementation**

Add these methods to `BiometricService`:
```dart
  /// Stamp the moment the app went to background. [now] is injectable for tests.
  Future<void> markBackgrounded([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kBackgroundedAt,
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// True if the app has been backgrounded longer than [lockTimeout].
  /// Returns false when there is no recorded background time.
  Future<bool> lockTimedOut([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final stamp = prefs.getInt(_kBackgroundedAt);
    if (stamp == null) return false;
    final elapsed = (now ?? DateTime.now()).millisecondsSinceEpoch - stamp;
    return elapsed > lockTimeout.inMilliseconds;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/biometric_service_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/auth/biometric_service.dart test/biometric_service_test.dart
git commit -m "feat: BiometricService background timeout logic"
```

---

## Task 6: BiometricService — credential round-trip (TDD)

**Files:**
- Modify: `lib/auth/biometric_service.dart`
- Test: `test/biometric_service_test.dart`

- [ ] **Step 1: Add the failing tests**

Add this group inside `main()`:
```dart
  group('credentials', () {
    test('readCredentials is null before saving', () async {
      expect(await _build().readCredentials(), isNull);
    });

    test('round-trips email and password', () async {
      final svc = _build();
      await svc.saveCredentials('a@b.com', 'secret123');
      final creds = await svc.readCredentials();
      expect(creds?.email, 'a@b.com');
      expect(creds?.password, 'secret123');
    });

    test('clearCredentials removes them', () async {
      final svc = _build();
      await svc.saveCredentials('a@b.com', 'secret123');
      await svc.clearCredentials();
      expect(await svc.readCredentials(), isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/biometric_service_test.dart`
Expected: FAIL — `saveCredentials` not defined.

- [ ] **Step 3: Add the implementation**

Add to `BiometricService`:
```dart
  Future<void> saveCredentials(String email, String password) async {
    await _store.write(_kEmail, email);
    await _store.write(_kPassword, password);
  }

  Future<({String email, String password})?> readCredentials() async {
    final email = await _store.read(_kEmail);
    final password = await _store.read(_kPassword);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  Future<void> clearCredentials() async {
    await _store.delete(_kEmail);
    await _store.delete(_kPassword);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/biometric_service_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/auth/biometric_service.dart test/biometric_service_test.dart
git commit -m "feat: BiometricService secure credential round-trip"
```

---

## Task 7: BiometricService — biometric prompt pass-throughs

Thin wrappers over `local_auth`. Not unit-tested (plugin boundary); verified at runtime.

**Files:**
- Modify: `lib/auth/biometric_service.dart`

- [ ] **Step 1: Add the methods**

Add to `BiometricService`:
```dart
  /// Device has biometric hardware AND at least one fingerprint/face enrolled.
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } on Exception {
      return false;
    }
  }

  /// Shows the OS biometric prompt. Returns true only on a successful scan.
  Future<bool> authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on Exception {
      return false;
    }
  }
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/auth/biometric_service.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/auth/biometric_service.dart
git commit -m "feat: BiometricService canUseBiometrics + authenticate"
```

---

## Task 8: AuthService.reauthenticate

Lets the profile enable-flow verify the current password against Firebase before storing it.

**Files:**
- Modify: `lib/auth/auth_service.dart` (add after `signIn`, around line 170)

- [ ] **Step 1: Add the method**

Insert into `AuthService`:
```dart
  /// Verify the current user's password against Firebase. Throws a
  /// [FirebaseAuthException] (`wrong-password`/`invalid-credential`) on mismatch.
  /// Used to confirm identity before saving credentials for biometric unlock.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
  }
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/auth/auth_service.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/auth/auth_service.dart
git commit -m "feat: AuthService.reauthenticate for credential verification"
```

---

## Task 9: AppStrings — new keys

**Files:**
- Modify: `lib/l10n/app_strings.dart`

- [ ] **Step 1: Declare the abstract getters**

In the abstract `AppStrings` class, after `String get editProfile;` (line 113), add:
```dart

  // Biometric lock
  String get biometricLockLabel;
  String get biometricLockSubtitle;
  String get biometricUnavailable;
  String get biometricEnableScanReason;
  String get biometricUnlockReason;
  String get lockTitle;
  String get unlockWithFingerprint;
  String get usePasswordInstead;
  String get wrongPassword;
  String get enableBiometricPasswordPrompt;
  String get confirm;
```

- [ ] **Step 2: Implement in `_Ar`**

In `_Ar`, after `String get editProfile => 'تعديل الملف';` (line 288), add:
```dart

  @override
  String get biometricLockLabel => 'قفل البصمة';
  @override
  String get biometricLockSubtitle => 'افتح التطبيق ببصمتك';
  @override
  String get biometricUnavailable => 'لا توجد بصمة مسجّلة على هذا الجهاز';
  @override
  String get biometricEnableScanReason => 'أكّد بصمتك لتفعيل القفل';
  @override
  String get biometricUnlockReason => 'افتح التطبيق ببصمتك';
  @override
  String get lockTitle => 'التطبيق مقفول';
  @override
  String get unlockWithFingerprint => 'افتح بالبصمة';
  @override
  String get usePasswordInstead => 'استخدم كلمة المرور';
  @override
  String get wrongPassword => 'كلمة المرور غير صحيحة';
  @override
  String get enableBiometricPasswordPrompt => 'أدخل كلمة المرور لتفعيل القفل';
  @override
  String get confirm => 'تأكيد';
```

- [ ] **Step 3: Implement in `_En`**

In `_En`, after `String get editProfile => 'Edit profile';` (line 487), add:
```dart

  @override
  String get biometricLockLabel => 'Fingerprint lock';
  @override
  String get biometricLockSubtitle => 'Unlock the app with your fingerprint';
  @override
  String get biometricUnavailable => 'No fingerprint enrolled on this device';
  @override
  String get biometricEnableScanReason => 'Confirm your fingerprint to enable the lock';
  @override
  String get biometricUnlockReason => 'Unlock the app with your fingerprint';
  @override
  String get lockTitle => 'App locked';
  @override
  String get unlockWithFingerprint => 'Unlock with fingerprint';
  @override
  String get usePasswordInstead => 'Use password instead';
  @override
  String get wrongPassword => 'Incorrect password';
  @override
  String get enableBiometricPasswordPrompt => 'Enter your password to enable the lock';
  @override
  String get confirm => 'Confirm';
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/l10n/app_strings.dart`
Expected: No issues found (both `_Ar` and `_En` implement every new getter).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat: add biometric lock localization keys (ar/en)"
```

---

## Task 10: LockScreen (TDD widget)

**Files:**
- Create: `lib/auth/lock_screen.dart`
- Test: `test/lock_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:Door/auth/biometric_service.dart';
import 'package:Door/auth/lock_screen.dart';
import 'package:Door/auth/secure_store.dart';
import 'package:Door/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSecureStore implements SecureStore {
  final Map<String, String> _data = {};
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('password fallback unlocks on matching password',
      (tester) async {
    final svc = BiometricService(
      store: FakeSecureStore(),
      localAuth: LocalAuthentication(),
    );
    await svc.saveCredentials('a@b.com', 'secret123');
    var unlocked = false;

    await tester.pumpWidget(_wrap(LockScreen(
      service: svc,
      onUnlocked: () => unlocked = true,
      onSignOut: () {},
      autoPrompt: false,
    )));
    await tester.pumpAndSettle();

    // Reveal the password field.
    await tester.tap(find.text('Use password instead'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
  });

  testWidgets('wrong password keeps it locked', (tester) async {
    final svc = BiometricService(
      store: FakeSecureStore(),
      localAuth: LocalAuthentication(),
    );
    await svc.saveCredentials('a@b.com', 'secret123');
    var unlocked = false;

    await tester.pumpWidget(_wrap(LockScreen(
      service: svc,
      onUnlocked: () => unlocked = true,
      onSignOut: () {},
      autoPrompt: false,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use password instead'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrongpass');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(unlocked, isFalse);
    expect(find.text('Incorrect password'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/lock_screen_test.dart`
Expected: FAIL — `LockScreen` not defined.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'biometric_service.dart';

/// Full-screen lock shown over the authenticated UI. Unlocks via fingerprint
/// or the saved password fallback.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.service,
    required this.onUnlocked,
    required this.onSignOut,
    this.autoPrompt = true,
  });

  final BiometricService service;
  final VoidCallback onUnlocked;
  final VoidCallback onSignOut;

  /// Auto-trigger the fingerprint prompt on first build. Disabled in tests.
  final bool autoPrompt;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = AppStrings.of(context);
    final ok = await widget.service.authenticate(s.biometricUnlockReason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlocked();
  }

  Future<void> _submitPassword() async {
    final creds = await widget.service.readCredentials();
    if (!mounted) return;
    if (creds != null && _passwordCtrl.text == creds.password) {
      widget.onUnlocked();
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(s.lockTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(s.unlockWithFingerprint),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!_showPassword)
                  TextButton(
                    onPressed: () => setState(() => _showPassword = true),
                    child: Text(s.usePasswordInstead),
                  ),
                if (_showPassword) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) {
                      if (_error) setState(() => _error = false);
                    },
                    onSubmitted: (_) => _submitPassword(),
                    decoration: InputDecoration(
                      labelText: s.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: _error ? s.wrongPassword : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitPassword,
                      child: Text(s.confirm),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: widget.onSignOut,
                  child: Text(s.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/lock_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/auth/lock_screen.dart test/lock_screen_test.dart
git commit -m "feat: LockScreen with fingerprint + password fallback"
```

---

## Task 11: AppLock lifecycle wrapper

**Files:**
- Create: `lib/auth/app_lock.dart`

- [ ] **Step 1: Write the implementation**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'biometric_service.dart';
import 'lock_screen.dart';

/// Wraps the app and enforces the biometric app-open lock. The lock is active
/// only when biometric is enabled AND a user is signed in, so the login screen
/// is never locked. The [child] stays mounted under the lock so Firebase
/// streams keep warm.
class AppLock extends StatefulWidget {
  const AppLock({
    super.key,
    required this.child,
    required this.authService,
    BiometricService? biometricService,
  }) : biometricService = biometricService ?? const _DefaultService();

  final Widget child;
  final AuthService authService;
  final BiometricService biometricService;

  @override
  State<AppLock> createState() => _AppLockState();
}

/// Placeholder so the const constructor stays valid; replaced in initState.
class _DefaultService implements BiometricService {
  const _DefaultService();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('AppLock must build its own BiometricService');
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  late final BiometricService _bio = widget.biometricService is _DefaultService
      ? BiometricService()
      : widget.biometricService;

  bool _locked = false;

  bool get _signedIn => widget.authService.currentUser != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybeLockOnStart();
  }

  Future<void> _maybeLockOnStart() async {
    if (_signedIn && await _bio.isEnabled()) {
      if (mounted) setState(() => _locked = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bio.markBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _maybeLockOnResume();
    }
  }

  Future<void> _maybeLockOnResume() async {
    if (_locked) return;
    if (_signedIn && await _bio.isEnabled() && await _bio.lockTimedOut()) {
      if (mounted) setState(() => _locked = true);
    }
  }

  void _unlock() {
    if (mounted) setState(() => _locked = false);
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
    _unlock();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          LockScreen(
            service: _bio,
            onUnlocked: _unlock,
            onSignOut: _signOut,
          ),
      ],
    );
  }
}
```

> **Note:** the `_DefaultService` placeholder keeps the constructor `const`-friendly while letting the State build a real `BiometricService`. If the analyzer dislikes the `noSuchMethod` placeholder, simplify by making `biometricService` nullable (`this.biometricService`) and dropping `_DefaultService`; then `_bio = widget.biometricService ?? BiometricService()`.

- [ ] **Step 2: Analyze — apply the nullable fallback if needed**

Run: `flutter analyze lib/auth/app_lock.dart`
Expected: No issues. If the placeholder trips a lint, switch to the nullable form described in the note:
```dart
  const AppLock({
    super.key,
    required this.child,
    required this.authService,
    this.biometricService,
  });

  final Widget child;
  final AuthService authService;
  final BiometricService? biometricService;
```
and `late final BiometricService _bio = widget.biometricService ?? BiometricService();`

- [ ] **Step 3: Commit**

```bash
git add lib/auth/app_lock.dart
git commit -m "feat: AppLock lifecycle wrapper enforcing biometric lock"
```

---

## Task 12: Wire AppLock into main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Import AppLock and a shared AuthService**

At the top of `lib/main.dart` add (after the existing `auth_service.dart` import):
```dart
import './auth/app_lock.dart';
```

- [ ] **Step 2: Wrap AuthGate**

In `_MyAppState`, add a field:
```dart
  final _authService = AuthService();
```
Then change the `home:` of `MaterialApp` from:
```dart
      home: AuthGate(
        onThemeToggle: _toggleTheme,
        isDarkMode: _isDarkMode,
        onLocaleToggle: _toggleLocale,
      ),
```
to:
```dart
      home: AppLock(
        authService: _authService,
        child: AuthGate(
          onThemeToggle: _toggleTheme,
          isDarkMode: _isDarkMode,
          onLocaleToggle: _toggleLocale,
        ),
      ),
```

> `AuthGate` keeps creating its own internal `AuthService` (unchanged) — both point at the same Firebase singletons, so sharing the instance is not required for correctness. `AppLock` only needs `currentUser` + `signOut`.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/main.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wrap AuthGate with AppLock"
```

---

## Task 13: Profile biometric toggle tile

**Files:**
- Create: `lib/auth/biometric_toggle_tile.dart`
- Modify: `lib/profile/profile_screen.dart`

- [ ] **Step 1: Write the toggle tile**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../toast/toast_service.dart';
import 'auth_service.dart';
import 'biometric_service.dart';

/// SwitchListTile that enables/disables the biometric app-open lock.
///
/// Enabling verifies the account password via Firebase reauth before storing
/// it, then confirms with a fingerprint scan. Disabling wipes saved credentials.
class BiometricToggleTile extends StatefulWidget {
  const BiometricToggleTile({super.key, required this.authService});

  final AuthService authService;

  @override
  State<BiometricToggleTile> createState() => _BiometricToggleTileState();
}

class _BiometricToggleTileState extends State<BiometricToggleTile> {
  final _bio = BiometricService();
  bool _enabled = false;
  bool _available = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await _bio.canUseBiometrics();
    final enabled = await _bio.isEnabled();
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
      });
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;
    if (value) {
      await _enable();
    } else {
      await _disable();
    }
  }

  Future<void> _enable() async {
    final s = AppStrings.of(context);
    final password = await _askPassword(s.enableBiometricPasswordPrompt);
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.authService.reauthenticate(password);
      final scanned = await _bio.authenticate(s.biometricEnableScanReason);
      if (!scanned) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final email = widget.authService.currentUser?.email ?? '';
      await _bio.saveCredentials(email, password);
      await _bio.setEnabled(true);
      if (mounted) setState(() => _enabled = true);
    } on FirebaseAuthException {
      if (mounted) ToastService.show(s.wrongPassword);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    await _bio.clearCredentials();
    await _bio.setEnabled(false);
    if (mounted) {
      setState(() {
        _enabled = false;
        _busy = false;
      });
    }
  }

  Future<String?> _askPassword(String title) {
    final ctrl = TextEditingController();
    final s = AppStrings.of(context);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          textDirection: TextDirection.ltr,
          autofocus: true,
          decoration: InputDecoration(labelText: s.password),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SwitchListTile(
      value: _enabled,
      onChanged: (_available && !_busy) ? _onChanged : null,
      secondary: const Icon(Icons.fingerprint),
      title: Text(s.biometricLockLabel),
      subtitle: Text(
        _available ? s.biometricLockSubtitle : s.biometricUnavailable,
      ),
    );
  }
}
```

> **Toast check:** confirm `ToastService.show` is the correct call signature by opening `lib/toast/toast_service.dart`. If the method differs (e.g. `ToastService.error`), use that instead.

- [ ] **Step 2: Verify the ToastService API**

Run: open `lib/toast/toast_service.dart`
Expected: confirm the static method name/signature; adjust the `ToastService.show(...)` call in step 1 to match.

- [ ] **Step 3: Mount the tile in the profile screen**

In `lib/profile/profile_screen.dart`, add the import:
```dart
import '../auth/biometric_toggle_tile.dart';
```
Then in `_Body.build`, insert after the `SectionCard` (the `apartment`/`bio` card, ends ~line 98) and before the trailing `SizedBox(height: AppSpacing.lg)` that precedes the edit button:
```dart
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            child: BiometricToggleTile(authService: authService),
          ),
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/auth/biometric_toggle_tile.dart lib/profile/profile_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/auth/biometric_toggle_tile.dart lib/profile/profile_screen.dart
git commit -m "feat: biometric lock toggle in profile screen"
```

---

## Task 14: Login pre-fill from saved credentials

**Files:**
- Modify: `lib/auth/login_screen.dart`

- [ ] **Step 1: Add the BiometricService field + prefill in initState**

In `_LoginScreenState`, add after the controller declarations (line ~20):
```dart
  final _bio = BiometricService();
```
Add an `initState` (the class currently has none) after the field declarations:
```dart
  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final creds = await _bio.readCredentials();
    if (creds == null || !mounted) return;
    if (_emailCtrl.text.isEmpty) _emailCtrl.text = creds.email;
    if (_passwordCtrl.text.isEmpty) _passwordCtrl.text = creds.password;
  }
```

- [ ] **Step 2: Add the import**

At the top of `lib/auth/login_screen.dart`, after `import 'auth_service.dart';`:
```dart
import 'biometric_service.dart';
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/auth/login_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/auth/login_screen.dart
git commit -m "feat: pre-fill login form from saved credentials"
```

---

## Task 15: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the whole test suite**

Run: `flutter test`
Expected: All tests pass (existing localization tests + 9 biometric_service + 2 lock_screen).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Format**

Run: `dart format .`
Expected: formatting applied / already formatted.

- [ ] **Step 4: Build the debug APK**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Manual smoke test (device/emulator with enrolled fingerprint)**

1. Sign in, go to profile, enable "Fingerprint lock" (enter password → scan).
2. Kill the app, relaunch → lock screen appears → fingerprint unlocks.
3. Background >60s, resume → lock re-appears; <60s resume → no lock.
4. On lock screen tap "Use password instead" → wrong password shows error, correct unlocks.
5. Sign out → saved credentials retained → login form pre-filled.
6. Disable toggle → relaunch → no lock.

- [ ] **Step 6: Commit any format changes**

```bash
git add -A
git commit -m "chore: format + final verification for biometric lock"
```

---

## Spec Coverage Check

| Spec requirement | Task |
|------------------|------|
| App-open lock, session untouched | 11, 12 |
| Saved password (secure storage only) | 3, 6 |
| Fallback unlock | 10 |
| Login pre-fill | 14 |
| Cold start + 60s resume timeout | 5, 11 |
| Settings toggle, off by default, reauth-verified | 4, 8, 13 |
| Logout keeps creds | 11 (`_signOut` does not clear) |
| local_auth + flutter_secure_storage deps | 1, 2 |
| AR/EN strings | 9 |
| Unit + widget tests | 4, 5, 6, 10 |
