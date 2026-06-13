import 'package:Door/auth/account_store.dart';
import 'package:Door/auth/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory SecureStore for tests (mirrors biometric_service_test).
class FakeSecureStore implements SecureStore {
  final Map<String, String> _data = {};
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

void main() {
  late AccountStore store;

  setUp(() => store = AccountStore(store: FakeSecureStore()));

  test('empty by default', () async {
    expect(await store.list(), isEmpty);
    expect(await store.credentials('a@x.com'), isNull);
  });

  test('remember adds an account and exposes credentials', () async {
    await store.remember(email: 'a@x.com', password: 'p1', name: 'Ali');
    final list = await store.list();
    expect(list, hasLength(1));
    expect(list.first.email, 'a@x.com');
    expect(list.first.name, 'Ali');
    final creds = await store.credentials('a@x.com');
    expect(creds?.password, 'p1');
  });

  test('list never leaks the password type', () async {
    await store.remember(email: 'a@x.com', password: 'secret', name: 'Ali');
    final list = await store.list();
    // SavedAccount has no password field — compile-time guarantee. Sanity check
    // the visible fields only.
    expect(list.first.email, 'a@x.com');
  });

  test('remember dedupes by lowercased email and updates password', () async {
    await store.remember(email: 'A@X.com', password: 'old', name: 'Ali');
    await store.remember(email: 'a@x.com', password: 'new', name: 'Ali');
    final list = await store.list();
    expect(list, hasLength(1));
    expect((await store.credentials('a@x.com'))?.password, 'new');
  });

  test('remember with empty name keeps the previous name', () async {
    await store.remember(email: 'a@x.com', password: 'p', name: 'Ali');
    await store.remember(email: 'a@x.com', password: 'p2', name: '');
    expect((await store.list()).first.name, 'Ali');
  });

  test('setName refreshes the display name', () async {
    await store.remember(email: 'a@x.com', password: 'p', name: 'Ali');
    await store.setName('a@x.com', 'Ali Hassan');
    expect((await store.list()).first.name, 'Ali Hassan');
  });

  test('setName is a no-op for unknown email', () async {
    await store.setName('ghost@x.com', 'Nobody');
    expect(await store.list(), isEmpty);
  });

  test('remove forgets the account', () async {
    await store.remember(email: 'a@x.com', password: 'p', name: 'Ali');
    await store.remember(email: 'b@x.com', password: 'q', name: 'Beh');
    await store.remove('a@x.com');
    final list = await store.list();
    expect(list, hasLength(1));
    expect(list.first.email, 'b@x.com');
    expect(await store.credentials('a@x.com'), isNull);
  });

  test('multiple accounts preserved across reads', () async {
    await store.remember(email: 'a@x.com', password: '1', name: 'A');
    await store.remember(email: 'b@x.com', password: '2', name: 'B');
    await store.remember(email: 'c@x.com', password: '3', name: 'C');
    expect(await store.list(), hasLength(3));
  });
}
