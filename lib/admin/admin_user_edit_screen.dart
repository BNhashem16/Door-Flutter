import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';

/// Admin edit: change any of a user's fields, including role and status.
/// Email and createdAt stay immutable (set on register).
class AdminUserEditScreen extends StatefulWidget {
  const AdminUserEditScreen({
    super.key,
    required this.authService,
    required this.user,
    this.adminName = '',
  });

  final AuthService authService;
  final AppUser user;

  /// The signed-in admin's own name — stamped onto the audit-log entry.
  final String adminName;

  @override
  State<AdminUserEditScreen> createState() => _AdminUserEditScreenState();
}

class _AdminUserEditScreenState extends State<AdminUserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.user.name);
  late final TextEditingController _apartmentCtrl =
      TextEditingController(text: widget.user.apartment);
  late final TextEditingController _bioCtrl =
      TextEditingController(text: widget.user.bio);
  late UserRole _role = widget.user.role;
  late UserStatus _status = widget.user.status == UserStatus.unknown
      ? UserStatus.pending
      : widget.user.status;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apartmentCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.authService.adminUpdateUser(
        widget.user.uid,
        name: _nameCtrl.text,
        apartment: _apartmentCtrl.text,
        bio: _bioCtrl.text,
        role: _role,
        status: _status,
      );
      await widget.authService.recordAudit(
        actorName: widget.adminName,
        action: 'edit_user',
        targetUid: widget.user.uid,
        targetName: _nameCtrl.text,
      );
      // If this edit flipped approval status, push the user so they learn even
      // with their app closed (the quick approve/reject buttons do the same).
      if (_status != widget.user.status &&
          (_status == UserStatus.approved || _status == UserStatus.rejected)) {
        await widget.authService.enqueuePush(
          type: _status == UserStatus.approved ? 'approved' : 'rejected',
          targetUid: widget.user.uid,
        );
      }
      if (!mounted) return;
      showToast(context, AppStrings.of(context).saveChangesSuccess);
      Navigator.of(context).pop();
    } on Exception {
      if (!mounted) return;
      showToast(context, AppStrings.of(context).saveChangesError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.editUserTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.name,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? s.enterNameField : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  initialValue: widget.user.email,
                  enabled: false,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: s.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _apartmentCtrl,
                  decoration: InputDecoration(
                    labelText: s.apartment,
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bioCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: s.bio,
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: InputDecoration(
                    labelText: s.roleLabel,
                    prefixIcon: const Icon(Icons.shield_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: UserRole.user,
                      child: Text(s.roleUser),
                    ),
                    DropdownMenuItem(
                      value: UserRole.admin,
                      child: Text(s.roleAdmin),
                    ),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<UserStatus>(
                  initialValue: _status,
                  decoration: InputDecoration(
                    labelText: s.statusLabel,
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: UserStatus.pending,
                      child: Text(s.statusPending),
                    ),
                    DropdownMenuItem(
                      value: UserStatus.approved,
                      child: Text(s.statusApproved),
                    ),
                    DropdownMenuItem(
                      value: UserStatus.rejected,
                      child: Text(s.statusRejected),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
