import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import 'support_service.dart';
import 'support_ticket.dart';

/// Resident view of their own submitted reports, with the admin's reply (when
/// present) and live status. Read from `/support_tickets/{uid}` via
/// [SupportService.watchOwn].
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final service = SupportService();
    return Scaffold(
      appBar: AppBar(title: Text(s.myReportsTitle)),
      body: StreamBuilder<List<SupportTicket>>(
        stream: service.watchOwn(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tickets = snap.data ?? const <SupportTicket>[];
          if (tickets.isEmpty) {
            return Center(child: Text(s.myReportsEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _MyTicketTile(ticket: tickets[i]),
          );
        },
      ),
    );
  }
}

class _MyTicketTile extends StatelessWidget {
  const _MyTicketTile({required this.ticket});

  final SupportTicket ticket;

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
              _pill(theme, _categoryLabel(s), colors.muted),
              const SizedBox(width: AppSpacing.xs),
              _pill(
                theme,
                ticket.isOpen ? s.supportOpen : s.supportResolved,
                statusColor,
              ),
              const Spacer(),
              Text(
                _formatTime(ticket.createdAt),
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(ticket.message, style: theme.textTheme.bodyMedium),
          if (ticket.hasReply) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:
                    Border.all(color: colors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent_rounded,
                          size: 16, color: colors.success),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        s.ticketAdminReply,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(ticket.reply, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
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
