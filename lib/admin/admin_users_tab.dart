import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import 'admin_user_detail_screen.dart';
import 'admin_user_edit_screen.dart';
import 'admin_user_filter.dart';

/// Users tab: searchable / status-filterable list with long-press multi-select
/// and bulk approve / suspend. Receives the resolved user list from the parent
/// (which owns the single stream).
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({
    super.key,
    required this.authService,
    required this.adminName,
    required this.users,
  });

  final AuthService authService;
  final String adminName;
  final List<AppUser> users;

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _searchController = TextEditingController();
  String _query = '';
  UserStatus? _statusFilter;
  bool _selectionMode = false;
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _enterSelection(String uid) {
    setState(() {
      _selectionMode = true;
      _selected.add(uid);
    });
  }

  void _toggle(String uid) {
    setState(() {
      if (!_selected.add(uid)) _selected.remove(uid);
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  Future<void> _applyBulk(UserStatus status) async {
    final s = AppStrings.of(context);
    // Drop any uids that vanished from the stream since selection.
    final present = {for (final u in widget.users) u.uid: u};
    final targets = _selected.where(present.containsKey).toList();
    if (targets.isEmpty) {
      _exitSelection();
      return;
    }
    final approved = status == UserStatus.approved;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? s.bulkApproveTitle : s.bulkSuspendTitle),
        content: Text(approved
            ? s.bulkApproveConfirm(targets.length)
            : s.bulkSuspendConfirm(targets.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(approved ? s.approve : s.reject),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.authService.setStatusForUsers(targets, status);
      for (final uid in targets) {
        final name = present[uid]?.name ?? '';
        await widget.authService.recordAudit(
          actorName: widget.adminName,
          action: approved ? 'approve' : 'reject',
          targetUid: uid,
          targetName: name,
        );
        await widget.authService.enqueuePush(
          type: approved ? 'approved' : 'rejected',
          targetUid: uid,
        );
      }
      if (!mounted) return;
      showToast(context, s.bulkApplied(targets.length));
      _exitSelection();
    } on Exception {
      if (!mounted) return;
      showToast(context, s.bulkFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final me = widget.authService.currentUser?.uid;
    final filtered = filterUsers(
      widget.users,
      query: _query,
      status: _statusFilter,
    );
    return Column(
      children: [
        if (_selectionMode)
          _SelectionBar(
            count: _selected.length,
            onClear: _exitSelection,
            onApprove: () => _applyBulk(UserStatus.approved),
            onSuspend: () => _applyBulk(UserStatus.rejected),
          )
        else
          _SearchAndFilters(
            controller: _searchController,
            status: _statusFilter,
            onQuery: (q) => setState(() => _query = q),
            onStatus: (st) => setState(() => _statusFilter = st),
          ),
        Expanded(
          child: widget.users.isEmpty
              ? Center(child: Text(s.noUsers))
              : filtered.isEmpty
                  ? Center(child: Text(s.noMatchingResults))
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.sm + 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final user = filtered[i];
                        return _UserTile(
                          authService: widget.authService,
                          adminName: widget.adminName,
                          user: user,
                          isMe: user.uid == me,
                          selectionMode: _selectionMode,
                          selected: _selected.contains(user.uid),
                          onEnterSelection: () => _enterSelection(user.uid),
                          onToggle: () => _toggle(user.uid),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

/// Search field + status filter chips, shown when not selecting.
class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.status,
    required this.onQuery,
    required this.onStatus,
  });

  final TextEditingController controller;
  final UserStatus? status;
  final ValueChanged<String> onQuery;
  final ValueChanged<UserStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: s.adminSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: s.filterAll,
                  selected: status == null,
                  onSelected: () => onStatus(null),
                ),
                _FilterChip(
                  label: s.statusPending,
                  selected: status == UserStatus.pending,
                  onSelected: () => onStatus(UserStatus.pending),
                ),
                _FilterChip(
                  label: s.statusApproved,
                  selected: status == UserStatus.approved,
                  onSelected: () => onStatus(UserStatus.approved),
                ),
                _FilterChip(
                  label: s.statusRejected,
                  selected: status == UserStatus.rejected,
                  onSelected: () => onStatus(UserStatus.rejected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

/// Contextual bar shown during multi-select: count + bulk actions + clear.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onApprove,
    required this.onSuspend,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final enabled = count > 0;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: s.bulkClear,
              onPressed: onClear,
            ),
            Expanded(
              child: Text(
                s.selectedCount(count),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: enabled ? onApprove : null,
              icon: Icon(Icons.check, color: enabled ? colors.success : null),
              label: Text(
                s.bulkApprove,
                style: TextStyle(color: enabled ? colors.success : null),
              ),
            ),
            TextButton.icon(
              onPressed: enabled ? onSuspend : null,
              icon: Icon(Icons.block, color: enabled ? colors.danger : null),
              label: Text(
                s.bulkSuspend,
                style: TextStyle(color: enabled ? colors.danger : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One user row. Tap opens detail (or toggles selection while selecting);
/// long-press starts selection. Per-user action buttons hide while selecting.
class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.authService,
    required this.adminName,
    required this.user,
    required this.isMe,
    required this.selectionMode,
    required this.selected,
    required this.onEnterSelection,
    required this.onToggle,
  });

  final AuthService authService;
  final String adminName;
  final AppUser user;
  final bool isMe;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onEnterSelection;
  final VoidCallback onToggle;

  Future<void> _setStatus(UserStatus status) async {
    await authService.setStatus(user.uid, status);
    final approved = status == UserStatus.approved;
    await authService.recordAudit(
      actorName: adminName,
      action: approved ? 'approve' : 'reject',
      targetUid: user.uid,
      targetName: user.name,
    );
    await authService.enqueuePush(
      type: approved ? 'approved' : 'rejected',
      targetUid: user.uid,
    );
  }

  Future<void> _toggleRole() async {
    final makeAdmin = !user.isAdmin;
    await authService.setRole(
      user.uid,
      makeAdmin ? UserRole.admin : UserRole.user,
    );
    await authService.recordAudit(
      actorName: adminName,
      action: makeAdmin ? 'make_admin' : 'remove_admin',
      targetUid: user.uid,
      targetName: user.name,
    );
  }

  /// Issue (or reissue) an access code for a pending user, audit it, and show
  /// the value in a copyable dialog for out-of-band hand-off.
  Future<void> _issueCode(BuildContext context) async {
    final s = AppStrings.of(context);
    try {
      final code = await authService.issueAccessCode(
        uid: user.uid,
        email: user.email,
      );
      await authService.recordAudit(
        actorName: adminName,
        action: 'issue_code',
        targetUid: user.uid,
        targetName: user.name,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.issueCodeTitle),
          content: SelectableText(s.issueCodeBody(code)),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                showToast(context, s.codeCopied);
              },
              icon: const Icon(Icons.copy),
              label: Text(s.copyCode),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.cancel),
            ),
          ],
        ),
      );
    } on Exception {
      if (!context.mounted) return;
      showToast(context, s.issueCodeError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    // Self is never selectable (mirrors the single-user action guard).
    final selectable = selectionMode && !isMe;
    return GestureDetector(
      onTap: () {
        if (selectionMode) {
          if (!isMe) onToggle();
        } else {
          _openDetail(context);
        }
      },
      onLongPress: isMe || selectionMode ? null : onEnterSelection,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectable)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                  ),
                InitialsAvatar(name: user.name, seed: user.uid, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name.isEmpty ? s.noName : user.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(user.email,
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
                StatusBadge.status(user.status),
              ],
            ),
            if (user.isAdmin)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge.role(UserRole.admin),
                ),
              ),
            if (!isMe && !selectionMode) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                children: [
                  if (user.status != UserStatus.approved)
                    TextButton.icon(
                      onPressed: () => _setStatus(UserStatus.approved),
                      icon: const Icon(Icons.check, color: Color(0xFF059669)),
                      label: Text(s.approve,
                          style: const TextStyle(color: Color(0xFF059669))),
                    ),
                  if (user.status == UserStatus.pending)
                    TextButton.icon(
                      onPressed: () => _issueCode(context),
                      icon: const Icon(Icons.vpn_key_outlined,
                          color: Color(0xFF2563EB)),
                      label: Text(s.issueCodeButton,
                          style: const TextStyle(color: Color(0xFF2563EB))),
                    ),
                  if (user.status != UserStatus.rejected)
                    TextButton.icon(
                      onPressed: () => _setStatus(UserStatus.rejected),
                      icon: const Icon(Icons.close, color: Color(0xFFDC2626)),
                      label: Text(s.reject,
                          style: const TextStyle(color: Color(0xFFDC2626))),
                    ),
                  TextButton.icon(
                    onPressed: _toggleRole,
                    icon: Icon(
                      user.isAdmin
                          ? Icons.remove_moderator_outlined
                          : Icons.admin_panel_settings_outlined,
                      color: const Color(0xFF7C3AED),
                    ),
                    label: Text(
                      user.isAdmin ? s.removeAdmin : s.makeAdmin,
                      style: const TextStyle(color: Color(0xFF7C3AED)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openEdit(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(s.edit),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFDC2626)),
                    label: Text(s.delete,
                        style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminUserDetailScreen(
          authService: authService,
          adminName: adminName,
          user: user,
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminUserEditScreen(
          authService: authService,
          adminName: adminName,
          user: user,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final s = AppStrings.of(context);
    final name = user.name.isEmpty ? user.email : user.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteUserTitle),
        content: Text(s.deleteUserConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete,
                style: const TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await authService.deleteUser(user.uid);
      await authService.recordAudit(
        actorName: adminName,
        action: 'delete_user',
        targetUid: user.uid,
        targetName: user.name,
      );
      if (!context.mounted) return;
      showToast(context, s.userDeleted);
    } on Exception {
      if (!context.mounted) return;
      showToast(context, s.userDeleteFailed);
    }
  }
}
