import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'guest_pass.dart';
import 'guest_service.dart';
import 'guest_status_chip.dart';

/// Share surface for a created/selected pass: QR + redeem link + Copy/Share +
/// live status. Status updates live from the owner's pass stream so a revoke
/// or expiry reflects here immediately.
class GuestPassShareView extends StatelessWidget {
  const GuestPassShareView({
    super.key,
    required this.service,
    required this.ownerUid,
    required this.pass,
  });

  final GuestService service;
  final String ownerUid;
  final GuestPass pass;

  static Future<void> show(
    BuildContext context, {
    required GuestService service,
    required String ownerUid,
    required GuestPass pass,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => GuestPassShareView(
        service: service,
        ownerUid: ownerUid,
        pass: pass,
      ),
    );
  }

  String get _url =>
      GuestService.redeemUrl(ownerUid: ownerUid, token: pass.token);

  String _formatExpiry(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    // Keep the live pass (status/usedCount) fresh from the stream; fall back to
    // the snapshot passed in for the first frame.
    return StreamBuilder<List<GuestPass>>(
      stream: service.watchPasses(ownerUid),
      builder: (context, snap) {
        var live = pass;
        for (final p in snap.data ?? const <GuestPass>[]) {
          if (p.token == pass.token) {
            live = p;
            break;
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(s.guestShareTitle, style: theme.textTheme.titleLarge),
                  const Spacer(),
                  GuestStatusChip(live),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child:
                    Text(s.guestShareHint, style: theme.textTheme.labelMedium),
              ),
              const SizedBox(height: AppSpacing.lg),

              // QR on a white plate so it scans in either theme.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: QrImageView(
                  data: _url,
                  size: 200,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF111827),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                live.label.isEmpty ? s.guestPassesTitle : live.label,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                s.guestValidUntil(_formatExpiry(live.expiresAt)),
                style: theme.textTheme.labelMedium,
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: AppSpacing.md),

              // The link itself (truncated), tappable to copy.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Text(
                  _url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(context, s),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(s.guestCopyLink),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _share(context, s, live),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(s.guestShare),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copy(BuildContext context, AppStrings s) async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.guestLinkCopied)),
    );
  }

  Future<void> _share(
      BuildContext context, AppStrings s, GuestPass live) async {
    await SharePlus.instance.share(
      ShareParams(text: s.guestShareMessage(live.label, _url)),
    );
  }
}
