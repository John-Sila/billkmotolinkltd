import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';

/// Absenteeism report.
///
/// READ-ONLY: this screen performs exactly two Firestore `get()` calls
/// (one query on `users`, one collection `get()` on `deviations`) and
/// never writes, updates, or deletes anything. It cross-references:
///
///   • `users` where userRank == 'Rider'  -> the roster of who *should*
///     be showing up, keyed by userName (their clock-out identity).
///   • `deviations/{weekLabel}` -> `{ userName: { weekday: {...} } }`,
///     already written by the existing clock-out flow every time a
///     rider clocks out. A userName appearing under a weekday means
///     that rider clocked out that day, i.e. was present.
///
/// A rider counts as "absent" on a given day only if all of these hold:
///   - the day has already happened (never flags future days)
///   - the day is on/after the rider's account creation date
///   - the day isn't a Sunday for riders who aren't scheduled to work
///     Sundays (`isWorkingOnSunday == false`), mirroring the same rule
///     already enforced on the Clock In screen
///   - the rider is currently active (`isActive != false`) and not
///     soft-deleted (`isDeleted != true`)
class Absenteeism extends StatefulWidget {
  const Absenteeism({super.key});

  @override
  State<Absenteeism> createState() => _AbsenteeismState();
}

class _RiderInfo {
  final String uid;
  final String userName;
  final bool isWorkingOnSunday;
  final DateTime? createdAt;

  _RiderInfo({
    required this.uid,
    required this.userName,
    required this.isWorkingOnSunday,
    required this.createdAt,
  });
}

class _WeekData {
  final String label;
  final DateTime start; // Monday
  final DateTime end; // Sunday
  final Map<String, Set<String>> presentByDay; // weekday -> set of userNames

  _WeekData({
    required this.label,
    required this.start,
    required this.end,
    required this.presentByDay,
  });
}

class _AbsenteeismState extends State<Absenteeism> {
  static const List<String> _weekdayOrder = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final _weekLabelDateFormat = DateFormat('dd MMM yyyy');

  bool _loading = true;
  String? _error;
  List<_WeekData> _weeks = [];
  List<_RiderInfo> _roster = [];
  int _duplicateNameCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Roster of current riders (read-only query, no writes).
      final usersSnap = await firestore
          .collection('users')
          .where('userRank', isEqualTo: 'Rider')
          .get();

      final Map<String, int> nameCounts = {};
      final List<_RiderInfo> roster = [];

      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final isDeleted = data['isDeleted'] == true;
        final isActive = data['isActive'] != false; // default true if absent
        if (isDeleted || !isActive) continue;

        final userName = (data['userName'] ?? '').toString().trim();
        if (userName.isEmpty) continue;

        final createdAtTs = data['createdAt'];
        final createdAt = createdAtTs is Timestamp ? createdAtTs.toDate() : null;

        nameCounts[userName] = (nameCounts[userName] ?? 0) + 1;

        roster.add(_RiderInfo(
          uid: doc.id,
          userName: userName,
          isWorkingOnSunday: data['isWorkingOnSunday'] == true,
          createdAt: createdAt,
        ));
      }

      final duplicates = nameCounts.values.where((c) => c > 1).length;

      // 2. All weekly deviation records (read-only, existing collection).
      final deviationsSnap = await firestore.collection('deviations').get();

      final List<_WeekData> weeks = [];
      for (final doc in deviationsSnap.docs) {
        final range = _extractRange(doc.id);
        if (range == null) continue; // skip malformed/legacy labels safely

        final Map<String, Set<String>> presentByDay = {
          for (final d in _weekdayOrder) d: <String>{},
        };

        final data = doc.data();
        data.forEach((userName, weekdaysRaw) {
          if (weekdaysRaw is! Map) return;
          for (final weekday in weekdaysRaw.keys) {
            final key = weekday.toString();
            if (presentByDay.containsKey(key)) {
              presentByDay[key]!.add(userName.toString().trim());
            }
          }
        });

        weeks.add(_WeekData(
          label: doc.id,
          start: range.$1,
          end: range.$2,
          presentByDay: presentByDay,
        ));
      }

      weeks.sort((a, b) => b.start.compareTo(a.start)); // newest first

      if (!mounted) return;
      setState(() {
        _roster = roster;
        _weeks = weeks;
        _duplicateNameCount = duplicates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load absenteeism data: $e';
        _loading = false;
      });
    }
  }

  /// Parses "Week N (dd MMM yyyy to dd MMM yyyy)" -> (start, end).
  (DateTime, DateTime)? _extractRange(String weekLabel) {
    final open = weekLabel.indexOf('(');
    final toIndex = weekLabel.indexOf(' to ');
    final close = weekLabel.lastIndexOf(')');
    if (open == -1 || toIndex == -1 || close == -1 || close < toIndex) {
      return null;
    }
    final startPart = weekLabel.substring(open + 1, toIndex).trim();
    final endPart = weekLabel.substring(toIndex + 4, close).trim();
    try {
      final start = _weekLabelDateFormat.parse(startPart);
      final end = _weekLabelDateFormat.parse(endPart);
      return (start, end);
    } catch (_) {
      return null;
    }
  }

  bool _isFutureDay(DateTime day) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return day.isAfter(todayOnly);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // appBar: AppBar(
      //   title: const Text('Rider Absenteeism', style: TextStyle(fontWeight: FontWeight.bold)),
      //   elevation: 0,
      //   backgroundColor: theme.colorScheme.surface,
      //   foregroundColor: theme.colorScheme.onSurface,
      //   actions: [
      //     IconButton(
      //       tooltip: 'Refresh',
      //       icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
      //       onPressed: _loading ? null : _load,
      //     ),
      //   ],
      // ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _error != null
              ? _buildErrorState(theme)
              : _weeks.isEmpty
                  ? _buildEmptyState(theme)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildHeaderCard(theme),
                          const SizedBox(height: 16),
                          ..._weeks.map((week) => _buildWeekTile(week, theme)),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.9),
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_roster.length} active rider${_roster.length == 1 ? '' : 's'} tracked',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Presence is derived from clock-out records. '
                  'Riders not scheduled for Sunday work are excluded from Sunday absences.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5),
                ),
                if (_duplicateNameCount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠ $_duplicateNameCount duplicate rider name(s) detected — '
                      'attendance for those names may overlap.',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekTile(_WeekData week, ThemeData theme) {
    // Only count days that have already occurred.
    final relevantDays = _weekdayOrder
        .asMap()
        .entries
        .map((e) => week.start.add(Duration(days: e.key)))
        .where((day) => !_isFutureDay(day))
        .toList();

    // Rough week-level summary for the collapsed subtitle.
    int totalPresentMarks = 0;
    int totalAbsentMarks = 0;
    for (final day in relevantDays) {
      final weekday = _weekdayOrder[day.weekday - 1];
      final present = week.presentByDay[weekday] ?? <String>{};
      for (final rider in _roster) {
        if (!_riderApplicable(rider, day, weekday)) continue;
        if (present.contains(rider.userName)) {
          totalPresentMarks++;
        } else {
          totalAbsentMarks++;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 6,
        shadowColor: theme.shadowColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.calendar_month_rounded, color: theme.colorScheme.onPrimaryContainer),
          ),
          title: Text(
            week.label,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _buildLegendDot(AppTheme.success, '$totalPresentMarks present'),
                const SizedBox(width: 14),
                _buildLegendDot(AppTheme.danger, '$totalAbsentMarks absent'),
              ],
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: relevantDays.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No days have occurred yet for this week.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ]
              : relevantDays
                  .map((day) => _buildDayTile(week, day, theme))
                  .toList(),
        ),
      ),
    );
  }

  bool _riderApplicable(_RiderInfo rider, DateTime day, String weekday) {
    // Skip Sunday for riders not scheduled to work Sundays.
    if (weekday == 'Sunday' && !rider.isWorkingOnSunday) return false;
    // Skip days before the rider even joined.
    if (rider.createdAt != null) {
      final joined = DateTime(rider.createdAt!.year, rider.createdAt!.month, rider.createdAt!.day);
      if (day.isBefore(joined)) return false;
    }
    return true;
  }

  Widget _buildDayTile(_WeekData week, DateTime day, ThemeData theme) {
    final weekday = _weekdayOrder[day.weekday - 1];
    final present = week.presentByDay[weekday] ?? <String>{};

    final applicableRiders = _roster.where((r) => _riderApplicable(r, day, weekday)).toList();
    final presentRiders = applicableRiders.where((r) => present.contains(r.userName)).toList()
      ..sort((a, b) => a.userName.compareTo(b.userName));
    final absentRiders = applicableRiders.where((r) => !present.contains(r.userName)).toList()
      ..sort((a, b) => a.userName.compareTo(b.userName));

    final dateLabel = DateFormat('dd MMM').format(day);
    final isToday = _isSameDate(day, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(
            isToday ? Icons.today_rounded : Icons.event_note_rounded,
            color: theme.colorScheme.primary,
          ),
          title: Row(
            children: [
              Text(
                '$weekday, $dateLabel',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Today', style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${presentRiders.length} present · ${absentRiders.length} absent',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          children: [
            if (applicableRiders.isEmpty)
              Text(
                'No riders were scheduled for this day.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else ...[
              _buildRiderGroup(
                theme: theme,
                title: 'Present',
                icon: Icons.check_circle_rounded,
                color: AppTheme.success,
                riders: presentRiders,
              ),
              const SizedBox(height: 14),
              _buildRiderGroup(
                theme: theme,
                title: 'Absent',
                icon: Icons.cancel_rounded,
                color: AppTheme.danger,
                riders: absentRiders,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRiderGroup({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color color,
    required List<_RiderInfo> riders,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '$title (${riders.length})',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        riders.isEmpty
            ? Text(
                'None',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: riders
                    .map((r) => Chip(
                          avatar: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Text(
                              r.userName.isNotEmpty ? r.userName[0].toUpperCase() : '?',
                              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          label: Text(r.userName),
                          backgroundColor: color.withValues(alpha: 0.08),
                          side: BorderSide(color: color.withValues(alpha: 0.3)),
                        ))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 72,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Attendance Data Yet',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Absenteeism will populate automatically once riders start clocking out.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 20),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}