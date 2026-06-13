/// Remote update descriptor stored at `/app_config` in RTDB.
///
/// - [latestBuild]: newest published Android versionCode. Builds below it get
///   a dismissible "update available" prompt.
/// - [minBuild]: lowest versionCode still allowed. Builds below it are hard
///   blocked behind [ForceUpdateScreen] until they update.
/// - [apkUrl]: direct download link for the new APK.
/// - [notes]: optional Arabic release notes shown in the prompt.
class UpdateInfo {
  const UpdateInfo({
    required this.latestBuild,
    required this.minBuild,
    required this.apkUrl,
    this.notes,
  });

  final int latestBuild;
  final int minBuild;
  final String apkUrl;
  final String? notes;

  static UpdateInfo? fromMap(Map<Object?, Object?> map) {
    final latest = (map['latestBuild'] as num?)?.toInt();
    final apkUrl = map['apkUrl'] as String?;
    if (latest == null || apkUrl == null || apkUrl.isEmpty) return null;
    return UpdateInfo(
      latestBuild: latest,
      minBuild: (map['minBuild'] as num?)?.toInt() ?? 0,
      apkUrl: apkUrl,
      notes: map['notes'] as String?,
    );
  }
}
