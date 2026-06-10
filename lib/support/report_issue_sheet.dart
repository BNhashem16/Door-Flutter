import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'support_service.dart';
import 'support_ticket.dart';

/// Bottom sheet for a resident to report an issue or suggest an improvement.
/// Writes a [SupportTicket] via [SupportService]; the admin sees it in the
/// support inbox.
class ReportIssueSheet extends StatefulWidget {
  const ReportIssueSheet({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
  });

  final String uid;
  final String name;
  final String email;

  /// Opens the sheet; resolves to `true` when a ticket was submitted.
  static Future<bool?> show(
    BuildContext context, {
    required String uid,
    required String name,
    required String email,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => ReportIssueSheet(uid: uid, name: name, email: email),
    );
  }

  @override
  State<ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<ReportIssueSheet> {
  final _service = SupportService();
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  TicketCategory _category = TicketCategory.bug;
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _categoryLabel(AppStrings s, TicketCategory c) => switch (c) {
        TicketCategory.bug => s.reportCategoryBug,
        TicketCategory.suggestion => s.reportCategorySuggestion,
        TicketCategory.other => s.reportCategoryOther,
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final s = AppStrings.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    setState(() => _submitting = true);
    try {
      await _service.submit(
        uid: widget.uid,
        name: widget.name,
        email: widget.email,
        category: _category,
        message: _messageController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.reportIssueError),
          backgroundColor: colors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.reportIssueTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              Text(
                s.reportCategoryLabel,
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final c in TicketCategory.values)
                    ChoiceChip(
                      label: Text(_categoryLabel(s, c)),
                      selected: _category == c,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _messageController,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: s.reportIssueTitle,
                  hintText: s.reportIssueHint,
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s.reportIssueRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(s.reportIssueSend),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
