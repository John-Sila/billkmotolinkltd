import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Small helpers shared by the widgets below (UI only).
// ---------------------------------------------------------------------------

double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

String _fmt2(double v) => NumberFormat('#,##0.00').format(v);
String _fmt0(double v) => NumberFormat('#,##0').format(v);

String _signed0(double v) {
  if (v == 0) return '0';
  return '${v > 0 ? '+' : '−'}${_fmt0(v.abs())}';
}

const List<String> _dayOrder = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

Color _gain(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF4ADE80)
    : const Color(0xFF15803D);

Color _loss(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFFF87171)
    : const Color(0xFFB91C1C);

Color _devColor(BuildContext c, double v) {
  if (v > 0) return _gain(c);
  if (v < 0) return _loss(c);
  return Theme.of(c).colorScheme.onSurfaceVariant;
}

/// Totals for one rider across the week.
class _UserStats {
  _UserStats(this.name, this.days) {
    for (final e in days.entries) {
      final d = Map<String, dynamic>.from(e.value as Map);
      gross += _num(d['grossIncome']);
      net += _num(d['netIncome']);
      grossDev += _num(d['grossDeviation']);
      netGrossDiff += _num(d['netGrossDifference']);
    }
  }

  final String name;
  final Map<String, dynamic> days;
  double gross = 0;
  double net = 0;
  double grossDev = 0;
  double netGrossDiff = 0;

  int get dayCount => days.length;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class WeeklyAnalysisReport extends StatefulWidget {
  const WeeklyAnalysisReport({super.key});

  @override
  State<WeeklyAnalysisReport> createState() => _WeeklyAnalysisReportState();
}

class _WeeklyAnalysisReportState extends State<WeeklyAnalysisReport> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _weeksData = {};
  bool _isLoading = true;

  /// true -> riders are ranked by net income, false -> by gross income.
  bool _rankByNet = true;

  @override
  void initState() {
    super.initState();
    _fetchWeeks();
    _cleanupOldWeeks();
  }

  Future<void> _cleanupOldWeeks() async {
    try {
      final fourMonthsAgo = DateTime.now().subtract(const Duration(days: 120));

      final snapshot =
          await FirebaseFirestore.instance.collection('deviations').get();

      final batch = FirebaseFirestore.instance.batch();
      int deletedCount = 0;

      for (var doc in snapshot.docs) {
        final weekLabel = doc.id;
        final startDate = _extractStartDate(weekLabel);

        if (startDate.isBefore(fourMonthsAgo)) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        debugPrint('✅ Deleted $deletedCount old weeks');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cleaned $deletedCount old weeks')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Cleanup error: $e');
    }
  }

  Future<void> _fetchWeeks() async {
    try {
      final snapshot = await _firestore.collection('deviations').get();
      Map<String, dynamic> weeks = {};
      for (var doc in snapshot.docs) {
        weeks[doc.id] = doc.data();
      }
      if (mounted) {
        setState(() {
          _weeksData = weeks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final _weekLabelFormat = DateFormat('dd MMM yyyy');

  DateTime _extractStartDate(String weekLabel) {
    // Extract text between "(" and "to"
    final open = weekLabel.indexOf('(');
    final toIndex = weekLabel.indexOf('to');
    if (open == -1 || toIndex == -1) {
      // Fallback: very old / invalid label -> treat as minimal date
      return DateTime(1970);
    }
    final startPart =
        weekLabel.substring(open + 1, toIndex).trim(); // "08 Dec 2025"
    try {
      return _weekLabelFormat.parse(startPart);
    } catch (_) {
      return DateTime(1970);
    }
  }

  // ---- Presentation helpers for the week header ----------------------------

  /// "Week 50 (08 Dec 2025 to 14 Dec 2025)" -> "Week 50"
  String _weekTitle(String label) {
    final i = label.indexOf('(');
    return i == -1 ? label : label.substring(0, i).trim();
  }

  /// -> "8 Dec – 14 Dec 2025"
  String _weekRange(String label) {
    final start = _extractStartDate(label);
    if (start.year == 1970) {
      final open = label.indexOf('(');
      final close = label.lastIndexOf(')');
      if (open != -1 && close > open) {
        return label.substring(open + 1, close).replaceAll(' to ', ' – ');
      }
      return '';
    }
    final end = start.add(const Duration(days: 6));
    final sameYear = start.year == end.year;
    final left = DateFormat(sameYear ? 'd MMM' : 'd MMM yyyy').format(start);
    final right = DateFormat('d MMM yyyy').format(end);
    return '$left – $right';
  }

  List<_UserStats> _rankedRiders(Map<String, dynamic> usersMap) {
    final list = usersMap.entries
        .map((e) => _UserStats(e.key, Map<String, dynamic>.from(e.value as Map)))
        .toList();
    list.sort((a, b) =>
        _rankByNet ? b.net.compareTo(a.net) : b.gross.compareTo(a.gross));
    return list;
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sortedWeeks = _weeksData.entries.toList()
      ..sort((a, b) {
        final da = _extractStartDate(a.key);
        final db = _extractStartDate(b.key);
        // Newest first
        return db.compareTo(da);
      });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Weekly Analysis',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWeeks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : sortedWeeks.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
                  itemCount: sortedWeeks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildRankToggle(context);

                    final weekIndex = index - 1;
                    final weekEntry = sortedWeeks[weekIndex];
                    final usersMap = Map<String, dynamic>.from(
                        weekEntry.value as Map);

                    return _buildWeekCard(
                      context,
                      weekEntry.key,
                      usersMap,
                      initiallyExpanded: weekIndex == 0,
                    );
                  },
                ),
    );
  }

  Widget _buildRankToggle(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
      child: Row(
        children: [
          Text(
            'RANK RIDERS BY',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            segments: const [
              ButtonSegment(value: true, label: Text('Net')),
              ButtonSegment(value: false, label: Text('Gross')),
            ],
            selected: {_rankByNet},
            onSelectionChanged: (s) => setState(() => _rankByNet = s.first),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.leaderboard_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No weekly data yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Rider rankings and deviations will appear here once clock-outs are recorded.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Week card -----------------------------------------------------------

  Widget _buildWeekCard(
    BuildContext context,
    String weekLabel,
    Map<String, dynamic> usersMap, {
    required bool initiallyExpanded,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final riders = _rankedRiders(usersMap);
    final weekGross = riders.fold<double>(0, (s, r) => s + r.gross);
    final weekNet = riders.fold<double>(0, (s, r) => s + r.net);
    final topValue = riders.isEmpty
        ? 1.0
        : (_rankByNet ? riders.first.net : riders.first.gross);

    final title = _weekTitle(weekLabel);
    final weekNumber = RegExp(r'\d+').firstMatch(title)?.group(0) ?? '–';
    final range = _weekRange(weekLabel);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(weekLabel),
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'WEEK',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  weekNumber,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            range.isEmpty ? title : range,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 14,
              runSpacing: 2,
              children: [
                _MiniStat(label: 'Net', value: _fmt0(weekNet)),
                _MiniStat(label: 'Gross', value: _fmt0(weekGross)),
                _MiniStat(label: 'Riders', value: '${riders.length}'),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'RANKING · BY ${_rankByNet ? 'NET' : 'GROSS'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < riders.length; i++)
              _RiderTile(
                key: ValueKey('$weekLabel-${riders[i].name}'),
                rank: i + 1,
                stats: riders[i],
                rankByNet: _rankByNet,
                fraction: topValue <= 0
                    ? 0
                    : ((_rankByNet ? riders[i].net : riders[i].gross) /
                            topValue)
                        .clamp(0.0, 1.0),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week header mini stat:  Net 123,456
// ---------------------------------------------------------------------------

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One ranked rider. Tap to open the day-by-day breakdown.
// ---------------------------------------------------------------------------

class _RiderTile extends StatefulWidget {
  const _RiderTile({
    super.key,
    required this.rank,
    required this.stats,
    required this.fraction,
    required this.rankByNet,
  });

  final int rank;
  final _UserStats stats;
  final double fraction; // 0..1 versus the week's top rider
  final bool rankByNet;

  @override
  State<_RiderTile> createState() => _RiderTileState();
}

class _RiderTileState extends State<_RiderTile> {
  bool _open = false;

  static const _gold = Color(0xFFC9A227);
  static const _silver = Color(0xFF8E9AAB);
  static const _bronze = Color(0xFFB36B3A);

  Color? _medal() {
    switch (widget.rank) {
      case 1:
        return _gold;
      case 2:
        return _silver;
      case 3:
        return _bronze;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.stats;
    final medal = _medal();
    final barColor = medal ?? scheme.primary;

    final primaryValue = widget.rankByNet ? s.net : s.gross;
    final secondaryLabel = widget.rankByNet ? 'Gross' : 'Net';
    final secondaryValue = widget.rankByNet ? s.gross : s.net;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: medal != null && widget.rank == 1
              ? _gold.withValues(alpha: 0.55)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                children: [
                  _RankBadge(rank: widget.rank, medal: medal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${s.dayCount} ${s.dayCount == 1 ? 'day' : 'days'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _AnimatedBar(
                          fraction: widget.fraction,
                          color: barColor,
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '$secondaryLabel ',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text: _fmt0(secondaryValue),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.rankByNet ? 'NET' : 'GROSS',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _fmt0(primaryValue),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? _DayBreakdown(stats: s)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.medal});
  final int rank;
  final Color? medal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasMedal = medal != null;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasMedal ? medal : scheme.surfaceContainerHighest,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: hasMedal ? Colors.white : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({
    required this.fraction,
    required this.color,
    this.height = 6,
  });
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color,
          backgroundColor: color.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day-by-day breakdown shown under a rider (replaces the old DataTable).
// ---------------------------------------------------------------------------

class _DayBreakdown extends StatelessWidget {
  const _DayBreakdown({required this.stats});
  final _UserStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final entries = stats.days.entries.toList()
      ..sort((a, b) {
        final ia = _dayOrder.indexOf(a.key);
        final ib = _dayOrder.indexOf(b.key);
        if (ia == -1 && ib == -1) return 0;
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });

    final rows = entries
        .map((e) => (
              day: e.key,
              data: Map<String, dynamic>.from(e.value as Map),
            ))
        .toList();

    final maxGross = rows.fold<double>(
        0, (m, r) => _num(r.data['grossIncome']) > m ? _num(r.data['grossIncome']) : m);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),

          // Week totals for this rider
          Row(
            children: [
              Expanded(
                child: _Kpi(label: 'GROSS', value: _fmt0(stats.gross)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Kpi(label: 'NET', value: _fmt0(stats.net)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  label: 'VS TARGET',
                  value: _signed0(stats.grossDev),
                  color: _devColor(context, stats.grossDev),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Kpi(
                  label: 'GROSS − NET',
                  value: _fmt0(stats.netGrossDiff),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            'DAILY BREAKDOWN',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          for (var i = 0; i < rows.length; i++)
            _DayRow(
              day: rows[i].day,
              gross: _num(rows[i].data['grossIncome']),
              net: _num(rows[i].data['netIncome']),
              dev: _num(rows[i].data['grossDeviation']),
              fraction: maxGross <= 0
                  ? 0
                  : _num(rows[i].data['grossIncome']) / maxGross,
              isBest: rows.length > 1 &&
                  maxGross > 0 &&
                  _num(rows[i].data['grossIncome']) == maxGross,
              isLast: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.gross,
    required this.net,
    required this.dev,
    required this.fraction,
    required this.isBest,
    required this.isLast,
  });

  final String day;
  final double gross;
  final double net;
  final double dev;
  final double fraction;
  final bool isBest;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final devColor = _devColor(context, dev);
    final short = day.length >= 3 ? day.substring(0, 3) : day;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          // Day pill
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isBest
                  ? const Color(0xFFC9A227).withValues(alpha: 0.16)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBest) ...[
                  const Icon(Icons.star_rounded,
                      size: 12, color: Color(0xFFC9A227)),
                  const SizedBox(width: 2),
                ],
                Text(
                  short,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Gross + bar
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmt2(gross),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                _AnimatedBar(
                  fraction: fraction,
                  color: isBest ? const Color(0xFFC9A227) : scheme.primary,
                  height: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Net + deviation
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmt2(net),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: devColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dev > 0
                            ? Icons.arrow_drop_up_rounded
                            : (dev < 0
                                ? Icons.arrow_drop_down_rounded
                                : Icons.remove_rounded),
                        size: 16,
                        color: devColor,
                      ),
                      Text(
                        _fmt0(dev.abs()),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: devColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}