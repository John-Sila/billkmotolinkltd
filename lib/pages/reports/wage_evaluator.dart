import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class WageEvaluatorScreen extends StatefulWidget {
  const WageEvaluatorScreen({super.key});

  @override
  State<WageEvaluatorScreen> createState() => _WageEvaluatorScreenState();
}

class _InfoItem {
  final String label;
  final String value;
  _InfoItem(this.label, this.value);
}

class PdfTheme {
  static const primary = PdfColors.blueGrey800;
  static const accent = PdfColors.blue600;
  static const subtle = PdfColors.grey600;
  static const border = PdfColors.grey300;
  static const background = PdfColors.grey100;

  static final title = pw.TextStyle(
    fontSize: 20,
    fontWeight: pw.FontWeight.bold,
    color: primary,
  );

  static final sectionHeader = pw.TextStyle(
    fontSize: 13,
    fontWeight: pw.FontWeight.bold,
    color: primary,
    letterSpacing: 0.5,
  );

  static final body = pw.TextStyle(fontSize: 10);
  static final label = pw.TextStyle(fontSize: 8, color: subtle);
  static final value = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
}

class _WageEvaluatorScreenState extends State<WageEvaluatorScreen> {
  String? selectedUserName;
  String? selectedUserId;

  double totalGross = 0;
  int workedDays = 0;
  double dailyTarget = 3250;
  double total = 0;

  Map<String, dynamic> dailyRecords = {};

  final List<Map<String, dynamic>> additionals = [];
  final List<Map<String, dynamic>> withdrawals = [];
  final currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);

  final TextEditingController _dailyTargetController =
      TextEditingController(text: '3250');

  @override
  void initState() {
    super.initState();
    calculateTotal();
  }

  @override
  void dispose() {
    _dailyTargetController.dispose();
    super.dispose();
  }

  void calculateTotal() {
    setState(() {
      total = ((totalGross - (dailyTarget * workedDays)) * 0.79 * 0.5) +
          (500 * workedDays);
    });
  }

  String getWeekLabel(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();

    final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    final formatter = DateFormat("dd MMM yyyy");
    return "Week $weekNumber (${formatter.format(firstDayOfWeek)} to ${formatter.format(lastDayOfWeek)})";
  }

  Future<Uint8List> loadAssetImage(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  String capitalize(String input) {
    return input
        .split(' ')
        .map((e) => e.isNotEmpty
            ? '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'This is a metric calculator: Nothing here gets posted to the database.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildUserDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .where('userRank', isEqualTo: 'Rider')
        .snapshots(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();

        return DropdownButtonFormField<String>(
          value: selectedUserId,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person_outline),
            labelText: "Select Employee",
          ),
          items: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['userName'] ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (uid) async {
            if (uid == null) return;
            final doc =
                await FirebaseFirestore.instance.collection('users').doc(uid).get();
            final data = doc.data();

            if (data == null) return;

            setState(() {
              selectedUserId = uid;
              selectedUserName = data['userName'];
              dailyTarget = (data['dailyTarget'] ?? 3250).toDouble();
              _dailyTargetController.text = dailyTarget.toStringAsFixed(2);
            });

            await fetchWeeklyTotals(data['userName']);
          },
        );
      },
    );
  }

  Widget _metricRow(
    BuildContext context,
    String label,
    String value, {
    bool isStrong = false,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveGrossPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Live Evaluation Preview",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 14),

          _metricRow(context, "Total Gross", currencyFormat.format(totalGross)),
          _metricRow(context, "Worked Days", "$workedDays"),
          _metricRow(context, "Daily Target", currencyFormat.format(dailyTarget)),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _metricRow(
              context,
              "Current Total",
              currencyFormat.format(total),
              isStrong: true,
            ),
          ),
        ],
      ),
    );
  }
    
  Widget _buildReadOnlyTarget() {
    return TextFormField(
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Daily Target',
        prefixIcon: Icon(Icons.track_changes),
      ),
      controller: _dailyTargetController,
      onChanged: (val) {
        setState(() {
          dailyTarget = double.tryParse(val) ?? 3250;
        });
        calculateTotal();
      },
    );
  }

  Future<void> fetchWeeklyTotals(String userName) async {
    final now = DateTime.now();
    final weekLabel = getWeekLabel(now);

    final doc = await FirebaseFirestore.instance
        .collection('deviations')
        .doc(weekLabel)
        .get();

    if (!doc.exists) {
      setState(() {
        totalGross = 0;
        workedDays = 0;
        dailyRecords = {};
      });
      calculateTotal();
      return;
    }

    final data = doc.data() as Map<String, dynamic>;

    if (!data.containsKey(userName)) {
      setState(() {
        totalGross = 0;
        workedDays = 0;
        dailyRecords = {};
      });
      calculateTotal();
      return;
    }

    final userData = data[userName] as Map<String, dynamic>;

    double grossSum = 0;
    int days = 0;

    userData.forEach((day, values) {
      final dayData = values as Map<String, dynamic>;
      grossSum += (dayData['grossIncome'] ?? 0).toDouble();
      days++;
    });

    setState(() {
      totalGross = grossSum;
      workedDays = days;
      dailyRecords = userData;
    });

    calculateTotal();
  }

  Widget buildDynamicList(List<Map<String, dynamic>> list, bool isAddition) {
    return Column(
      children: [
        ...list.asMap().entries.map((entry) {
          int index = entry.key;
          return Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Name'),
                  onChanged: (val) => list[index]['name'] = val,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Amount'),
                  onChanged: (val) {
                    setState(() {
                      list[index]['amount'] = double.tryParse(val) ?? 0;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () {
                  setState(() {
                    list.removeAt(index);
                  });
                },
              )
            ],
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                list.add({'name': '', 'amount': 0});
              });
            },
            icon: const Icon(Icons.add),
            label: Text(isAddition ? 'Add Additional' : 'Add Withdrawal'),
          ),
        )
      ],
    );
  }

  List<MapEntry<String, dynamic>> getSortedDailyEntries(Map<String, dynamic> records) {
    const weekdayOrder = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final orderMap = {
      for (int i = 0; i < weekdayOrder.length; i++) weekdayOrder[i]: i,
    };

    final entries = records.entries.toList();

    entries.sort((a, b) {
      final aIndex = orderMap[a.key] ?? 999;
      final bIndex = orderMap[b.key] ?? 999;
      return aIndex.compareTo(bIndex);
    });

    return entries;
  }

  String ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Map<String, String> formatPrettyDateParts(DateTime date) {
    final day = date.day.toString();
    final suffix = ordinalSuffix(date.day);
    final month = DateFormat('MMMM').format(date);
    final year = date.year.toString();

    return {
      "day": day,
      "suffix": suffix,
      "rest": " $month, $year",
    };
  }
  
  pw.Widget _buildFinancialTable(
    double grossTotal,
    double targetDeduction,
    double wagePerDay,
    double factor1,
    double factor2,
    double total,
  ) {
    final bold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Column(
          children: [
            // HEADER
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              color: PdfColors.grey200,
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text("Item", style: bold)),
                  pw.Expanded(
                    child: pw.Text(
                      "Amount",
                      textAlign: pw.TextAlign.right,
                      style: bold,
                    ),
                  ),
                ],
              ),
            ),

            // BODY
            _summaryRow(
              "Total Gross",
              currencyFormat.format(grossTotal),
              valueStyle: PdfTheme.value,
            ),
            _summaryRow(
              "Target Deduction",
              "- ${currencyFormat.format(targetDeduction)}",
              valueColor: PdfColors.red700,
              labelColor: PdfColors.red700,
            ),
            _summaryRow(
              "Wage Adjustment",
              "+ ${currencyFormat.format(wagePerDay)}",
              valueColor: PdfColors.green700,
            ),
            _summaryRow(
              "Factor 1",
              factor1.toStringAsFixed(2),
              labelColor: PdfTheme.subtle,
            ),
            _summaryRow(
              "Factor 2",
              factor2.toStringAsFixed(2),
              labelColor: PdfTheme.subtle,
            ),

            // TOTAL (NO margin, NO radius — let parent control shape)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              color: PdfColors.blueGrey900,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Total Payable",
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
                  ),
                  pw.Text(
                    currencyFormat.format(total),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
    
  pw.Widget _buildDailySummaryTable(Map<String, dynamic> records) {
    final sortedEntries = getSortedDailyEntries(records);

    final days = <String>[];
    final valuesRaw = <double>[];

    for (final entry in sortedEntries) {
      final data = entry.value as Map<String, dynamic>;
      days.add(entry.key);
      valuesRaw.add((data['grossIncome'] ?? 0).toDouble());
    }

    final maxVal = valuesRaw.isNotEmpty
        ? valuesRaw.reduce((a, b) => a > b ? a : b)
        : 0.0;

    final minVal = valuesRaw.isNotEmpty
        ? valuesRaw.reduce((a, b) => a < b ? a : b)
        : 0.0;

    final total = valuesRaw.fold(0.0, (sum, v) => sum + v);

    days.add("Total");
    valuesRaw.add(total);

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8), // slightly increased
      ),
      child: pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Table(
          border: pw.TableBorder.symmetric(
            inside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
          columnWidths: {
            for (int i = 0; i < days.length; i++)
              i: const pw.FlexColumnWidth(1),
          },
          children: [
            // HEADER ROW
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              children: days.map((day) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text(
                    day,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),

            // VALUES ROW
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: List.generate(valuesRaw.length, (index) {
                final value = valuesRaw[index];
                final isTotal = index == valuesRaw.length - 1;
                final isMax = value == maxVal && !isTotal;
                final isMin = value == minVal && !isTotal;

                PdfColor? color;
                if (isTotal) {
                  color = PdfColors.blueGrey900;
                } else if (isMax) {
                  color = PdfColors.green700;
                } else if (isMin) {
                  color = PdfColors.red700;
                }

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Text(
                    currencyFormat.format(value),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: isTotal
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: color,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value, {
    pw.TextStyle? labelStyle,
    pw.TextStyle? valueStyle,
    PdfColor? labelColor,
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: (labelStyle ?? const pw.TextStyle(fontSize: 10)).copyWith(
                color: labelColor,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: (valueStyle ?? const pw.TextStyle(fontSize: 10)).copyWith(
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoCard(String label, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfTheme.border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: PdfTheme.label),
          pw.SizedBox(height: 4),
          pw.Text(value, style: PdfTheme.value),
        ],
      ),
    );
  }

  pw.Widget _buildDateWithSubscript(DateTime date) {
    final day = date.day.toString();
    final suffix = ordinalSuffix(date.day);
    final month = DateFormat('MMMM').format(date);
    final year = date.year;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text("Date: ", style: const pw.TextStyle(fontSize: 10)),

        // Day
        pw.Text(day, style: const pw.TextStyle(fontSize: 10)),

        // Subscript suffix
        pw.Transform.translate(
          offset: const PdfPoint(0, 3.5), // push DOWN
          child: pw.Text(
            suffix,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),

        // Rest of date
        pw.Text(
          " $month, $year",
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Future<void> generatePdf() async {
    if (selectedUserName == null) return;

    final companyLogo = await loadAssetImage('assets/logo.png');
    final kraLogo = await loadAssetImage('assets/kra.png');
    final sigBytes = await loadAssetImage('assets/primary_signature.png');

    final companyImage = pw.MemoryImage(companyLogo);
    final kraImage = pw.MemoryImage(kraLogo);
    final signatureImage = pw.MemoryImage(sigBytes);

    final pdf = pw.Document();

    final double wagePerDay = 500;
    final double factor1 = 0.79;
    final double factor2 = 0.5;
    final double targetDeduction = dailyTarget * workedDays;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    pw.Image(companyImage, width: 60),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("BILLK MOTOLINK LTD", style: PdfTheme.title),
                        pw.Text(
                          "Human Resource Management System",
                          style: PdfTheme.label,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Image(kraImage, width: 55),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          //pw.Divider(thickness: 1, height: 40, color: PdfColors.grey300),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "WAGE EVALUATION REPORT",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              _buildDateWithSubscript(DateTime.now()),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoCard("Employee Name", selectedUserName!),
                _buildInfoCard("Worked Days", "$workedDays days"),
                _buildInfoCard("Daily Target", currencyFormat.format(dailyTarget)),
                _buildInfoCard("Total Gross", currencyFormat.format(totalGross)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Compensation Formula", style: PdfTheme.sectionHeader),
                pw.SizedBox(height: 6),
                pw.Text(
                  "((G - (T × D)) × C1 × C2) + (W × D)",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            "Parameters: Wage per Day = ${currencyFormat.format(wagePerDay)}, Constant I = $factor1, Constant II = $factor2",
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            "FINANCIAL SUMMARY",
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _buildFinancialTable(
            totalGross,
            targetDeduction,
            wagePerDay * workedDays,
            factor1,
            factor2,
            total,
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            "DAILY TOTALS",
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _buildDailySummaryTable(dailyRecords),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 200,
                    child: pw.Text(
                      "This document is subject to Section 74 of the Employment Act 2007, CAP 226. KRA (eTims and affiliates) may audit this report for compliance and verification purposes.",
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey600),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.SizedBox(
                    width: 200,
                    child: pw.Text(
                      "Department of Information & Communication Technology",
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey400,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Authorized By",
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 5),
                  pw.Image(signatureImage, width: 100, height: 40),
                  pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 5),
                  pw.Text("Paul Kyonda",
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    "CEO & Principal Director",
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wage Evaluator',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: "Employee Details",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUserDropdown(),
                  const SizedBox(height: 16),
                  _buildLiveGrossPreview(),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "Evaluation Parameters",
              child: Column(
                children: [
                  _buildReadOnlyTarget(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildTotalCard(theme, isDark),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: generatePdf,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Generate Report"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blueGrey)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blueGrey.withValues(alpha: 0.2)
            : Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "TOTAL PAYABLE",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          Text(
            "KES ${total.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.blue[200] : Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }
}