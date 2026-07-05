import 'package:billkmotolinkltd/pages/reports/non_variable_docs.dart';
import 'package:billkmotolinkltd/pages/reports/wage_evaluator.dart';
import 'package:billkmotolinkltd/pages/reports/absenteeism.dart';
import 'package:flutter/material.dart';
import 'package:billkmotolinkltd/pages/reports/this_week_as_is.dart';
import 'package:billkmotolinkltd/pages/reports/general_as_is_state.dart';
import 'package:billkmotolinkltd/pages/reports/human_resource_report.dart';
import 'package:billkmotolinkltd/pages/reports/rider_daily_statistics.dart';
import 'package:billkmotolinkltd/pages/reports/weekly_analysis_report.dart';

class Reports extends StatelessWidget {
  const Reports({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Reports Center',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Access your business analytics, financial summaries, and performance metrics here.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 30),

        // Weekly Analysis Report
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.teal),
            title: const Text('Weekly Analysis Report'),
            subtitle: const Text('View total rider revenue trends for the week.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeeklyAnalysisReport()),
              );
            },
          ),
        ),

        // Rider Daily Statistics
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.people, color: Colors.teal),
            title: const Text('Rider Daily Statistics'),
            subtitle: const Text('View rider engagement insights.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RiderDailyStatistics()),
              );
            },
          ),
        ),

        // Human Resource
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.restaurant_menu_rounded, color: Colors.teal),
            title: const Text('Human Resource'),
            subtitle: const Text('See reports that await action.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HumanResourceReports()),
              );
            },
          ),
        ),

        // Daily As-Is State
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.pie_chart_rounded, color: Colors.teal),
            title: const Text('This Week As-Is State'),
            subtitle: const Text('See how the company is doing this week.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThisWeekStateReport()),
              );
            },
          ),
        ),

        // General As-Is State
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.bar_chart_rounded, color: Colors.teal),
            title: const Text('General As-Is State'),
            subtitle: const Text('See how the company has been doing over the weeks.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GeneralStateReport()),
              );
            },
          ),
        ),

        // Absenteeism
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.event_busy_rounded, color: Colors.teal),
            title: const Text('Attendance Rota'),
            subtitle: const Text('See which riders clocked out each day, by week.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Absenteeism()),
              );
            },
          ),
        ),

        // Wage Evaluator
        Card(
          elevation: 2,
          child: ListTile(
            leading: const Icon(Icons.attach_money_rounded, color: Colors.teal),
            title: const Text('Wage Evaluator'),
            subtitle: const Text('Analyze and evaluate employee wages.'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WageEvaluatorScreen()),
              );
            },
          ),
        ),

        // non variable docs
        // Card(
        //   elevation: 2,
        //   child: ListTile(
        //     leading: const Icon(Icons.attach_money_rounded, color: Colors.teal),
        //     title: const Text('Non Variable Documents'),
        //     subtitle: const Text('Reproduce contractual documents for employees.'),
        //     onTap: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (_) => const NonVariableDocuments()),
        //       );
        //     },
        //   ),
        // ),



        
      ],
    );
  }
}