import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../logs/gate_log.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

/// Whose access data the dashboard charts.
enum AnalyticsScope { own, all }

/// Opens-over-time dashboard derived live from gate logs. Admins see every
/// user's activity ([AnalyticsScope.all]); a resident sees only their own.
/// Pure client-side aggregation — no extra backend.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    required this.authService,
    required this.scope,
    this.uid,
  });

  final AuthService authService;
  final AnalyticsScope scope;

  /// Required for [AnalyticsScope.own]; ignored for [AnalyticsScope.all].
  final String? uid;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _days = 7; // 7 or 30

  Stream<List<GateLog>> _stream() {
    if (widget.scope == AnalyticsScope.all) {
      return widget.authService.watchAllLogs();
    }
    final uid = widget.uid ?? widget.authService.currentUser?.uid ?? '';
    return widget.authService.watchUserLogs(uid);
  }

  /// Count of OPEN actions per day for the last [_days] days, oldest → newest.
  List<int> _bucketByDay(List<GateLog> logs) {
    final buckets = List<int>.filled(_days, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final log in logs) {
      if (log.action != GateAction.open) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(log.timestamp);
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff >= 0 && diff < _days) {
        buckets[_days - 1 - diff]++;
      }
    }
    return buckets;
  }

  /// OPEN counts per source over the whole window.
  Map<GateSource, int> _bySource(List<GateLog> logs) {
    final map = {GateSource.app: 0, GateSource.widget: 0, GateSource.guest: 0};
    final cutoff =
        DateTime.now().subtract(Duration(days: _days)).millisecondsSinceEpoch;
    for (final log in logs) {
      if (log.action != GateAction.open) continue;
      if (log.timestamp < cutoff) continue;
      map[log.source] = (map[log.source] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.analyticsTitle)),
      body: StreamBuilder<List<GateLog>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(s.logsLoadError));
          }
          final logs = snap.data ?? const <GateLog>[];
          final buckets = _bucketByDay(logs);
          final total = buckets.fold<int>(0, (a, b) => a + b);
          final sources = _bySource(logs);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _periodToggle(s),
              const SizedBox(height: AppSpacing.lg),
              _summaryRow(s, total, buckets),
              const SizedBox(height: AppSpacing.lg),
              _chartCard(s, buckets, total),
              const SizedBox(height: AppSpacing.lg),
              _sourceCard(s, sources, total),
            ],
          );
        },
      ),
    );
  }

  Widget _periodToggle(AppStrings s) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        ChoiceChip(
          label: Text(s.analyticsLast7),
          selected: _days == 7,
          showCheckmark: false,
          onSelected: (_) => setState(() => _days = 7),
        ),
        ChoiceChip(
          label: Text(s.analyticsLast30),
          selected: _days == 30,
          showCheckmark: false,
          onSelected: (_) => setState(() => _days = 30),
        ),
      ],
    );
  }

  Widget _summaryRow(AppStrings s, int total, List<int> buckets) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final busiest =
        buckets.isEmpty ? 0 : buckets.reduce((a, b) => a > b ? a : b);
    final avg = buckets.isEmpty ? 0 : (total / buckets.length).round();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _stat(theme, colors, Icons.lock_open_rounded, colors.success,
                '$total', s.analyticsTotalOpens),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _stat(theme, colors, Icons.trending_up_rounded,
                theme.colorScheme.primary, '$busiest', s.analyticsBusiestDay),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _stat(theme, colors, Icons.calendar_today_rounded,
                colors.muted, '$avg', s.analyticsDailyAvg),
          ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, AppColors colors, IconData icon, Color accent,
      String value, String label) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, color: accent),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _chartCard(AppStrings s, List<int> buckets, int total) {
    final theme = Theme.of(context);
    final maxY = (buckets.isEmpty ? 0 : buckets.reduce((a, b) => a > b ? a : b))
        .toDouble();

    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(s.analyticsOpensPerDay, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child:
                    Text(s.analyticsNoData, style: theme.textTheme.labelMedium),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxY < 1 ? 1 : maxY) * 1.2,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: theme.dividerColor, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) => _bottomLabel(
                            theme, s, value.toInt(), buckets.length),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[i].toDouble(),
                            color: theme.colorScheme.primary,
                            width: buckets.length > 10 ? 6 : 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// X-axis label: weekday short for the 7-day view; day-of-month every 5th bar
  /// for the 30-day view to avoid clutter.
  Widget _bottomLabel(ThemeData theme, AppStrings s, int index, int count) {
    final day = DateTime.now().subtract(Duration(days: count - 1 - index));
    final String text;
    if (count <= 7) {
      text = s.weekdayShort(day.weekday);
    } else {
      if (index % 5 != 0 && index != count - 1) return const SizedBox.shrink();
      text = '${day.day}/${day.month}';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: theme.textTheme.labelSmall),
    );
  }

  Widget _sourceCard(AppStrings s, Map<GateSource, int> sources, int total) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final rows = <(String, int, Color)>[
      (s.logSourceApp, sources[GateSource.app] ?? 0, theme.colorScheme.primary),
      (s.logSourceWidget, sources[GateSource.widget] ?? 0, colors.success),
      (s.logSourceGuest, sources[GateSource.guest] ?? 0, colors.muted),
    ];

    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_small_rounded,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(s.analyticsBySource, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, count, color) in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                      width: 80,
                      child: Text(label, style: theme.textTheme.labelMedium)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : count / total,
                        minHeight: 10,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('$count', style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
