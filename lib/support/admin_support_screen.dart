import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_card.dart';
import 'support_service.dart';
import 'support_ticket.dart';

/// Admin inbox: live list of user-submitted support tickets with a
/// resolve/reopen toggle.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({
    super.key,
    required this.authService,
    this.adminName = '',
  });

  final AuthService authService;

  /// The signed-in admin's own name — stamped onto audit-log entries.
  final String adminName;

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final SupportService _service = SupportService();

  Future<void> _toggle(SupportTicket t) async {
    final s = AppStrings.of(context);
    final next = t.isOpen ? TicketStatus.resolved : TicketStatus.open;
    try {
      await _service.setStatus(t.uid, t.id, next);
      // On resolve: record the action and push the reporter (best-effort) so
      // they get closure even with their app closed. Reopen is silent.
      if (next == TicketStatus.resolved) {
        await widget.authService.recordAudit(
          actorName: widget.adminName,
          action: 'resolve_ticket',
          targetUid: t.uid,
          targetName: t.name,
        );
        await widget.authService.enqueuePush(
          type: 'ticket_resolved',
          targetUid: t.uid,
        );
      }
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
      appBar: AppBar(title: Text(s.supportTitle)),
      body: StreamBuilder<List<SupportTicket>>(
        stream: _service.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(s.supportLoadError));
          }
          final tickets = snap.data ?? const <SupportTicket>[];
          if (tickets.isEmpty) {
            return Center(child: Text(s.supportEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _TicketTile(
                ticket: tickets[i], onToggle: () => _toggle(tickets[i])),
          );
        },
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onToggle});

  final SupportTicket ticket;
  final VoidCallback onToggle;

  String _categoryLabel(AppStrings s) => switch (ticket.category) {
        TicketCategory.bug => s.reportCategoryBug,
        TicketCategory.suggestion => s.reportCategorySuggestion,
        TicketCategory.other => s.reportCategoryOther,
      };

  String _formatTime(int ms) {
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final colors = theme.extension<AppColors>()!;
    final statusColor = ticket.isOpen ? colors.danger : colors.success;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: ticket.name, seed: ticket.uid, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.name.isEmpty ? s.noName : ticket.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (ticket.email.isNotEmpty)
                      Text(
                        ticket.email,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              _pill(theme, _categoryLabel(s), colors.muted),
              const SizedBox(width: AppSpacing.xs),
              _pill(
                theme,
                ticket.isOpen ? s.supportOpen : s.supportResolved,
                statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(ticket.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                _formatTime(ticket.createdAt),
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  ticket.isOpen
                      ? Icons.check_circle_outline_rounded
                      : Icons.undo_rounded,
                  color: ticket.isOpen ? colors.success : colors.muted,
                ),
                label: Text(
                  ticket.isOpen ? s.supportMarkResolved : s.supportReopen,
                  style: TextStyle(
                    color: ticket.isOpen ? colors.success : colors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(ThemeData theme, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
