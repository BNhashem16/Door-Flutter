import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';
import '../widgets/initials_avatar.dart';
import 'account_store.dart';
import 'auth_service.dart';

/// Bottom sheet listing the accounts saved on this device, letting the user
/// switch between them without a manual logout/login. Opened from the
/// [AppDrawer] header.
class AccountSwitcherSheet extends StatefulWidget {
  const AccountSwitcherSheet({super.key, required this.authService});

  final AuthService authService;

  static Future<void> show(BuildContext context, AuthService authService) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => AccountSwitcherSheet(authService: authService),
    );
  }

  @override
  State<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<AccountSwitcherSheet> {
  late Future<List<SavedAccount>> _future;

  /// Lowercased email of the row currently being switched to, or null.
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _future = widget.authService.accounts.list();
  }

  void _reload() =>
      setState(() => _future = widget.authService.accounts.list());

  String get _currentEmail =>
      (widget.authService.currentUser?.email ?? '').trim().toLowerCase();

  Future<void> _switch(SavedAccount account) async {
    if (_busyKey != null) return;
    if (account.key == _currentEmail) return;
    setState(() => _busyKey = account.key);
    try {
      await widget.authService.switchToAccount(account.email);
      if (!mounted) return;
      // AuthGate routes to the new account behind us; close the sheet.
      Navigator.of(context).pop();
    } on FirebaseAuthException {
      // Saved password is stale (or missing) → ask for it inline.
      if (!mounted) return;
      setState(() => _busyKey = null);
      await _promptPassword(account);
    } on Exception {
      if (!mounted) return;
      setState(() => _busyKey = null);
      showToast(context, AppStrings.of(context).unexpectedError);
    }
  }

  Future<void> _promptPassword(SavedAccount account) async {
    final s = AppStrings.of(context);
    final password = await _PasswordDialog.show(context, account.email);
    if (password == null || password.isEmpty || !mounted) return;
    setState(() => _busyKey = account.key);
    try {
      // signIn re-stamps activeDevice and re-saves the fresh password.
      await widget.authService.signIn(email: account.email, password: password);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() => _busyKey = null);
      showToast(context, s.switchAccountFailed);
    }
  }

  Future<void> _remove(SavedAccount account) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.removeAccountTitle),
        content: Text(s.removeAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.removeAccount),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.authService.accounts.remove(account.email);
    if (!mounted) return;
    // Removing the signed-in account makes no sense to leave authed → sign out.
    if (account.key == _currentEmail) {
      Navigator.of(context).pop();
      await widget.authService.signOut();
      return;
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.switchAccountTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<SavedAccount>>(
              future: _future,
              builder: (context, snap) {
                final accounts = snap.data ?? const <SavedAccount>[];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in accounts) _accountTile(theme, s, a),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busyKey != null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.authService.signOut();
                      },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(s.addAnotherAccount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountTile(ThemeData theme, AppStrings s, SavedAccount a) {
    final isCurrent = a.key == _currentEmail;
    final isBusy = _busyKey == a.key;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: InitialsAvatar(name: a.name, seed: a.key, size: 44),
      title: Text(
        a.name.isEmpty ? a.email : a.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isCurrent ? s.currentAccountLabel : a.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: isCurrent ? null : TextDirection.ltr,
        style: isCurrent
            ? theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.primary)
            : theme.textTheme.labelMedium,
      ),
      trailing: isBusy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2))
          : isCurrent
              ? Icon(Icons.check_circle_rounded,
                  color: theme.colorScheme.primary)
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: s.removeAccount,
                  onPressed: () => _remove(a),
                ),
      onTap: isCurrent || _busyKey != null ? null : () => _switch(a),
    );
  }
}

/// Small modal asking the user to re-type the password for [email] when the
/// stored one no longer works.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.email});

  final String email;

  static Future<String?> show(BuildContext context, String email) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PasswordDialog(email: email),
    );
  }

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AlertDialog(
      title: Text(s.switchAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.email, textDirection: TextDirection.ltr),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: s.password,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(s.confirm),
        ),
      ],
    );
  }
}
