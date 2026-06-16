import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'guest_pass.dart';
import 'guest_service.dart';

/// Which preset duration the resident picked.
enum _DurChoice { h1, h3, tonight, custom, permanent }

/// Bottom sheet to create a guest pass: visitor label + duration + max opens.
/// Creates the pass via [GuestService] and pops the created [GuestPass] so the
/// caller can present the share view.
class CreateGuestPassSheet extends StatefulWidget {
  const CreateGuestPassSheet({
    super.key,
    required this.service,
    required this.ownerUid,
    required this.createdByName,
  });

  final GuestService service;
  final String ownerUid;
  final String createdByName;

  /// Opens the sheet; resolves to the created pass, or null if dismissed.
  static Future<GuestPass?> show(
    BuildContext context, {
    required GuestService service,
    required String ownerUid,
    required String createdByName,
  }) {
    return showModalBottomSheet<GuestPass>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => CreateGuestPassSheet(
        service: service,
        ownerUid: ownerUid,
        createdByName: createdByName,
      ),
    );
  }

  @override
  State<CreateGuestPassSheet> createState() => _CreateGuestPassSheetState();
}

class _CreateGuestPassSheetState extends State<CreateGuestPassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();

  _DurChoice _dur = _DurChoice.h3;
  int _customHours = 6;
  int _maxUses = 1;
  bool _submitting = false;

  // Recurring (weekly) schedule.
  bool _recurring = false;
  final Set<int> _weekdays = {}; // DateTime.weekday: 1=Mon … 7=Sun
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 12, minute: 0);
  DateTime _repeatUntil = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Duration _resolveDuration() {
    switch (_dur) {
      case _DurChoice.h1:
        return const Duration(hours: 1);
      case _DurChoice.h3:
        return const Duration(hours: 3);
      case _DurChoice.tonight:
        final now = DateTime.now();
        var end = DateTime(now.year, now.month, now.day, 23, 59);
        if (!end.isAfter(now)) end = end.add(const Duration(days: 1));
        return end.difference(now);
      case _DurChoice.custom:
        return Duration(hours: _customHours);
      case _DurChoice.permanent:
        // Permanent pass has no time window; callers branch on this before
        // calling _resolveDuration, so this value is never used.
        return Duration.zero;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final s = AppStrings.of(context);
    if (_recurring && _weekdays.isEmpty) {
      final colors = Theme.of(context).extension<AppColors>()!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.guestWeekdaysRequired),
          backgroundColor: colors.danger,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final pass = _recurring
          ? await widget.service.createRecurringPass(
              ownerUid: widget.ownerUid,
              createdByName: widget.createdByName,
              label: _labelController.text,
              schedule: GuestSchedule(
                weekdays: _weekdays.toList()..sort(),
                startMinute: _minutes(_from),
                endMinute: _minutes(_to),
              ),
              repeatUntil: _repeatUntil,
              maxUses: _maxUses,
            )
          : await widget.service.createPass(
              ownerUid: widget.ownerUid,
              createdByName: widget.createdByName,
              label: _labelController.text,
              validFor: _dur == _DurChoice.permanent ? null : _resolveDuration(),
              maxUses: _maxUses,
            );
      if (!mounted) return;
      Navigator.of(context).pop(pass);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final colors = Theme.of(context).extension<AppColors>()!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).saveChangesError),
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
              Text(s.newGuestPass, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _labelController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: s.guestLabelLabel,
                  hintText: s.guestLabelHint,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s.guestLabelRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _recurringToggle(theme, s),
              const SizedBox(height: AppSpacing.lg),
              if (!_recurring) ...[
                _label(theme, s.guestDurationLabel),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _choice(s.guestDur1h, _dur == _DurChoice.h1,
                        () => setState(() => _dur = _DurChoice.h1)),
                    _choice(s.guestDur3h, _dur == _DurChoice.h3,
                        () => setState(() => _dur = _DurChoice.h3)),
                    _choice(s.guestDurTonight, _dur == _DurChoice.tonight,
                        () => setState(() => _dur = _DurChoice.tonight)),
                    _choice(s.guestDurCustom, _dur == _DurChoice.custom,
                        () => setState(() => _dur = _DurChoice.custom)),
                    _choice(s.guestDurPermanent, _dur == _DurChoice.permanent,
                        () => setState(() => _dur = _DurChoice.permanent)),
                  ],
                ),
                if (_dur == _DurChoice.custom) ...[
                  const SizedBox(height: AppSpacing.md),
                  _hoursStepper(theme, s),
                ],
              ] else
                _scheduleControls(theme, s),
              const SizedBox(height: AppSpacing.lg),
              _label(theme, s.guestMaxUsesLabel),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _choice(s.guestUsesOnce, _maxUses == 1,
                      () => setState(() => _maxUses = 1)),
                  _choice(s.guestUsesFive, _maxUses == 5,
                      () => setState(() => _maxUses = 5)),
                  _choice(s.guestUsesUnlimitedOption, _maxUses == 0,
                      () => setState(() => _maxUses = 0)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
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
                      : const Icon(Icons.add_link_rounded),
                  label: Text(s.createGuestPass),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Text(
        text,
        style:
            theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      );

  Widget _recurringToggle(ThemeData theme, AppStrings s) {
    final colors = theme.extension<AppColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: SwitchListTile(
        value: _recurring,
        onChanged: (v) => setState(() => _recurring = v),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        secondary: const Icon(Icons.event_repeat_rounded),
        title: Text(s.guestRecurringToggle),
        subtitle: Text(s.guestRecurringHint),
      ),
    );
  }

  /// Weekday selector + daily time window + repeat-until date for a recurring
  /// pass.
  Widget _scheduleControls(ThemeData theme, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(theme, s.guestWeekdaysLabel),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var d = 1; d <= 7; d++)
              _choice(
                s.weekdayShort(d),
                _weekdays.contains(d),
                () => setState(() => _weekdays.contains(d)
                    ? _weekdays.remove(d)
                    : _weekdays.add(d)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _label(theme, s.guestWindowLabel),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _timeField(theme, s.guestWindowFrom, _from, (t) {
                setState(() => _from = t);
              }),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _timeField(theme, s.guestWindowTo, _to, (t) {
                setState(() => _to = t);
              }),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _label(theme, s.guestEndDateLabel),
        const SizedBox(height: AppSpacing.sm),
        _dateField(theme, s),
      ],
    );
  }

  Widget _timeField(
    ThemeData theme,
    String label,
    TimeOfDay value,
    ValueChanged<TimeOfDay> onPick,
  ) {
    String two(int n) => n.toString().padLeft(2, '0');
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: value);
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text(
          '${two(value.hour)}:${two(value.minute)}',
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _dateField(ThemeData theme, AppStrings s) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = _repeatUntil;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _repeatUntil,
          firstDate: now,
          lastDate: now.add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _repeatUntil = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: s.guestEndDateLabel,
          prefixIcon: const Icon(Icons.event_rounded),
        ),
        child: Text(
          '${d.year}/${two(d.month)}/${two(d.day)}',
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }

  Widget _hoursStepper(ThemeData theme, AppStrings s) {
    final colors = theme.extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Text(s.guestCustomHoursLabel, style: theme.textTheme.bodyMedium),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            onPressed:
                _customHours > 1 ? () => setState(() => _customHours--) : null,
          ),
          SizedBox(
            width: 64,
            child: Text(
              s.guestHours(_customHours),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed:
                _customHours < 24 ? () => setState(() => _customHours++) : null,
          ),
        ],
      ),
    );
  }
}
