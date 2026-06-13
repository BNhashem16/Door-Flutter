import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../toast/toast_service.dart';
import 'force_update_screen.dart';
import 'update_info.dart';
import 'update_service.dart';

/// Version gate wrapped around the whole app (above onboarding and auth).
///
/// Compares this install's versionCode against `/app_config`:
/// - below `minBuild`  → hard block: [ForceUpdateScreen].
/// - below `latestBuild` → one dismissible update dialog per app launch.
/// - `/app_config` missing or unreadable → app runs normally (fail open).
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  final _service = UpdateService();
  late final Stream<UpdateInfo?> _stream = _service.watch();
  int? _build;
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    UpdateService.currentBuild().then((b) {
      if (mounted) setState(() => _build = b);
    });
  }

  Future<void> _showSoftPrompt(UpdateInfo info) async {
    final s = AppStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.updateAvailableTitle),
        content: Text(
          info.notes == null || info.notes!.isEmpty
              ? s.updateAvailableBody
              : '${s.updateAvailableBody}\n\n${info.notes}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(s.updateLaterButton),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final uri = Uri.tryParse(info.apkUrl);
              final ok = uri != null &&
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!mounted || !context.mounted) return;
              if (!ok) showToast(context, s.updateOpenFailed);
            },
            child: Text(s.updateDownloadButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final build = _build;
    if (build == null) return widget.child;

    return StreamBuilder<UpdateInfo?>(
      stream: _stream,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return widget.child;
        if (build < info.minBuild) return ForceUpdateScreen(info: info);
        if (build < info.latestBuild && !_promptShown) {
          _promptShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showSoftPrompt(info);
          });
        }
        return widget.child;
      },
    );
  }
}
