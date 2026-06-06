import 'dart:ffi';

import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:billkmotolinkltd/utils/utility_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class ClockOut extends StatefulWidget {
  const ClockOut({super.key});

  @override
  State<ClockOut> createState() => _ClockOutState();
}

extension DateTimeFormatting on DateTime {
  String weekdayName() {
    return ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][weekday-1];
  }

  String monthName() {
    return ["January","February","March","April","May","June","July","August","September","October","November","December"][month-1];
  }

  String daySuffix() {
    if (day >= 11 && day <= 13) return "th";
    switch (day % 10) {
      case 1: return "st";
      case 2: return "nd";
      case 3: return "rd";
      default: return "th";
    }
  }
}

class _ClockOutState extends State<ClockOut> {
  final TextEditingController grossIncomeController = TextEditingController();
  final TextEditingController todaysIABController = TextEditingController();
  final TextEditingController prevIABController = TextEditingController();
  final TextEditingController clockInMileageController = TextEditingController();
  final TextEditingController clockOutMileageController = TextEditingController();
  final TextEditingController otherExpenseController = TextEditingController();

  Map<String, bool> expensesChecked = {
    'Battery Swap': false,
    'Data Bundles': false,
    'Lunch': false,
    'Police': false,
    'Taxes': false,
    'Bike Cleaning': false,
    'Other': false,
  };

  Map<String, TextEditingController> expenseControllers = {};
  List<String> destinations = [];
  String? selectedDestination;
  double commissionPercentage = 0.0;
  double target = 0.0;
  bool isClockedIn = false;
  bool hasClockedOutToday = false;
  bool isClockingOut = false;
  bool? _isOnline;



  double deviation = 0.0;
  double netIncome = 0.0;
  double totalExpenses = 0.0;
  bool isLoading = true;
  String userName = "";

  String todayHumanKey() {
    return DateFormat("dd MMM yyyy", "en_US").format(DateTime.now());
  }

  String weekdayName() {
    return DateFormat("EEEE", "en_US").format(DateTime.now());
  }

  String traceDateString() {
    return DateFormat("EEEE_d_MMMM", "en_US").format(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    fetchInitialData();
    checkIsOnline();

    // Initialize expense controllers
    expensesChecked.forEach((key, value) {
      expenseControllers[key] = TextEditingController();
      expenseControllers[key]!.addListener(updateNetIncome);
    });

    grossIncomeController.addListener(updateDeviation);
    todaysIABController.addListener(updateNetIncome);
    prevIABController.addListener(updateNetIncome);


    // Rebuild whenever any input changes
    grossIncomeController.addListener(_updateState);
    todaysIABController.addListener(_updateState);
    prevIABController.addListener(_updateState);
    clockInMileageController.addListener(_updateState);
    clockOutMileageController.addListener(_updateState);
    expenseControllers.forEach((key, ctrl) => ctrl.addListener(_updateState));
    otherExpenseController.addListener(_updateState);
  }

  void _updateState() => setState(() {});

  @override
  void dispose() {
    grossIncomeController.dispose();
    todaysIABController.dispose();
    prevIABController.dispose();
    clockInMileageController.dispose();
    clockOutMileageController.dispose();
    otherExpenseController.dispose();
    expenseControllers.forEach((key, ctrl) => ctrl.dispose());
    super.dispose();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning, $userName";
    if (hour < 17) return "Good afternoon, $userName";
    return "Good evening, $userName";
  }

  // Fetch initial data
  Future<void> fetchInitialData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      isClockedIn = userData['isClockedIn'] ?? false;

      final dateKey = DateFormat("dd MMM yyyy", "en_US").format(DateTime.now());

      // Check if today's clockout exists
      final clockouts = Map<String, dynamic>.from(userData['clockouts'] ?? {});
      hasClockedOutToday = clockouts.containsKey(dateKey);

      if (!isClockedIn || hasClockedOutToday) {
        setState(() => isLoading = false);
        return;
      }

      userName = userData['userName'] ?? "User";

      clockInMileageController.text =
          ((userData['clockinMileage'] ?? 0) as num).toDouble().toString();

      // Fetch commission
      final generalDoc =
          await FirebaseFirestore.instance.collection('general').doc('general_variables').get();
      commissionPercentage =
          ((generalDoc.data()?['commissionPercentage'] ?? 0) as num).toDouble() / 100.0;


      // Fetch destinations
      destinations = List<String>.from(generalDoc.data()?['destinations'] ?? []);

      // Fetch targets
      final now = DateTime.now();
      final weekday = now.weekday; // 1 = Monday, 7 = Sunday
      target = ((weekday == 7 ? userData['sundayTarget'] : userData['dailyTarget']) ?? 0)
          .toDouble();

      prevIABController.text =
          ((userData['currentInAppBalance'] ?? 0) as num).toDouble().toString();

      setState(() => isLoading = false);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  void updateDeviation() {
    final gross = double.tryParse(grossIncomeController.text) ?? 0.0;
    setState(() {
      deviation = gross - target;
    });
    updateNetIncome();
  }

  void updateNetIncome() {
    final gross = double.tryParse(grossIncomeController.text) ?? 0.0;
    final todayIAB = double.tryParse(todaysIABController.text) ?? 0.0;
    final prevIAB = double.tryParse(prevIABController.text) ?? 0.0;

    totalExpenses = 0.0;
    expenseControllers.forEach((key, ctrl) {
      if (expensesChecked[key] == true) {
        totalExpenses += double.tryParse(ctrl.text) ?? 0.0;
      }
    });

    setState(() {
      netIncome = gross * (1 - commissionPercentage) - (todayIAB - prevIAB) - totalExpenses;
    });
  }

  bool get canClockOut {
    if (isClockedIn != true) return false; // handle nullable

    if (grossIncomeController.text.isEmpty ||
        todaysIABController.text.isEmpty ||
        prevIABController.text.isEmpty ||
        clockInMileageController.text.isEmpty ||
        clockOutMileageController.text.isEmpty ||
        selectedDestination == null) {
      return false;
    }

    // All checked expenses must have a value
    for (var key in expensesChecked.keys) {
      if (!expensesChecked[key]!) continue;

      if (key == 'Other') {
        // Other must have both amount AND description
        if (expenseControllers[key]!.text.isEmpty || otherExpenseController.text.isEmpty) {
          return false;
        }
      } else {
        if (expenseControllers[key]!.text.isEmpty) return false;
      }
    }

    return true;
  }

  String getWeekLabel(DateTime date) {
    // Compute ISO week number
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();

    // Compute start and end of week (Monday to Sunday)
    final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    final formatter = DateFormat("dd MMM yyyy");
    return "Week $weekNumber (${formatter.format(firstDayOfWeek)} to ${formatter.format(lastDayOfWeek)})";
  }

  void showClockOutConfirmationDialog() {
    final localTheme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.logout,
            color: localTheme.colorScheme.primary,
            size: 48,
          ),
          title: Text(
            'Confirm Clock-Out',
            style: localTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to end this shift?',
                style: localTheme.textTheme.bodyMedium?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will finalize your mileage, batteries, and shift data.',
                style: localTheme.textTheme.bodySmall?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: localTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: isClockingOut 
                  ? localTheme.colorScheme.primaryContainer 
                  : localTheme.colorScheme.primary,
                surfaceTintColor: Colors.transparent,
              ),
              onPressed: isClockingOut
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      setState(() => isClockingOut = true);
                      await clockOut();
                      setState(() => isClockingOut = false);
                    },
              child: isClockingOut
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Confirm',
                          style: localTheme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
          actionsPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
    
  // Helper function
  bool _clockOutMileageValid() {
    final clockOutVal = double.tryParse(clockOutMileageController.text) ?? 0.0;
    final clockInVal = double.tryParse(clockInMileageController.text) ?? 0.0;
    return clockOutVal >= clockInVal;
  }

  String formatTimeElapsed(int timeElapsedMs) {
    int hours = timeElapsedMs ~/ 3600000; // 3600 * 1000 ms per hour
    int minutes = (timeElapsedMs % 3600000) ~/ 60000; // 60 * 1000 ms per minute
    
    return '${hours.toString().padLeft(1)} hrs ${minutes.toString().padLeft(2)} mins';
  }

  Future<void> pruneAllStoreTransactions({int retentionDays = 30}) async {
    try {
      final collection = FirebaseFirestore.instance.collection("store");

      final snapshot = await collection.get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: retentionDays));

      int updates = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final List<dynamic> transactions =
            List<dynamic>.from(data['transactions'] ?? []);

        if (transactions.isEmpty) continue;

        final filtered = transactions.where((tx) {
          final time = tx['time'];

          if (time == null) return false;

          DateTime txTime;

          if (time is Timestamp) {
            txTime = time.toDate();
          } else if (time is DateTime) {
            txTime = time;
          } else {
            return false;
          }

          return txTime.isAfter(cutoff);
        }).toList();

        // Only update if something changed
        if (filtered.length != transactions.length) {
          batch.update(doc.reference, {
            "transactions": filtered,
          });
          updates++;
        }

        // Firestore batch limit = 500
        if (updates == 499) {
          await batch.commit();
          updates = 0;
        }
      }

      // Commit remaining
      if (updates > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Global prune failed: $e");
    }
  }
    
  Future<void> clockOut() async {
    if (!canClockOut) {
      Fluttertoast.showToast(msg: "Complete all required fields");
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();

      final fs = FirebaseFirestore.instance;
      final userRef = fs.collection('users').doc(uid);
      final batteriesRef = fs.collection('batteries');
      final bikesRef = fs.collection('general').doc('general_variables');
      final weekLabel = getWeekLabel(now);
      final deviationsRef = fs.collection('deviations')
          .doc(weekLabel);

      // --- PULL USER PROFILE FIRST ---
      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        Fluttertoast.showToast(msg: "User not found");
        return;
      }
      final userName = userSnap.get('userName');
      final pendingAmountOld = userSnap.get('pendingAmount') ?? 0.0;
      final prevInApp = double.parse(prevIABController.text);
      final todaysIAB = double.parse(todaysIABController.text);
      final clockinMileage = userSnap.get('clockinMileage');
      final selectedLoc = selectedDestination;
      if (double.parse(clockOutMileageController.text) < clockinMileage) {
        Fluttertoast.showToast(
          msg: "Clockout mileage too low",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 14.0,
        );
        return;
      }
      // userSnap.get('currentBike');

      // --- EXPENSE MAP --- (Fixed)
      Map<String, dynamic> expenseData = {};
      expenseControllers.forEach((key, ctrl) {
        // Skip 'Other' when processing standard checkboxes
        if (expensesChecked[key]! && key != 'Other') {
          expenseData[key] = double.parse(ctrl.text);
        }
      });

      // Handle 'Other' separately - ONLY if checked and has description
      if (expensesChecked['Other']! && otherExpenseController.text.trim().isNotEmpty) {
        final description = otherExpenseController.text.trim();
        final value = double.parse(expenseControllers['Other']!.text);
        expenseData[description] = value; // Only custom description as key
      }

      // --- NET INCOME CALC ---
      final gross = double.parse(double.parse(grossIncomeController.text).toStringAsFixed(2));
      final commission = commissionPercentage; // already fetched on load
      final netIncome = double.parse((gross * (1 - commission)
          - (todaysIAB - prevInApp)
          - expenseData.values.whereType<num>().fold(0.0, (s, v) => s + v)).toStringAsFixed(2));

      // --- DATE KEYS ---
      final dateKey = todayHumanKey();                   // e.g. 06 Dec 2025
      final weekDay = weekdayName();                     // Saturday

      // -----------------------------------------------------------------------
      // 1. RELEASE BIKE (general/general_variables/bikes)
      // -----------------------------------------------------------------------
      final generalSnap = await bikesRef.get();
      final bikes = Map<String, dynamic>.from(generalSnap.get('bikes'));

      bikes.updateAll((key, value) {
        final m = Map<String, dynamic>.from(value);
        if (m['assignedRider'] == userName) {
          m['assignedRider'] = "None";
          m['isAssigned'] = false;
        }
        return m;
      });

      // -----------------------------------------------------------------------
      // 2. RELEASE BATTERIES + TRACE APPEND
      // -----------------------------------------------------------------------
      final batteryQuery = await batteriesRef
          .where('assignedRider', isEqualTo: userName)
          .get();

      for (var b in batteryQuery.docs) {
        // battery state
        await b.reference.update({
          'assignedRider': "None",
          'assignedBike': "None",
          'confirmedStatus': false,
          'storeAssignedRider': "None",
          'batteryLocation': selectedLoc,
          'offTime': now,
        });
      }

      // user profile
      int timeElapsed = (now.millisecondsSinceEpoch - userSnap.get('clockInTime').millisecondsSinceEpoch) as int;
      final clockoutData = {
        "grossIncome": gross,
        "todaysInAppBalance": double.parse(todaysIAB.toStringAsFixed(2)),
        "previousInAppBalance": double.parse((prevInApp).toStringAsFixed(2)),
        "inAppDifference": todaysIAB - prevInApp,
        "expenses": expenseData,
        "netIncome": netIncome,
        "clockinMileage": clockinMileage,
        "clockoutMileage": double.parse(clockOutMileageController.text),
        "mileageDifference":
            double.parse(clockOutMileageController.text) - clockinMileage,
        "posted_at": now,
        "timeElapsed": formatTimeElapsed(timeElapsed)
      };

      final notificationId =
        DateTime.now().millisecondsSinceEpoch.toString();
        
      await userRef.update({
        "clockouts.$dateKey": clockoutData,
        "currentInAppBalance": todaysIAB,
        "isClockedIn": false,
        "netClockedLastly": netIncome,
        "pendingAmount": double.parse((pendingAmountOld + netIncome).toStringAsFixed(2)),
        "lastClockDate": now,
        "currentBike": "None",
        'notifications.$notificationId': {
          'isRead': false,
          'message': 'You\'re clocked out for today.',
          'time': now,
        },
        "numberOfNotifications": FieldValue.increment(1),
      });

      // deviations
      final deviationData = {
        "grossIncome": gross,
        "netIncome": netIncome,
        "grossDeviation": gross - target,
        "netGrossDifference": gross - netIncome,
      };

      await deviationsRef.set({
        userName: {weekDay: deviationData}
      }, SetOptions(merge: true));

      // net income and worked days
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(userRef);

        final now = DateTime.now();
        final monthName = DateFormat("MMMM").format(now);
        final nextMonth = DateFormat("MMMM")
            .format(DateTime(now.year, now.month + 1, now.day));

        // Safely read netIncomes and workedDays maps
        final netIncomes = Map<String, dynamic>.from(snap.data()?['netIncomes'] ?? {});
        final workedDays = Map<String, dynamic>.from(snap.data()?['workedDays'] ?? {});

        final currentIncome = (netIncomes[monthName] ?? 0.0) as num;
        final currentDays = (workedDays[monthName] ?? 0.0) as num;

        transaction.update(userRef, {
          "netIncomes.$monthName": currentIncome + netIncome,
          "workedDays.$monthName": currentDays + 1,
          "netIncomes.$nextMonth": FieldValue.delete(),
          "workedDays.$nextMonth": FieldValue.delete(),
        });
      });

      // bike
      await bikesRef.update({"bikes": bikes});
      setState(() {
        hasClockedOutToday = true;
      });

      // store
      final storeQuery = await FirebaseFirestore.instance
        .collection("store")
        .where("assignedTo", isEqualTo: userName)
        .get();
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in storeQuery.docs) {
        final ref = doc.reference;

        final now = DateTime.now();

        final message =
            "Unassigned from $userName on ${AppDateUtils.formatStandard(now)} due to clock-out. Awaiting confirmation.";

        batch.update(ref, {
          "assignedTo": "None",
          "assignedToUid": "None",
          "movement": "Incoming",
          "droppedBy": userName,
          "isAssigned": false,
          "confirmedStatus": false,
          "transactions": FieldValue.arrayUnion([
            {
              "message": message,
              "time": now,
            }
          ]),
        });
      }
      await batch.commit();
      await pruneAllStoreTransactions();

      await _updateYearlyAndMonthlyStats(
        userName: '$userName',
        gross: gross,
        netIncome: netIncome,
        expenseData: expenseData,
      );
      
      ToastService.success("Clock-out successful! See you next time.");
    } catch (e) {
        if (!mounted) return;
        
        showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Clock-Out Failed"),
          content: SingleChildScrollView(
            child: SelectableText(
              e.toString(), // full exception string, now copiable
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Dismiss"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _updateYearlyAndMonthlyStats({
    required String userName,
    required double gross,
    required double netIncome,
    required Map<String, dynamic> expenseData,
  }) async {
    final now = DateTime.now();
    final year = now.year.toString(); // "2026"
    final month = DateFormat("MMMM").format(now); // "April"
    final monthKey = "${year}_$month"; // "2026_April"

    final fs = FirebaseFirestore.instance;
    final generalRef = fs
        .collection('general')
        .doc('general_variables');

    try {
      final snap = await generalRef.get();
      final data = Map<String, dynamic>.from(snap.data() ?? {});

      // 1. annual_incomes.$year.$userName
      final annualYearPath = "annual_incomes.$year.$userName";
      final annualSnap = Map<String, dynamic>.from(
        (((data["annual_incomes"] as Map<String, dynamic>? ?? {})[year]
                as Map<String, dynamic>? ?? {})[userName]
            as Map<String, dynamic>? ?? {}),
      );

      final aGross = (annualSnap["gross"] ?? 0.0) as num;
      final aNet = (annualSnap["net"] ?? 0.0) as num;
      final aExp = (annualSnap["expenses"] ?? 0.0) as num;

      // 2. monthly_incomes.$monthKey.$userName
      final monthlyPath = "monthly_incomes.$monthKey.$userName";
      final monthlySnap = Map<String, dynamic>.from(
        (((data["monthly_incomes"] as Map<String, dynamic>? ?? {})[monthKey]
                as Map<String, dynamic>? ?? {})[userName]
            as Map<String, dynamic>? ?? {}),
      );

      final mGross = (monthlySnap["gross"] ?? 0.0) as num;
      final mNet = (monthlySnap["net"] ?? 0.0) as num;
      final mExp = (monthlySnap["expenses"] ?? 0.0) as num;

      // 3. Compute total expenses
      final totalExpenses = expenseData.values
          .whereType<num>()
          .fold(0.0, (s, v) => s + v);

      // 4. Update Firestore in one `.update`
      await generalRef.update({
        // annual_incomes.2026.userName.gross, net, expenses, dateAppended
        "$annualYearPath.gross": aGross + gross,
        "$annualYearPath.net": aNet + netIncome,
        "$annualYearPath.expenses": aExp + totalExpenses,
        "$annualYearPath.dateAppended": DateTime.now(),

        // monthly_incomes.2026_April.userName.gross, net, expenses, dateAppended
        "$monthlyPath.gross": mGross + gross,
        "$monthlyPath.net": mNet + netIncome,
        "$monthlyPath.expenses": mExp + totalExpenses,
        "$monthlyPath.dateAppended": DateTime.now(),
      });
    } catch (e) {
      ToastService.error("Failed to update stats: $e");
    }
  }
    
  String resolveClockoutText({
    required bool isClockedIn,
    required bool isLoading,
    required bool isOnline,
    required bool isBlocked,
    required bool hasClockedOutToday,
  }) {
    if (_isOnline == false) return "You are offline";
    if (!isClockedIn) return "You are not clocked in";
    if (hasClockedOutToday) return "You are clocked out";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Clock Out";
  }

  Future<void> checkIsOnline() async {
    final online = await isOnline();
    setState(() {
      _isOnline = online;
    });
  }

  Future<bool> isOnline() async {
    try {
      final response = await http.get(
        Uri.parse("https://clients3.google.com/generate_204"),
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }



  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await fetchInitialData();
        await checkIsOnline();
      },
      child:Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // greeting
                Text(
                  getGreeting(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                if (isClockedIn == false)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16), // Add spacing
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are not clocked in.', // Fixed text
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),



                Text(
                  "Deviation: KSh ${deviation.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deviation < 0 ? Colors.red : Colors.green,
                  ),
                ),

                const SizedBox(height: 16),

                // gross
                _buildTextField(
                  enabled: true,
                  controller: grossIncomeController,
                  label: 'Gross Income',
                  onChanged: (_) => setState(() {}),
                  hint: 'Enter gross income',
                  icon: Icons.monetization_on,
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Gross income is required' 
                      : null,
                ),
                const SizedBox(height: 20),


                // Commission (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: TextEditingController(
                    text: (commissionPercentage * 100).toStringAsFixed(0),
                  ),
                  label: '${(commissionPercentage * 100).toStringAsFixed(0)}% Commission',
                  hint: '',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  icon: Icons.percent,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Auto-filled' 
                      : null,
                ),
                const SizedBox(height: 20),

                // Today's IAB
                _buildTextField(
                  enabled: true,
                  controller: todaysIABController,
                  label: 'Today\'s In-App Balance',
                  hint: 'Enter today\'s IAB',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  icon: Icons.account_balance_wallet,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'In-app balance is required' 
                      : null,
                ),
                const SizedBox(height: 20),

                // Previous IAB (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: prevIABController,
                  label: 'Previous IAB',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  hint: 'Enter previous IAB',
                  icon: Icons.history,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Auto-filled' 
                      : null,
                ),
                const SizedBox(height: 20),

                const Text("Expenses", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Expenses checkboxes
                ...expensesChecked.keys.map((key) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6), // extra space
                    child: Row(
                      children: [
                        Checkbox(
                          value: expensesChecked[key],
                          onChanged: (val) {
                            setState(() {
                              expensesChecked[key] = val!;
                              if (!val) expenseControllers[key]!.clear();
                              updateNetIncome();
                            });
                          },
                        ),
                        Text(key),
                        const SizedBox(width: 8),


                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: expenseControllers[key],
                              enabled: expensesChecked[key],
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter amount",
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.attach_money_outlined,
                                  color: expensesChecked[key] ?? false ? Colors.blue[600]! : Colors.grey[400]!,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: expensesChecked[key] ?? false ? Colors.grey[300]! : Colors.grey[400]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: expensesChecked[key] ?? false ? Colors.grey[300]! : Colors.grey[400]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey[400]!,
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ),





                        
                      ],
                    ),
                  );
                }),

                // Other description
                if (expensesChecked['Other']!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: TextField(
                      controller: otherExpenseController,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: "Other Expense Description",
                        hintText: "Enter description...",
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                        prefixIcon: Icon(
                          Icons.description_outlined,
                          color: Colors.blue[600],
                          size: 24,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.blue[600]!,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.transparent,  // No fixed background
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Clock-In Mileage (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: clockInMileageController,
                  label: 'Clock-In Mileage',
                  hint: '',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  icon: Icons.history,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Auto-filled' 
                      : null,
                ),
                const SizedBox(height: 20),

                // Clock-Out Mileage
                _buildTextField(
                  enabled: true,
                  controller: clockOutMileageController,
                  label: 'Clock-Out Mileage',
                  hint: 'Enter clock-out mileage',
                  icon: Icons.directions_bike,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Mileage is required' 
                      : null,
                ),
                const SizedBox(height: 20),



                // Location dropdown
                _buildDropdownField<String>(
                  value: selectedDestination,
                  label: 'Select Location',
                  hint: 'Choose destination',
                  icon: Icons.location_on_outlined,
                  items: destinations.map((loc) {
                    return DropdownMenuItem(value: loc, child: Text(loc));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => selectedDestination = val);
                  },
                ),
                const SizedBox(height: 20),


                // Net Income
                Text(
                  "Net Income: KSh ${netIncome.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Clock-Out Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!hasClockedOutToday && canClockOut && !isClockingOut && _clockOutMileageValid() && isClockedIn && (_isOnline == true))
                        ? showClockOutConfirmationDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasClockedOutToday ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isClockingOut
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            resolveClockoutText(
                              isClockedIn: isClockedIn,
                              hasClockedOutToday: hasClockedOutToday,
                              isLoading: isLoading,
                              isBlocked: false,
                              isOnline: (_isOnline == true) ? true : false,
                            ),
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),

                  ),
                )


              ],
            ),
          ),
        ),
      )

      );
  }
}


Widget _buildTextField({
  required bool enabled,
  required TextEditingController controller,
  required String label,
  required String hint,
  void Function(String)? onChanged,
  required IconData icon,
  TextInputType? keyboardType,
  bool obscureText = false,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    enabled: enabled,
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    onChanged: onChanged,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.blue[600]),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey[700]),
    ),
  );
}


Widget _buildDropdownField<T>({
  required T? value,
  required String label,
  required String hint,
  required IconData icon,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?>? onChanged,
  String? Function(T?)? validator,
}) {
  return DropdownButtonFormField<T>(
    value: value,
    items: items,
    onChanged: onChanged,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.blue[600]),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    ),
  );
}

