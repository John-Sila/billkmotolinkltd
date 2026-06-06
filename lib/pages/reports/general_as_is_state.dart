import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GeneralStateReport extends StatefulWidget {
  const GeneralStateReport({super.key});

  @override
  State<GeneralStateReport> createState() => _GeneralStateReportState();
}

class _GeneralStateReportState extends State<GeneralStateReport> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;

  // weekName → aggregated {gross, net, expense, chartData}
  List<MapEntry<String, Map<String, dynamic>>> _sortedWeeklyTotals = [];

  @override
  void initState() {
    super.initState();
    _fetchWeeks();
  }

  Future<void> _fetchWeeks() async {
    try {
      final snapshot = await _firestore.collection('deviations').get();

      final Map<String, Map<String, dynamic>> results = {};

      for (var doc in snapshot.docs) {
        final weekName = doc.id;
        final weekData = doc.data();

        double weekGross = 0;
        double weekNet = 0;
        double weekExpense = 0;

        final List<FlSpot> grossSpots = [];
        final List<FlSpot> netSpots = [];
        final List<FlSpot> expenseSpots = [];

        double x = 0;

        for (final userEntry in weekData.entries) {
          final userDays = userEntry.value as Map<String, dynamic>;

          for (final dayEntry in userDays.entries) {
            final day = dayEntry.value as Map<String, dynamic>;

            final gross = _safeDouble(day['grossIncome']);
            final net = _safeDouble(day['netIncome']);
            final exp = gross - net;

            weekGross += gross;
            weekNet += net;
            weekExpense += exp;

            grossSpots.add(FlSpot(x, gross));
            netSpots.add(FlSpot(x, net));
            expenseSpots.add(FlSpot(x, exp));

            x++;
          }
        }

        results[weekName] = {
          'gross': weekGross,
          'net': weekNet,
          'expense': weekExpense,
          'grossChart': grossSpots,
          'netChart': netSpots,
          'expenseChart': expenseSpots,
        };
      }

      // SORT WEEKS by week number (descending - latest first)
      DateTime? _parseWeekDate(String weekKey) {
        try {
          // Extract "12 Jan 2026" from "Week 3 (12 Jan 2026 to 18 Jan 2026)"
          final match = RegExp(r'\((\d{1,2})\s+(\w{3})\s+(\d{4})').firstMatch(weekKey);
          
          if (match == null) return null;
          
          final day = int.tryParse(match.group(1) ?? '0');
          final monthStr = (match.group(2) ?? '').toLowerCase();
          final year = int.tryParse(match.group(3) ?? '0');
          
          if (day == null || year == null) return null;
          
          const months = {
            'jan': DateTime.january, 'feb': DateTime.february, 'mar': DateTime.march,
            'apr': DateTime.april, 'may': DateTime.may, 'jun': DateTime.june,
            'jul': DateTime.july, 'aug': DateTime.august, 'sep': DateTime.september,
            'oct': DateTime.october, 'nov': DateTime.november, 'dec': DateTime.december,
          };
          
          final month = months[monthStr] ?? DateTime.january;
          return DateTime(year, month, day);
        } catch (e) {
          return null;
        }
      }

      final sortedEntries = results.entries.toList()
        ..sort((a, b) {
          final dateA = _parseWeekDate(a.key);
          final dateB = _parseWeekDate(b.key);
          
          // ✅ NULL-SAFE COMPARE
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1; // Put nulls at end
          if (dateB == null) return -1;
          
          return dateB.compareTo(dateA); // ✅ Safe now!
        });

      

      if (mounted) {
        setState(() {
          _sortedWeeklyTotals = sortedEntries;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  double _safeDouble(dynamic n) {
    if (n == null) return 0;
    if (n is num) return n.toDouble();
    final parsed = double.tryParse(n.toString());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return 0;
    return parsed;
  }

  String _formatCurrency(double value) {
    return NumberFormat('#,###', 'en_KE').format(value);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'General As-Is State',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWeeks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sortedWeeklyTotals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No weekly data available', style: theme.textTheme.titleLarge),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _sortedWeeklyTotals.length,
                  itemBuilder: (context, index) {
                    final entry = _sortedWeeklyTotals[index];
                    return _buildWeekCard(entry.key, entry.value, theme, index);
                  },
                ),
    );
  }

  Widget _buildWeekCard(String weekName, Map<String, dynamic> totals, ThemeData theme, int index) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: theme.colorScheme.surface,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              theme.colorScheme.primary.withValues(alpha: 0.2),
              theme.colorScheme.secondary.withValues(alpha: 0.2),
            ]),
            shape: BoxShape.circle,
          ),
          child: Text('${index + 1}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        ),
        title: Text(
          weekName,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('KSh ${_formatCurrency(totals['gross'])} total', style: theme.textTheme.bodyMedium),
        childrenPadding: const EdgeInsets.all(24),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
        children: [
          _buildTotalsSection(totals, theme),
          const SizedBox(height: 24),
          _buildChartSection("📈 Gross Income", totals["grossChart"], theme, Colors.green.shade500),
          const SizedBox(height: 20),
          _buildChartSection("💰 Net Income", totals["netChart"], theme, Colors.blue.shade500),
          const SizedBox(height: 20),
          _buildChartSection("💸 Expenses", totals["expenseChart"], theme, Colors.orange.shade500),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(Map<String, dynamic> totals, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.withValues(alpha: 0.05), Colors.blue.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green.shade600, size: 28),
              const SizedBox(width: 12),
              Text('Weekly Totals', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          // STACKED VERTICALLY - Gross on top, Net below
          _metricRow("Total Gross", totals["gross"], theme, Colors.green.shade500, Icons.trending_up_rounded),
          const SizedBox(height: 16),
          _metricRow("Total Net", totals["net"], theme, Colors.blue.shade500, Icons.account_balance_wallet_rounded),
          const SizedBox(height: 16),
          _metricRow("Total Expenses", totals["expense"], theme, Colors.orange.shade500, Icons.receipt_long_rounded),
        ],
      ),
    );
  }

  Widget _metricRow(String label, double value, ThemeData theme, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                Text(
                  'KSh ${_formatCurrency(value)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildChartSection(String title, List<FlSpot> spots, ThemeData theme, Color lineColor) {
  if (spots.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics_outlined, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Text('No data for $title', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  // Adaptive colors based on theme brightness
  final isDark = theme.brightness == Brightness.dark;
  final gridColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
  final borderColor = isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2);
  final bgColor = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.9);

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lineColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.show_chart, color: lineColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: lineColor)),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: gridColor,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  curveSmoothness: 0.4,
                  spots: spots,
                  barWidth: 4,
                  color: lineColor,
                  shadow: Shadow(
                    color: lineColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 6,
                      color: lineColor,
                      strokeWidth: 3,
                      strokeColor: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        lineColor.withValues(alpha: isDark ? 0.3 : 0.4),
                        lineColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}



}
