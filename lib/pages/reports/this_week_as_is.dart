import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ThisWeekStateReport extends StatefulWidget {
  const ThisWeekStateReport({super.key});

  @override
  State<ThisWeekStateReport> createState() => _ThisWeekStateReportState();
}

class _ThisWeekStateReportState extends State<ThisWeekStateReport> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  
  // This week's data only
  Map<String, dynamic>? _thisWeekData;
  String? _currentWeekLabel;
  
  // Track selected metric for detailed view
  String? _selectedMetric;
  String? _selectedDay;

  @override
  void initState() {
    super.initState();
    _fetchThisWeek();
  }

  String getWeekLabel(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
    final formatter = DateFormat("dd MMM yyyy");
    return "Week $weekNumber (${formatter.format(firstDayOfWeek)} to ${formatter.format(lastDayOfWeek)})";
  }

  String weekdayName() {
    return DateFormat("EEEE", "en_US").format(DateTime.now());
  }

  Future<void> _fetchThisWeek() async {
    try {
      final now = DateTime.now();
      final weekLabel = getWeekLabel(now);
      
      setState(() {
        _currentWeekLabel = weekLabel;
        _loading = true;
      });

      final doc = await _firestore.collection('deviations').doc(weekLabel).get();
      
      if (mounted) {
        setState(() {
          _thisWeekData = doc.data();
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

  String _normalizePhoneNumber(String phone) {
  // Remove all non-digits
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  
  switch (digits.length) {
    case 9:
      // 9 digits → Add Kenya country code
      return '+254$digits';
    
    case 10:
      // 10 digits → Omit first letter (0), add +254
      if (digits.startsWith('0')) {
        return '+254${digits.substring(1)}';
      }
      return '+254$digits';
    
    case 12:
      // 12 digits → Already has country code, use as-is
      return digits;
    
    default:
      // Anything else → Return as-is (might already be correct)
      return phone;
  }
}

  Map<String, double> _calculateTotals() {
    if (_thisWeekData == null) return {'gross': 0, 'net': 0, 'expense': 0};
    
    double gross = 0, net = 0;
    
    for (final userEntry in _thisWeekData!.entries) {
      final userDays = userEntry.value as Map<String, dynamic>;
      for (final dayEntry in userDays.entries) {
        final day = dayEntry.value as Map<String, dynamic>;
        gross += _safeDouble(day['grossIncome']);
        net += _safeDouble(day['netIncome']);
        // ✅ EXPENSE = GROSS - NET (calculated, not from field)
      }
    }
    
    final expense = gross - net; // ✅ Fixed calculation
    
    return {'gross': gross, 'net': net, 'expense': expense};
  }

  List<FlSpot> _buildDailyTrend(String metric) {
    if (_thisWeekData == null) return [];
    
    final List<FlSpot> spots = [];
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    double x = 0;
    
    for (final userEntry in _thisWeekData!.entries) {
      final userDays = userEntry.value as Map<String, dynamic>;
      for (int i = 0; i < weekdays.length; i++) {
        final dayName = weekdays[i];
        final dayData = userDays[dayName];
        if (dayData != null) {
          double value = 0;
          switch (metric) {
            case 'gross':
              value = _safeDouble(dayData['grossIncome']);
              break;
            case 'net':
              value = _safeDouble(dayData['netIncome']);
              break;
            case 'expense':
              // ✅ EXPENSE = GROSS - NET (calculated per day per user)
              final gross = _safeDouble(dayData['grossIncome']);
              final netIncome = _safeDouble(dayData['netIncome']);
              value = gross - netIncome;
              break;
          }
          spots.add(FlSpot(x, value));
        }
        x++;
      }
    }
    
    return spots;
  }

  Map<String, Map<String, double>> _getDayUserContributions(String dayName, String metric) {
    if (_thisWeekData == null) return {};
    
    final Map<String, Map<String, double>> contributions = {};
    
    for (final userEntry in _thisWeekData!.entries) {
      final userName = userEntry.key;
      final userDays = userEntry.value as Map<String, dynamic>;
      final dayData = userDays[dayName];
      
      if (dayData != null) {
        double value = 0;
        switch (metric) {
          case 'gross':
            value = _safeDouble(dayData['grossIncome']);
            break;
          case 'net':
            value = _safeDouble(dayData['netIncome']);
            break;
          case 'expense':
            // ✅ EXPENSE = GROSS - NET (calculated per user per day)
            final gross = _safeDouble(dayData['grossIncome']);
            final netIncome = _safeDouble(dayData['netIncome']);
            value = gross - netIncome;
            break;
        }
        
        if (value > 0) {
          contributions[userName] = {
            'amount': value,
            'percentage': 0,
          };
        }
      }
    }
    
    // Sort by amount descending
    return Map.fromEntries(
      contributions.entries.toList()
        ..sort((a, b) => b.value['amount']!.compareTo(a.value['amount']!))
    );
  }

  Future<void> _contactRider(String riderName, String action, double amount) async {
    final metricName = _selectedMetric![0].toUpperCase() + _selectedMetric!.substring(1);
      final hour = DateTime.now().hour;
      String greeting;
      if (hour < 12) {
        greeting = 'Good morning';
      } else if (hour < 17) {
        greeting = 'Good afternoon';
      } else {
        greeting = 'Good evening';
      }
    final message = '$greeting $riderName, '
        'Your $metricName on $_selectedDay: KSh ${_formatCurrency(amount)}\n';
    
    try {
      // query users/UIDs where userName matches riderName
      final querySnapshot = await _firestore
          .collection('users')
          .where('userName', isEqualTo: riderName)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User "$riderName" not found')),
          );
        }
        return;
      }
      
      // get first matching document
      final userDoc = querySnapshot.docs.first;
      final phone = _normalizePhoneNumber(userDoc.data()['phoneNumber']!.toString());
      
      switch (action) {
        case 'whatsapp':
          await _launchWhatsApp(phone, message);
          break;
        case 'call':
          await _launchPhoneCall(phone);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error contacting $riderName: $e')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot make calls from this device'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Phone call error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to make call: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = _calculateTotals();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentWeekLabel ?? 'This Week',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchThisWeek,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _thisWeekData == null || _thisWeekData!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No data for this week', style: theme.textTheme.titleLarge),
                    ],
                  ),
                )
              : _selectedMetric != null && _selectedDay != null
                  ? _buildUserContributionsView(totals, theme)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTotalsSection(totals, theme),
                          const SizedBox(height: 24),
                          _buildTrendCharts(totals, theme),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildTotalsSection(Map<String, double> totals, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
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
              Text('Week Totals', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          _buildClickableMetric("Total Gross", totals['gross']!, theme, Colors.green.shade500, Icons.trending_up_rounded, 'gross'),
          const SizedBox(height: 16),
          _buildClickableMetric("Total Net", totals['net']!, theme, Colors.blue.shade500, Icons.account_balance_wallet_rounded, 'net'),
          const SizedBox(height: 16),
          _buildClickableMetric("Total Expenses", totals['expense']!, theme, Colors.orange.shade500, Icons.receipt_long_rounded, 'expense'),
        ],
      ),
    );
  }

  Widget _buildClickableMetric(String label, double value, ThemeData theme, Color color, IconData icon, String metric) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildDaySelectorModal(metric, theme),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color, height: 1.1),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }

  double _getDayTotal(String dayName, String metric) {
    if (_thisWeekData == null) return 0;
    
    double total = 0;
    
    for (final userEntry in _thisWeekData!.entries) {
      final userDays = userEntry.value as Map<String, dynamic>;
      final dayData = userDays[dayName];
      
      if (dayData != null) {
        switch (metric) {
          case 'gross':
            total += _safeDouble(dayData['grossIncome']);
            break;
          case 'net':
            total += _safeDouble(dayData['netIncome']);
            break;
          case 'expense':
            final gross = _safeDouble(dayData['grossIncome']);
            final netIncome = _safeDouble(dayData['netIncome']);
            total += (gross - netIncome);
            break;
        }
      }
    }
    
    return total;
  }

  Widget _buildDaySelectorModal(String metric, ThemeData theme) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final isDark = theme.brightness == Brightness.dark;
    
    // Metric display names and colors
    final metricInfo = {
      'gross': {'name': 'Gross Income', 'color': Colors.green.shade500},
      'net': {'name': 'Net Income', 'color': Colors.blue.shade500},
      'expense': {'name': 'Expenses', 'color': Colors.orange.shade500},
    };
    
    final metricName = metricInfo[metric]!['name'] as String;
    final metricColor = metricInfo[metric]!['color'] as Color;

    return Container(
      height: 500, // Increased height for better spacing
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // ✅ Theme adaptive
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with metric info
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              color: metricColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: metricColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.analytics, color: metricColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metricName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Tap day to see rider contributions',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: metricColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: metricColor.withValues(alpha: 0.7), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Week Total: KSh ${_formatCurrency(_calculateTotals()[metric]!)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: metricColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Days list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: weekdays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final day = weekdays[index];
                final dayTotal = _getDayTotal(day, metric);
                final hasData = dayTotal > 0;
                
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: hasData
                        ? () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedMetric = metric;
                              _selectedDay = day;
                            });
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      decoration: BoxDecoration(
                        color: hasData 
                            ? metricColor.withValues(alpha: 0.06)
                            : theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasData 
                              ? metricColor.withValues(alpha: 0.2)
                              : theme.colorScheme.outlineVariant!,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Day number circle
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: hasData 
                                  ? metricColor.withValues(alpha: 0.15)
                                  : theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasData 
                                    ? metricColor.withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasData ? metricColor : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Day info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  day,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'KSh ${_formatCurrency(dayTotal)}',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: hasData ? metricColor : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Status indicator
                          if (hasData)
                            Icon(
                              Icons.arrow_forward_ios,
                              color: metricColor.withValues(alpha: 0.7),
                              size: 18,
                            )
                          else
                            Icon(
                              Icons.schedule_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserContributionsView(Map<String, double> totals, ThemeData theme) {
    final contributions = _getDayUserContributions(_selectedDay!, _selectedMetric!);
    
    return Column(
      children: [
        AppBar(
          title: Text(
            '$_selectedDay ● ${_selectedMetric![0].toUpperCase()}${_selectedMetric!.substring(1)}', 
            style: const TextStyle(
              fontWeight: FontWeight.w800, // Extra heavy weight
              fontSize: 18, // Slightly larger for impact
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _selectedMetric = null;
              _selectedDay = null;
            }),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchThisWeek,
            ),
          ],
        ),
        Expanded(
          child: contributions.isEmpty
              ? Center(child: Text('No contributions for this day'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: contributions.length,
                  itemBuilder: (context, index) {
                    final userEntry = contributions.entries.elementAt(index);
                    final user = userEntry.key;
                    final data = userEntry.value;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(user[0].toUpperCase())),
                        title: Text(user, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('KSh ${_formatCurrency(data['amount']!)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // WhatsApp
                            GestureDetector(
                              onTap: () => _contactRider(user, 'whatsapp', data['amount']!),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.chat_outlined, color: Colors.green.shade600, size: 18),
                              ),
                            ),
                            // Phone Call
                            GestureDetector(
                              onTap: () => _contactRider(user, 'call', data['amount']!),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.call_outlined, color: Colors.blue.shade600, size: 18),
                              ),
                            ),
                          ],
                        ),

                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTrendCharts(Map<String, double> totals, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Trends', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _buildChartSection("📈 Gross Income", _buildDailyTrend('gross'), theme, Colors.green.shade500),
        const SizedBox(height: 20),
        _buildChartSection("💰 Net Income", _buildDailyTrend('net'), theme, Colors.blue.shade500),
        const SizedBox(height: 20),
        _buildChartSection("💸 Expenses", _buildDailyTrend('expense'), theme, Colors.orange.shade500),
      ],
    );
  }

  Widget _buildChartSection(String title, List<FlSpot> spots, ThemeData theme, Color lineColor) {
    if (spots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [Icon(Icons.analytics_outlined, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 16), Text('No data for $title', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant))]),
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2);
    final bgColor = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.9);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: lineColor.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(Icons.show_chart, color: lineColor, size: 20)),
          const SizedBox(width: 12),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: lineColor)),
        ]),
        const SizedBox(height: 20),
        Container(
          height: 200,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 1, dashArray: [5, 5])),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: true),
            lineBarsData: [LineChartBarData(isCurved: true, curveSmoothness: 0.4, spots: spots, barWidth: 4, color: lineColor, shadow: Shadow(color: lineColor.withValues(alpha: 0.4), blurRadius: 8), dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 6, color: lineColor, strokeWidth: 3, strokeColor: isDark ? Colors.black : Colors.white)), belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [lineColor.withValues(alpha: isDark ? 0.3 : 0.4), lineColor.withValues(alpha: 0.0)])))],
          )),
        ),
      ]),
    );
  }

}
