import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Small helpers (UI only)
// ---------------------------------------------------------------------------

final NumberFormat _whole = NumberFormat('#,##0');

double _num(dynamic v) =>
    double.tryParse(v?.toString().replaceAll(',', '') ?? '') ?? 0.0;

/// "KSh 12,345" for numbers; anything that isn't a number is shown as-is
/// (e.g. "5 hrs 20 mins").
String _ksh(dynamic v) {
  final raw = v?.toString() ?? '';
  if (raw.isEmpty) return raw;
  final d = double.tryParse(raw.replaceAll(',', ''));
  if (d == null || d.isNaN || d.isInfinite) return raw;
  return 'KSh ${_whole.format(d)}';
}

Color _gain(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF4ADE80)
    : const Color(0xFF15803D);

Color _loss(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFFF87171)
    : const Color(0xFFB91C1C);

const Color _gold = Color(0xFFC9A227);
const Color _silver = Color(0xFF8E9AAB);
const Color _bronze = Color(0xFFB36B3A);

/// The clock-out address, or null when there is no location / no place name.
String? _addressOf(dynamic loc) {
  if (loc is! Map) return null;
  final a = loc['address']?.toString().trim();
  return (a == null || a.isEmpty) ? null : a;
}

String _coords(GeoPoint g) {
  String part(double v, String pos, String neg) =>
      '${v.abs().toStringAsFixed(4)}° ${v >= 0 ? pos : neg}';
  return '${part(g.latitude, 'N', 'S')}, ${part(g.longitude, 'E', 'W')}';
}

Color? _medalFor(int rank) {
  switch (rank) {
    case 1:
      return _gold;
    case 2:
      return _silver;
    case 3:
      return _bronze;
  }
  return null;
}

/// Totals used to rank riders. Built from the user documents that are already
/// fetched, so ranking costs no extra reads.
class _RiderSummary {
  const _RiderSummary({
    required this.shifts,
    required this.gross,
    required this.net,
    this.recentGross = const [],
    this.lastAddress,
  });
  final int shifts;
  final double gross;
  final double net;

  /// Gross of the last (up to) 6 shifts, oldest first. Drives the trend line.
  final List<double> recentGross;

  /// Where the rider last clocked out, if that was recorded.
  final String? lastAddress;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class RiderDailyStatistics extends StatefulWidget {
  const RiderDailyStatistics({super.key});

  @override
  State<RiderDailyStatistics> createState() => _RiderDailyStatisticsState();
}

class _RiderDailyStatisticsState extends State<RiderDailyStatistics> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Map<String, dynamic>> _usersClockouts = {};
  Map<String, String> _usernames = {};
  final Map<String, _RiderSummary> _summaries = {};
  final Set<String> _fetchedUsers = {};
  bool _loadingUsers = true;

  /// true -> riders ranked by net income, false -> by gross income.
  bool _rankByNet = true;

  // Fields shown in each day card, in this order (only if present in the data)
  final Map<String, String> fieldLabels = {
    'grossIncome': 'Gross Income',
    'todaysInAppBalance': "Today's In-App Balance",
    'previousInAppBalance': 'Previous In-App Balance',
    'timeElapsed': 'Time Elapsed',
  };

  final List<String> displayOrder = [
    'grossIncome',
    'todaysInAppBalance',
    'previousInAppBalance',
    'timeElapsed',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('userRank', isEqualTo: 'Rider')
          .get();

      final Map<String, String> finalUsernames = {};
      final Map<String, _RiderSummary> summaries = {};

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final clockouts = data['clockouts'] as Map<String, dynamic>? ?? {};

        if (clockouts.isNotEmpty) {
          finalUsernames[doc.id] = data['userName'] ?? doc.id;

          double gross = 0, net = 0;
          final dated = <MapEntry<DateTime, Map>>[];
          for (final e in clockouts.values) {
            if (e is Map) {
              gross += _num(e['grossIncome']);
              net += _num(e['netIncome']);
              final ts = e['posted_at'];
              dated.add(MapEntry(ts is Timestamp ? ts.toDate() : DateTime(0), e));
            }
          }
          dated.sort((a, b) => a.key.compareTo(b.key)); // oldest -> newest
          final recent =
              dated.length > 6 ? dated.sublist(dated.length - 6) : dated;

          summaries[doc.id] = _RiderSummary(
            shifts: clockouts.length,
            gross: gross,
            net: net,
            recentGross: [for (final d in recent) _num(d.value['grossIncome'])],
            lastAddress: dated.isEmpty
                ? null
                : _addressOf(dated.last.value['clockoutLocation']),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _usernames = finalUsernames;
        _summaries
          ..clear()
          ..addAll(summaries);
        _loadingUsers = false;
      });
    } catch (e) {
      debugPrint('Failed to load riders: $e');
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _fetchClockoutsForUser(String userId) async {
    if (_fetchedUsers.contains(userId)) return;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data();
    final clockouts = data?['clockouts'] as Map<String, dynamic>? ?? {};

    // This should never be empty because we filtered earlier.
    if (clockouts.isEmpty) {
      _fetchedUsers.add(userId);
      return;
    }

    final entriesWithDate = clockouts.entries.map((e) {
      final dayData = Map<String, dynamic>.from(e.value);
      final ts = dayData['posted_at'] as Timestamp?;
      final date = ts?.toDate() ?? DateTime(0);
      return MapEntry(e.key, {...dayData, 'dateTime': date});
    }).toList();

    entriesWithDate.sort((a, b) => (b.value['dateTime'] as DateTime)
        .compareTo(a.value['dateTime'] as DateTime));

    if (!mounted) return;
    setState(() {
      _usersClockouts[userId] = Map.fromEntries(entriesWithDate);
      _fetchedUsers.add(userId);
    });
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('dd MMM yyyy • HH:mm').format(ts.toDate());
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Rider Daily Statistics',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: _loadingUsers
          ? Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _usernames.isEmpty
              ? _buildEmptyState(context)
              : Builder(
                  builder: (context) {
                    // Show all users initially, filter only those we've checked
                    final entries = _usernames.entries.where((entry) {
                      final clockouts = _usersClockouts[entry.key];
                      // Show: users with clockouts OR users not yet loaded
                      return clockouts == null || clockouts.isNotEmpty;
                    }).toList();

                    if (entries.isEmpty) return _buildEmptyState(context);

                    double valueOf(String id) {
                      final s = _summaries[id];
                      if (s == null) return 0;
                      return _rankByNet ? s.net : s.gross;
                    }

                    // Ranked, best first
                    entries.sort(
                        (a, b) => valueOf(b.key).compareTo(valueOf(a.key)));
                    final top = entries.isEmpty ? 0.0 : valueOf(entries.first.key);

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
                      itemCount: entries.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildHeader(context, entries.length);
                        }
                        final i = index - 1;
                        final userId = entries[i].key;
                        final value = valueOf(userId);

                        return _RiderTile(
                          key: ValueKey(userId),
                          rank: i + 1,
                          username: entries[i].value,
                          summary: _summaries[userId],
                          rankByNet: _rankByNet,
                          fraction: top <= 0 ? 0 : (value / top).clamp(0.0, 1.0),
                          clockouts: _usersClockouts[userId],
                          onOpen: () => _fetchClockoutsForUser(userId),
                          dayBuilder: (day) => _DayCard(
                            dayKey: day.key,
                            details: Map<String, dynamic>.from(day.value as Map),
                            postedAt: _formatDate(
                                (day.value as Map)['posted_at'] as Timestamp?),
                            displayOrder: displayOrder,
                            fieldLabels: fieldLabels,
                            isLatest: day.key ==
                                _usersClockouts[userId]!.keys.first,
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildHeader(BuildContext context, int riderCount) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$riderCount ${riderCount == 1 ? 'RIDER' : 'RIDERS'} · RANKED',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
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
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No riders found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Rider shifts will appear here once clock-outs are recorded.',
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
}

// ---------------------------------------------------------------------------
// One ranked rider. Tap to load and show their shifts.
// ---------------------------------------------------------------------------

class _RiderTile extends StatefulWidget {
  const _RiderTile({
    super.key,
    required this.rank,
    required this.username,
    required this.summary,
    required this.rankByNet,
    required this.fraction,
    required this.clockouts,
    required this.onOpen,
    required this.dayBuilder,
  });

  final int rank;
  final String username;
  final _RiderSummary? summary;
  final bool rankByNet;
  final double fraction;
  final Map<String, dynamic>? clockouts;
  final VoidCallback onOpen;
  final Widget Function(MapEntry<String, dynamic> day) dayBuilder;

  @override
  State<_RiderTile> createState() => _RiderTileState();
}

class _RiderTileState extends State<_RiderTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final medal = _medalFor(widget.rank);
    final barColor = medal ?? scheme.primary;
    final s = widget.summary;

    final primary = s == null ? 0.0 : (widget.rankByNet ? s.net : s.gross);
    final secondaryLabel = widget.rankByNet ? 'Gross' : 'Net';
    final secondary = s == null ? 0.0 : (widget.rankByNet ? s.gross : s.net);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.rank == 1
              ? _gold.withValues(alpha: 0.55)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => _open = !_open);
              if (_open) widget.onOpen();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
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
                                widget.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (s != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${s.shifts} ${s.shifts == 1 ? 'shift' : 'shifts'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        _AnimatedBar(
                            fraction: widget.fraction, color: barColor),
                        const SizedBox(height: 6),
                        if (s != null)
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
                                text: _whole.format(secondary),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ]),
                          ),
                        if (s != null && s.recentGross.length >= 2) ...[
                          const SizedBox(height: 10),
                          _GrossTrend(values: s.recentGross),
                        ],
                        if (s?.lastAddress != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  s!.lastAddress!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (s != null)
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
                          _whole.format(primary),
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
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                          child: Text(
                            'SHIFTS · NEWEST FIRST',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (widget.clockouts == null ||
                            widget.clockouts!.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Loading shifts...',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...widget.clockouts!.entries.map(widget.dayBuilder),
                      ],
                    ),
                  )
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
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasMedal ? medal : scheme.surfaceContainerHighest,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: hasMedal ? Colors.white : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 6,
          color: color,
          backgroundColor: color.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One shift (one clock-out).
// ---------------------------------------------------------------------------

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.dayKey,
    required this.details,
    required this.postedAt,
    required this.displayOrder,
    required this.fieldLabels,
    required this.isLatest,
  });

  final String dayKey;
  final Map<String, dynamic> details;
  final String postedAt;
  final List<String> displayOrder;
  final Map<String, String> fieldLabels;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final hasNet = details.containsKey('netIncome');
    final net = _num(details['netIncome']);
    final netColor = net < 0 ? _loss(context) : scheme.onSurface;
    final shift = details['shift']?.toString().toLowerCase();
    final hasShift = shift == 'day' || shift == 'night';

    // Metrics that exist, in the configured order
    final metrics = <MapEntry<String, String>>[
      for (final key in displayOrder)
        if (details[key] != null)
          MapEntry(fieldLabels[key] ?? key, _ksh(details[key])),
    ];

    final expenses = details['expenses'] is Map
        ? Map<String, dynamic>.from(details['expenses'] as Map)
        : <String, dynamic>{};
    final expenseTotal =
        expenses.values.fold<double>(0, (s, v) => s + _num(v));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: date + net
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dayKey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (hasShift) ...[
                          const SizedBox(width: 8),
                          _ShiftChip(night: shift == 'night'),
                        ],
                        if (isLatest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LATEST',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (postedAt.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        postedAt,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasNet)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NET',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _ksh(details['netIncome']),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: netColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),
          // _LocationStrip(location: details['clockoutLocation']),

          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            // Two metrics per row
            for (var i = 0; i < metrics.length; i += 2)
              Padding(
                padding: EdgeInsets.only(
                    bottom: i + 2 < metrics.length ? 12 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Metric(entry: metrics[i])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: i + 1 < metrics.length
                          ? _Metric(entry: metrics[i + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],

          if (expenses.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'EXPENSES',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  'KSh ${_whole.format(expenseTotal)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in expenses.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${e.key}  ',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: _whole.format(_num(e.value)),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.entry});
  final MapEntry<String, String> entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.key.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            height: 1.25,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          entry.value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Gross trend for the last (up to) 6 shifts. Shown on the collapsed rider card.
// ---------------------------------------------------------------------------

class _GrossTrend extends StatelessWidget {
  const _GrossTrend({required this.values});
  final List<double> values; // oldest first

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final up = values.last >= values.first;
    final color = up ? _gain(context) : _loss(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'GROSS · LAST ${values.length} SHIFTS',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Icon(
              up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              _whole.format(values.last),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 30,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => CustomPaint(
              painter: _SparklinePainter(
                values: values,
                color: color,
                progress: t,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final double progress; // 0..1 reveal animation

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    const pad = 3.0;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          pad + w * i / (values.length - 1),
          // flat series sits in the middle
          range == 0
              ? size.height / 2
              : pad + h * (1 - (values[i] - minV) / range),
        ),
    ];

    // Clip so the line "draws in" from the left.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final p in pts.take(pts.length - 1)) {
      canvas.drawCircle(p, 2, Paint()..color = color.withValues(alpha: 0.6));
    }
    canvas.restore();

    // Latest value, emphasised (drawn once the line has fully appeared).
    if (progress >= 0.98) {
      canvas.drawCircle(pts.last, 4.5, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(pts.last, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.color != color || old.values != values;
}

// ---------------------------------------------------------------------------
// Shift chip (Day / Night)
// ---------------------------------------------------------------------------

class _ShiftChip extends StatelessWidget {
  const _ShiftChip({required this.night});
  final bool night;

  @override
  Widget build(BuildContext context) {
    final color = night ? Colors.indigo[400]! : Colors.amber[800]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            night ? 'NIGHT' : 'DAY',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Where the rider clocked out. Copes with every shape the data can take:
//   - no clockoutLocation at all (older records, or batteries flow)
//   - status "found" with an address
//   - coordinates but no place name
//   - status "not_found" with only a reason
// ---------------------------------------------------------------------------

class _LocationStrip extends StatelessWidget {
  const _LocationStrip({required this.location});
  final dynamic location;

  static const Map<String, String> _reasons = {
    'gps_off': "Phone's GPS was off",
    'permission_blocked': 'Location permission was blocked',
    'permission_denied': 'Location permission was denied',
    'no_signal': 'No GPS signal',
    'error': 'Location could not be read',
    'unavailable': 'Location unavailable',
    'address_unknown': 'Place name unavailable',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final loc = location is Map ? Map<String, dynamic>.from(location as Map) : null;
    final address = _addressOf(loc);
    final gp = loc?['geoPoint'];
    final coords = gp is GeoPoint ? _coords(gp) : null;
    final accuracy = loc?['accuracyMeters'] is num
        ? (loc!['accuracyMeters'] as num).round()
        : null;
    final mocked = loc?['isMocked'] == true;
    final reason = _reasons[loc?['reason']?.toString()];

    final IconData icon;
    final Color color;
    final String title;
    final String? sub;

    if (address != null) {
      icon = Icons.location_on;
      color = scheme.primary;
      title = address;
      sub = [
        if (accuracy != null) '±$accuracy m',
        if (coords != null) coords,
      ].join(' · ');
    } else if (coords != null) {
      icon = Icons.location_on_outlined;
      color = scheme.onSurfaceVariant;
      title = reason ?? 'Place name unavailable';
      sub = [
        if (accuracy != null) '±$accuracy m',
        coords,
      ].join(' · ');
    } else if (loc != null) {
      icon = Icons.location_off_outlined;
      color = Colors.orange[800]!;
      title = reason ?? 'Location could not be found';
      sub = null;
    } else {
      icon = Icons.location_off_outlined;
      color = scheme.onSurfaceVariant;
      title = 'No location recorded';
      sub = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: address != null ? FontWeight.w700 : FontWeight.w600,
                    color: address != null
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (mocked) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _loss(context).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 12, color: _loss(context)),
                  const SizedBox(width: 3),
                  Text(
                    'MOCKED',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: _loss(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
