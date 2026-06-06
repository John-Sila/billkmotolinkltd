import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RiderDailyStatistics extends StatefulWidget {
  const RiderDailyStatistics({super.key});

  @override
  State<RiderDailyStatistics> createState() => _RiderDailyStatisticsState();
}

class _RiderDailyStatisticsState extends State<RiderDailyStatistics> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Map<String, dynamic>> _usersClockouts = {};
  Map<String, String> _usernames = {};
  final Set<String> _fetchedUsers = {};
  bool _loadingUsers = true;

  // Ordered and filtered field labels - ONLY wanted fields
  final Map<String, String> fieldLabels = {
    'grossIncome': 'Gross Income',
    'netIncome': 'Net Income',
    'mileageDifference': 'Mileage Coverage',
    'todaysInAppBalance': "Today's In-App Balance",
    'previousInAppBalance': 'Previous In-App Balance',
    'timeElapsed': 'Time Elapsed',
  };

  // Define the exact display order
  final List<String> displayOrder = [
    'grossIncome',
    'netIncome',
    'mileageDifference',
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
    final usersSnapshot = await _firestore
      .collection('users')
      .where('userRank', isEqualTo: 'Rider')
      .get();

    final Map<String, String> finalUsernames = {};

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final clockouts = data['clockouts'] as Map<String, dynamic>? ?? {};

      if (clockouts.isNotEmpty) {
        finalUsernames[doc.id] = data['userName'] ?? doc.id;
      }
    }

    setState(() {
      _usernames = finalUsernames;
      _loadingUsers = false;
    });
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

    entriesWithDate.sort(
        (a, b) => (b.value['dateTime'] as DateTime).compareTo(a.value['dateTime'] as DateTime));

    setState(() {
      _usersClockouts[userId] = Map.fromEntries(entriesWithDate);
      _fetchedUsers.add(userId);
    });
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('dd MMM yyyy • HH:mm').format(ts.toDate());
  }

  String _formatValue(String value, String fieldKey) {
    if (value.isEmpty) return value;

    double? numValue = double.tryParse(value.replaceAll(',', ''));

    // Guard clause: Bail out if NaN or Infinity
    if (numValue == null || numValue.isNaN || numValue.isInfinite) {
      return value; // return raw string safely
    }

    // KM fields
    if (fieldKey == 'clockinMileage' ||
        fieldKey == 'clockoutMileage' ||
        fieldKey == 'mileageDifference') {
      return '${_formatNumberWithCommas(numValue.toInt())} KM';
    }

    // Currency fields
    return 'KSh ${_formatNumberWithCommas(numValue.toInt())}';
  }


  String _formatNumberWithCommas(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Rider Daily Statistics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _fetchUsers,
          ),
        ],
      ),




body: _loadingUsers
    ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
    : _usernames.isEmpty
        ? _buildEmptyState(context)
        : Builder(
            builder: (context) {
              // Show all users initially, filter only those we've checked
              final filteredEntries = _usernames.entries.where((entry) {
                final userId = entry.key;
                final clockouts = _usersClockouts[userId];
                // Show: users with clockouts OR users not yet loaded
                return clockouts == null || clockouts.isNotEmpty;
              }).toList();

              if (filteredEntries.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filteredEntries.length,
                itemBuilder: (context, index) {
                  final userEntry = filteredEntries[index];
                  final userId = userEntry.key;
                  final username = userEntry.value;
                  final userClockouts = _usersClockouts[userId];

                  return _buildRiderCard(username, userId, userClockouts, theme);
                },
              );
            },
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
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Riders Found',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'No rider data available at the moment.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderCard(String username, String userId, Map<String, dynamic>? clockouts, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Card(
        elevation: 8,
        shadowColor: theme.shadowColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: theme.cardColor,
        child: ExpansionTile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              color: theme.colorScheme.onPrimary,
              size: 28,
            ),
          ),
          title: Text(
            username,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            clockouts == null ? 'Tap to load data' : '${clockouts.length} shifts',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onExpansionChanged: (expanded) {
            if (expanded) _fetchClockoutsForUser(userId);
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          childrenPadding: const EdgeInsets.all(24),
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: clockouts == null || clockouts.isEmpty
              ? [
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading shifts...',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              : clockouts.entries
                  .map((dayEntry) => _buildDayCard(dayEntry, theme))
                  .toList(),
        ),
      ),
    );
  }

  Widget _buildDayCard(MapEntry<String, dynamic> dayEntry, ThemeData theme) {
    final day = dayEntry.key;
    final details = dayEntry.value as Map<String, dynamic>;
    final postedAt = _formatDate(details['posted_at'] as Timestamp?);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Card(
        elevation: 4,
        shadowColor: theme.shadowColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                      theme.colorScheme.primaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.today_outlined, 
                      color: theme.colorScheme.onPrimary, 
                      size: 20
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            postedAt,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ONLY display wanted fields in exact order
              _buildMetricsList(details, theme),

              // Expenses section
              if (details['expenses'] != null) ...[
                const SizedBox(height: 20),
                _buildExpensesSection(details['expenses'] as Map<String, dynamic>, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsList(Map<String, dynamic> details, ThemeData theme) {
    return Column(
      children: displayOrder.map((fieldKey) {
        // Only show if field exists in data
        if (details.containsKey(fieldKey)) {
          final label = fieldLabels[fieldKey] ?? fieldKey;
          final value = details[fieldKey].toString();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatValue(value, fieldKey),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink(); // Hide missing fields
      }).where((widget) => widget != const SizedBox.shrink()).toList(),
    );
  }

  Widget _buildExpensesSection(Map<String, dynamic> expenses, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: theme.colorScheme.onTertiaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Expenses',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...expenses.entries
              .map((expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            expense.key,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          _formatValue(expense.value.toString(), 'expenses'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ))
              ,
        ],
      ),
    );
  }
}
