import 'package:Door/admin/admin_user_filter.dart';
import 'package:Door/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({
  String uid = 'u',
  String name = 'Name',
  String email = 'a@b.com',
  String apartment = '',
  UserStatus status = UserStatus.approved,
}) {
  return AppUser(
    uid: uid,
    email: email,
    name: name,
    role: UserRole.user,
    status: status,
    createdAt: 0,
    apartment: apartment,
  );
}

void main() {
  group('filterUsers', () {
    final users = [
      _user(
          uid: '1',
          name: 'Ahmed Salah',
          email: 'ahmed@x.com',
          apartment: '12',
          status: UserStatus.approved),
      _user(
          uid: '2',
          name: 'Mona Ali',
          email: 'mona@y.com',
          apartment: '3',
          status: UserStatus.pending),
      _user(
          uid: '3',
          name: 'Omar',
          email: 'omar@z.com',
          apartment: '12',
          status: UserStatus.rejected),
    ];

    test('empty query + null status returns all', () {
      expect(filterUsers(users).length, 3);
    });

    test('matches by name, case-insensitive', () {
      final r = filterUsers(users, query: 'ahmed');
      expect(r.map((u) => u.uid), ['1']);
    });

    test('matches by email', () {
      final r = filterUsers(users, query: 'mona@y');
      expect(r.map((u) => u.uid), ['2']);
    });

    test('matches by apartment', () {
      final r = filterUsers(users, query: '12');
      expect(r.map((u) => u.uid), ['1', '3']);
    });

    test('filters by status', () {
      final r = filterUsers(users, status: UserStatus.pending);
      expect(r.map((u) => u.uid), ['2']);
    });

    test('combines query and status', () {
      final r = filterUsers(users, query: '12', status: UserStatus.rejected);
      expect(r.map((u) => u.uid), ['3']);
    });

    test('whitespace-only query does not filter', () {
      expect(filterUsers(users, query: '   ').length, 3);
    });

    test('no match returns empty', () {
      expect(filterUsers(users, query: 'zzz'), isEmpty);
    });
  });

  group('groupByUnit', () {
    test('groups, sorts units numeric-aware, blank bucket last', () {
      final users = [
        _user(uid: '1', name: 'B', apartment: '10'),
        _user(uid: '2', name: 'A', apartment: '2'),
        _user(uid: '3', name: 'C', apartment: ''),
        _user(uid: '4', name: 'D', apartment: '2'),
      ];
      final groups = groupByUnit(users);
      expect(groups.map((e) => e.key), ['2', '10', kUnspecifiedUnit]);
      // Unit "2" residents sorted by name: A (uid 2) before D (uid 4).
      expect(groups.first.value.map((u) => u.uid), ['2', '4']);
    });

    test('blank and whitespace apartments share the unspecified bucket', () {
      final users = [
        _user(uid: '1', apartment: ''),
        _user(uid: '2', apartment: '   '),
      ];
      final groups = groupByUnit(users);
      expect(groups.length, 1);
      expect(groups.single.key, kUnspecifiedUnit);
      expect(groups.single.value.length, 2);
    });

    test('non-numeric labels sort after numeric units, before blank', () {
      final users = [
        _user(uid: '1', name: 'x', apartment: 'Villa'),
        _user(uid: '2', name: 'y', apartment: '5'),
        _user(uid: '3', name: 'z', apartment: ''),
      ];
      final groups = groupByUnit(users);
      expect(groups.map((e) => e.key), ['5', 'Villa', kUnspecifiedUnit]);
    });
  });
}
