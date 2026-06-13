import '../auth/auth_service.dart';

/// Pure, Flutter-free helpers for the admin user list: text + status filtering
/// and grouping residents by apartment. Kept separate from the widgets so the
/// logic is unit-testable and the UI files stay thin.

/// Sentinel key for residents with no apartment set. The UI maps this key to a
/// localized "unspecified" label.
const String kUnspecifiedUnit = '';

/// Filter [users] by a free-text [query] and an optional [status].
///
/// [query] matches name OR email OR apartment, case-insensitive substring; an
/// empty/whitespace query does not filter by text. A null [status] means "all
/// statuses". Order is preserved from the input.
List<AppUser> filterUsers(
  List<AppUser> users, {
  String query = '',
  UserStatus? status,
}) {
  final q = query.trim().toLowerCase();
  return users.where((u) {
    if (status != null && u.status != status) return false;
    if (q.isEmpty) return true;
    return u.name.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        u.apartment.toLowerCase().contains(q);
  }).toList();
}

/// Group [users] by apartment, returning entries sorted numeric-aware by unit
/// (so "2" precedes "10"). The blank-apartment bucket (key [kUnspecifiedUnit])
/// always sorts last. Residents within each unit are sorted by name.
List<MapEntry<String, List<AppUser>>> groupByUnit(List<AppUser> users) {
  final map = <String, List<AppUser>>{};
  for (final u in users) {
    final unit = u.apartment.trim();
    map.putIfAbsent(unit, () => <AppUser>[]).add(u);
  }
  for (final list in map.values) {
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  return map.entries.toList()..sort((a, b) => _compareUnit(a.key, b.key));
}

/// Compare two apartment keys: numeric units ascending, then non-numeric labels
/// alphabetically, with the blank bucket always last.
int _compareUnit(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 0;
  if (a.isEmpty) return 1;
  if (b.isEmpty) return -1;
  final na = int.tryParse(a);
  final nb = int.tryParse(b);
  if (na != null && nb != null) return na.compareTo(nb);
  if (na != null) return -1; // numeric units sort before alphabetic labels
  if (nb != null) return 1;
  return a.toLowerCase().compareTo(b.toLowerCase());
}
