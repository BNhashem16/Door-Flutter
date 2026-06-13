import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import 'create_guest_pass_sheet.dart';
import 'guest_pass.dart';
import 'guest_pass_share_view.dart';
import 'guest_service.dart';
import 'guest_status_chip.dart';

/// Resident's guest passes: live list + create + per-row share/revoke.
class GuestPassesScreen extends StatefulWidget {
  const GuestPassesScreen({
    super.key,
    required this.authService,
    required this.userName,
  });

  final AuthService authService;
  final String userName;

  @override
  State<GuestPassesScreen> createState() => _GuestPassesScreenState();
}

class _GuestPassesScreenState extends State<GuestPassesScreen> {
  final GuestService _service = GuestService();

  String get _uid => widget.authService.currentUser?.uid ?? '';

  Future<void> _create() async {
    final pass = await CreateGuestPassSheet.show(
      context,
      service: _service,
      ownerUid: _uid,
      createdByName: widget.userName,
    );
    if (pass == null || !mounted) return;
    await GuestPassShareView.show(
      context,
      service: _service,
      ownerUid: _uid,
      pass: pass,
    );
  }

  Future<void> _share(GuestPass pass) => GuestPassShareView.show(
        context,
        service: _service,
        ownerUid: _uid,
        pass: pass,
      );

  Future<void> _revoke(GuestPass pass) async {
    final s = AppStrings.of(context);
    final confirmed = await _confirm(
      title: s.guestRevokeTitle,
      message: s.guestRevokeConfirm(pass.label),
      action: s.guestRevoke,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _service.revoke(_uid, pass.id), s.guestRevoked);
  }

  Future<void> _delete(GuestPass pass) async {
    final s = AppStrings.of(context);
    final label = pass.label.isEmpty ? s.guestPassesTitle : pass.label;
    final confirmed = await _confirm(
      title: s.guestDeleteTitle,
      message: s.guestDeleteConfirm(label),
      action: s.delete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _service.delete(_uid, pass.id), s.guestDeleted);
  }

  Future<void> _deleteAll() async {
    final s = AppStrings.of(context);
    final confirmed = await _confirm(
      title: s.guestDeleteAllTitle,
      message: s.guestDeleteAllConfirm,
      action: s.guestDeleteAll,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _service.deleteAll(_uid), s.guestAllDeleted);
  }

  /// Shared confirm dialog; destructive actions get the danger accent.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final colors = Theme.of(context).extension<AppColors>()!;
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: colors.danger)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Runs a service write, then shows a success or error snackbar.
  Future<void> _run(Future<void> Function() write, String successMsg) async {
    final s = AppStrings.of(context);
    try {
      await write();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } catch (_) {
      if (!mounted) return;
      final colors = Theme.of(context).extension<AppColors>()!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.saveChangesError),
          backgroundColor: colors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return StreamBuilder<List<GuestPass>>(
      stream: _service.watchPasses(_uid),
      builder: (context, snap) {
        final passes = snap.data ?? const <GuestPass>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(s.guestPassesTitle),
            actions: [
              if (passes.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: s.guestDeleteAll,
                  onPressed: _deleteAll,
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
            label: Text(s.newGuestPass),
          ),
          body: Builder(
            builder: (context) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text(s.guestPassLoadError));
              }
              if (passes.isEmpty) {
                return _Empty(onCreate: _create);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                itemCount: passes.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _PassTile(
                  pass: passes[i],
                  onShare: () => _share(passes[i]),
                  onRevoke: () => _revoke(passes[i]),
                  onDelete: () => _delete(passes[i]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PassTile extends StatelessWidget {
  const _PassTile({
    required this.pass,
    required this.onShare,
    required this.onRevoke,
    required this.onDelete,
  });

  final GuestPass pass;
  final VoidCallback onShare;
  final VoidCallback onRevoke;
  final VoidCallback onDelete;

  String _formatExpiry(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  /// Human line for a recurrence, e.g. «Mon · Thu · 08:00–12:00».
  String _scheduleSummary(AppStrings s, GuestSchedule schedule) {
    String two(int n) => n.toString().padLeft(2, '0');
    String hm(int m) => '${two(m ~/ 60)}:${two(m % 60)}';
    final days = schedule.weekdays.map(s.weekdayShort).join(' · ');
    return '$days · ${hm(schedule.startMinute)}–${hm(schedule.endMinute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final usesText = pass.maxUses <= 0
        ? s.guestUsesUnlimited
        : s.guestUsesLeft(pass.usesLeft ?? 0);

    return SectionCard(
      child: InkWell(
        onTap: onShare,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pass.label.isEmpty
                                ? s.guestPassesTitle
                                : pass.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        GuestStatusChip(pass),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pass.recurring
                          ? s.guestRepeatUntil(_formatExpiry(pass.expiresAt))
                          : s.guestValidUntil(_formatExpiry(pass.expiresAt)),
                      style: theme.textTheme.labelMedium,
                      textDirection: TextDirection.ltr,
                    ),
                    if (pass.schedule != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _scheduleSummary(s, pass.schedule!),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(usesText, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: s.guestShare,
                onPressed: onShare,
              ),
              if (pass.revocable)
                IconButton(
                  icon: const Icon(Icons.block_rounded),
                  tooltip: s.guestRevoke,
                  onPressed: onRevoke,
                ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).extension<AppColors>()!.danger,
                ),
                tooltip: s.guestDeleteTitle,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final colors = theme.extension<AppColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.guestPassesEmpty,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.guestPassesEmptyHint,
              style: theme.textTheme.labelMedium?.copyWith(color: colors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
