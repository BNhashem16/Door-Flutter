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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.guestRevokeTitle),
        content: Text(s.guestRevokeConfirm(pass.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.guestRevoke),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.revoke(_uid, pass.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.guestRevoked)),
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

    return Scaffold(
      appBar: AppBar(title: Text(s.guestPassesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: Text(s.newGuestPass),
      ),
      body: StreamBuilder<List<GuestPass>>(
        stream: _service.watchPasses(_uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(s.guestPassLoadError));
          }
          final passes = snap.data ?? const <GuestPass>[];
          if (passes.isEmpty) {
            return _Empty(onCreate: _create);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            itemCount: passes.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _PassTile(
              pass: passes[i],
              onShare: () => _share(passes[i]),
              onRevoke: () => _revoke(passes[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PassTile extends StatelessWidget {
  const _PassTile({
    required this.pass,
    required this.onShare,
    required this.onRevoke,
  });

  final GuestPass pass;
  final VoidCallback onShare;
  final VoidCallback onRevoke;

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
                      s.guestValidUntil(_formatExpiry(pass.expiresAt)),
                      style: theme.textTheme.labelMedium,
                      textDirection: TextDirection.ltr,
                    ),
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
              if (!pass.revoked && pass.valid)
                IconButton(
                  icon: const Icon(Icons.block_rounded),
                  tooltip: s.guestRevoke,
                  onPressed: onRevoke,
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
