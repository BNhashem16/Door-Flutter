import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/auth_service.dart';
import 'update_info.dart';

/// Streams the published update descriptor from `/app_config` and reads this
/// install's own Android versionCode. `/app_config` is world-readable (rule)
/// so the gate works before login; writes are admin-only.
class UpdateService {
  DatabaseReference get _ref => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: AuthService.databaseUrl,
      ).ref('app_config');

  Stream<UpdateInfo?> watch() => _ref.onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return null;
        return UpdateInfo.fromMap(Map<Object?, Object?>.from(value));
      });

  /// This install's versionCode (the `+N` in pubspec `version: x.y.z+N`).
  static Future<int> currentBuild() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }
}
