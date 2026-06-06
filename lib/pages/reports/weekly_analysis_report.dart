import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyAnalysisReport extends StatefulWidget {
  const WeeklyAnalysisReport({super.key});

  @override
  State<WeeklyAnalysisReport> createState() => _WeeklyAnalysisReportState();
}

class _WeeklyAnalysisReportState extends State<WeeklyAnalysisReport> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _weeksData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWeeks();
    _cleanupOldWeeks();
  }

  Future<void> _cleanupOldWeeks() async {
    try {
      final fourMonthsAgo = DateTime.now().subtract(const Duration(days: 120));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('deviations')
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      int deletedCount = 0;
      
      for (var doc in snapshot.docs) {
        final weekLabel = doc.id;
        final startDate = _extractStartDate(weekLabel); // ✅ Reuse exactly!
        
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
    final startPart = weekLabel.substring(open + 1, toIndex).trim(); // "08 Dec 2025"
    try {
      return _weekLabelFormat.parse(startPart);
    } catch (_) {
      return DateTime(1970);
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '-';
    final numValue = double.tryParse(value.toString()) ?? 0.0;
    return NumberFormat('#,##0.00').format(numValue);
  }

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
          'Weekly Analysis Report',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
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
            padding: const EdgeInsets.all(24),
            itemCount: sortedWeeks.length,
            itemBuilder: (context, weekIndex) {
              final weekEntry = sortedWeeks[weekIndex];  // ✅ Direct index access
              final weekName = weekEntry.key;
              final usersMap = weekEntry.value as Map<String, dynamic>;
              
              return _buildWeekSection(weekName, usersMap);
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
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Weekly Data Available',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Text(
              'Weekly deviation analysis will appear here when data is available.',
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

  Widget _buildWeekSection(String weekName, Map<String, dynamic> usersMap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Card(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: _buildWeekExpansionTile(weekName, usersMap),
      ),
    );
  }

  Widget _buildWeekExpansionTile(String weekName, Map<String, dynamic> usersMap) {
    return ExpansionTile(
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo[400]!, Colors.indigo[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.calendar_month,
          color: Colors.white,
          size: 28,
        ),
      ),
      title: Text(
        weekName,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        '${usersMap.length} users • ${usersMap.values.expand((user) => (user as Map).values).length} days',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      childrenPadding: const EdgeInsets.all(20),
      collapsedBackgroundColor: Colors.transparent,
      children: usersMap.entries
          .map((userEntry) => _buildUserCard(userEntry))
          .toList(),
    );
  }

  Widget _buildUserCard(MapEntry<String, dynamic> userEntry) {
    final userName = userEntry.key;
    final daysMap = userEntry.value as Map<String, dynamic>;
    
    // Calculate totals for this user
    double totalGross = 0, totalNet = 0, totalGrossDev = 0, totalNetGrossDiff = 0;
    
    for (final dayEntry in daysMap.entries) {
      final dayData = dayEntry.value as Map<String, dynamic>;
      totalGross += (dayData['grossIncome'] ?? 0).toDouble();
      totalNet += (dayData['netIncome'] ?? 0).toDouble();
      totalGrossDev += (dayData['grossDeviation'] ?? 0).toDouble();
      totalNetGrossDiff += (dayData['netGrossDifference'] ?? 0).toDouble();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Reduced from 16
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ExpansionTile(
          leading: CircleAvatar(
            radius: 20, // Reduced from 24
            backgroundColor: Colors.green[400],
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          title: Text(
            userName,
            style: const TextStyle(
              fontSize: 16, // Reduced from 18
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Wrap( // Changed from Row
            spacing: 6,
            runSpacing: 2,
            children: [
              _buildMetricChip('Gross', totalGross, Colors.green),
              _buildMetricChip('Net', totalNet, Colors.blue),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16), // Tightened
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          children: [
            _buildUserDataTable(daysMap, totalGross, totalNet, totalGrossDev, totalNetGrossDiff),
          ],
        ),
      ),
    );

  
  }

  Widget _buildMetricChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: ${_formatNumber(value)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildUserDataTable(
    Map<String, dynamic> daysMap,
    double totalGross,
    double totalNet,
    double totalGrossDev,
    double totalNetGrossDiff,
  ) {
    final List<String> dayOrder = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final sortedEntries = daysMap.entries.toList()
      ..sort((a, b) {
        final ia = dayOrder.indexOf(a.key);
        final ib = dayOrder.indexOf(b.key);
        // Unknown day names go to the end, keep their relative order
        if (ia == -1 && ib == -1) return 0;
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });

    final List<DataRow> rows = [];

    for (final dayEntry in sortedEntries) {
      final day = dayEntry.key;
      final mapData = dayEntry.value as Map<String, dynamic>;
      final gross = (mapData['grossIncome'] ?? 0).toDouble();
      final net = (mapData['netIncome'] ?? 0).toDouble();
      final grossDev = (mapData['grossDeviation'] ?? 0).toDouble();
      final netGrossDiff = (mapData['netGrossDifference'] ?? 0).toDouble();

      rows.add(
        DataRow(
          cells: [
            DataCell(Text(day)),
            DataCell(Text(_formatNumber(gross))),
            DataCell(Text(_formatNumber(net))),
            DataCell(Text(_formatNumber(grossDev))),
            DataCell(Text(_formatNumber(netGrossDiff))),
          ],
        ),
      );
    }

    // Add TOTAL row (as you already had, without `decoration`)
    rows.add(
      DataRow(
        cells: [
          const DataCell(
            Text(
              'TOTAL',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          DataCell(
            Text(
              _formatNumber(totalGross),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          DataCell(
            Text(
              _formatNumber(totalNet),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          DataCell(
            Text(
              _formatNumber(totalGrossDev),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          DataCell(
            Text(
              _formatNumber(totalNetGrossDiff),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 48,
        columns: const [
          DataColumn(label: Text('Day')),
          DataColumn(label: Text('Gross')),
          DataColumn(label: Text('Net')),
          DataColumn(label: Text('Gross Dev')),
          DataColumn(label: Text('Net-Gross Diff')),
        ],
        rows: rows,
      ),
    );
  }



}
