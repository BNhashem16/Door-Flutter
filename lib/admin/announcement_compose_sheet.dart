import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../toast/toast_service.dart';

/// Admin bottom sheet to compose a building-wide announcement. Enqueues a
/// `broadcast` push-outbox entry; the Worker fans it out to every resident.
class AnnouncementComposeSheet extends StatefulWidget {
  const AnnouncementComposeSheet({super.key, required this.authService});

  final AuthService authService;

  static Future<void> show(BuildContext context, AuthService authService) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AnnouncementComposeSheet(authService: authService),
    );
  }

  @override
  State<AnnouncementComposeSheet> createState() =>
      _AnnouncementComposeSheetState();
}

class _AnnouncementComposeSheetState extends State<AnnouncementComposeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final s = AppStrings.of(context);
    try {
      await widget.authService.enqueueBroadcast(
        title: _titleCtrl.text,
        body: _bodyCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, s.announcementSent);
    } on Exception {
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(context, s.announcementError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(s.announcementTitle,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: s.announcementSubject,
                prefixIcon: const Icon(Icons.title_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? s.announcementSubjectHint
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bodyCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: s.announcementBody,
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? s.announcementBodyHint
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(s.announcementSend),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
