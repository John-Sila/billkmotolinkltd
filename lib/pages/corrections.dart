// ignore_for_file: use_build_context_synchronously

import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class Corrections extends StatefulWidget {
  const Corrections({super.key});

  @override
  State<Corrections> createState() => _Correctionstate();
}

class _Correctionstate extends State<Corrections> {
  final TextEditingController grossIncomeController = TextEditingController();
  final TextEditingController todaysIABController = TextEditingController();
  final TextEditingController prevIABController = TextEditingController();
  final TextEditingController clockInMileageController = TextEditingController();
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
  double commissionPercentage = 0.0;
  double target = 0.0;
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

  String timeNow() {
    return DateFormat("HH:mm:ss").format(DateTime.now());
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

  String? selectedKey;
  Map<String, dynamic> requirements = {}; // Will hold the fetched requirements
  int appBalance = 0;
  String dayOfWeek = "";
  String weekRange = "";
  String selectedDate = "";

  void _updateVariables(String key) {
    final data = Map<String, dynamic>.from(requirements[key]!);
    setState(() {
      selectedKey = key; // <- This updates the dropdown
      appBalance = ((data['appBalance'] ?? 0) as num).toInt();
      dayOfWeek = data['dayOfWeek'] ?? "";
      weekRange = data['weekRange'] ?? "";
      selectedDate = data['date'] ?? "";

      // Update the TextFormField controller
      prevIABController.text = appBalance.toString();
    });
  }

  Future<void> fetchInitialData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      userName = userData['userName'] ?? "User";

      clockInMileageController.text =
          ((userData['clockinMileage'] ?? 0) as num).toDouble().toString();

      // Fetch commission
      final generalDoc = await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .get();
      commissionPercentage =
          ((generalDoc.data()?['commissionPercentage'] ?? 0) as num).toDouble() / 100.0;

      // Fetch destinations
      destinations = List<String>.from(generalDoc.data()?['destinations'] ?? []);

      // Fetch targets
      target = ((userData['dailyTarget']) ?? 0).toDouble();

      // --- Fetch requirements ---
      final reqMap = Map<String, dynamic>.from(userData['requirements'] ?? {});
      if (reqMap.isNotEmpty) {
        requirements = reqMap;
        selectedKey = requirements.keys.first;
        _updateVariables(selectedKey!);
      }


      setState(() => isLoading = false);
    } catch (e) {
      ToastService.error("Error fetching data: $e");
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

  bool get canCorrect {
    if (grossIncomeController.text.isEmpty ||
        todaysIABController.text.isEmpty ||
        prevIABController.text.isEmpty) {
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

  void showCorrectionsConfirmationDialog() {
    final localTheme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.edit_note,
            color: localTheme.colorScheme.primary,
            size: 48,
          ),
          title: Text(
            'Confirm Correction',
            style: localTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to correct and overwrite the current data for this day?',
                style: localTheme.textTheme.bodyMedium?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone. All existing data for this day will be replaced.',
                style: localTheme.textTheme.bodySmall?.copyWith(
                  color: localTheme.colorScheme.error,
                  fontWeight: FontWeight.w500,
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
              // Use the variable to freeze the button while processing
              onPressed: isClockingOut
                  ? null
                  : () async {
                      // Let the function safely handle state updates and pops
                      await correct(dialogContext);
                    },
              child: isClockingOut
                  ? const SizedBox(
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
                        const Icon(
                          Icons.save_outlined,
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

  Future<void> correct(BuildContext dialogContext) async {
    // 1. Guard check BEFORE mutating processing states or dismissing UI
    if (!canCorrect) {
      ToastService.warning("Complete all required fields");
      return;
    }

    if (isClockingOut) return;

    // 2. Set loading state and close dialog safely
    setState(() {
      isClockingOut = true;
    });

    if (Navigator.canPop(dialogContext)) {
      Navigator.pop(dialogContext);
    }

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();

      final fs = FirebaseFirestore.instance;
      final userRef = fs.collection('users').doc(uid);
      final deviationsRef = fs.collection('deviations').doc(weekRange);

      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        ToastService.error("User not found");
        return;
      }
      
      final userName = userSnap.get('userName');
      final pendingAmountOld = userSnap.get('pendingAmount') ?? 0.0;
      final prevInApp = double.parse(prevIABController.text);
      final todaysIAB = double.parse(todaysIABController.text);

      // Expenses compilation
      Map<String, dynamic> expenseData = {};
      expenseControllers.forEach((key, ctrl) {
        if (expensesChecked[key]! && key != 'Other') {
          expenseData[key] = double.parse(ctrl.text);
        }
      });

      if (expensesChecked['Other']! && otherExpenseController.text.trim().isNotEmpty) {
        final description = otherExpenseController.text.trim();
        final value = double.parse(expenseControllers['Other']!.text);
        expenseData[description] = value;
      }

      final gross = double.parse(double.parse(grossIncomeController.text).toStringAsFixed(2));
      final commission = commissionPercentage;
      final netIncome = double.parse((gross * (1 - commission)
          - (todaysIAB - prevInApp)
          - expenseData.values.whereType<num>().fold(0.0, (s, v) => s + v)).toStringAsFixed(2));

      final clockoutData = {
        "grossIncome": gross,
        "todaysInAppBalance": todaysIAB,
        "previousInAppBalance": prevInApp,
        "inAppDifference": todaysIAB - prevInApp,
        "expenses": expenseData,
        "netIncome": netIncome,
        "clockinMileage": 0,
        "clockoutMileage": 0,
        "mileageDifference": 0,
        "posted_at": now,
        "timeElapsed": "Void due to correction",
      };

      final monthName = DateFormat("MMMM").format(now);
      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
        
      await userRef.update({
        "clockouts.$selectedDate": clockoutData,
        "pendingAmount": double.parse((pendingAmountOld + netIncome).toStringAsFixed(2)),
        "netIncomes.$monthName": FieldValue.increment(netIncome),
        "workedDays.$monthName": FieldValue.increment(1),
        'notifications.$notificationId': {
          'isRead': false,
          'message': 'You have successfully corrected this date.',
          'time': now,
        },
        "numberOfNotifications": FieldValue.increment(1),
      });

      final deviationData = {
        "grossIncome": gross,
        "netIncome": netIncome,
        "grossDeviation": gross - target,
        "netGrossDifference": gross - netIncome,
      };

      await deviationsRef.set({
        userName: {dayOfWeek: deviationData}
      }, SetOptions(merge: true));

      ToastService.success("Correction was completed successfully");

      await deleteThisRequirement(uid: uid, targetDate: selectedDate);
      await _updateYearlyAndMonthlyStats(
        userName: '$userName',
        gross: gross,
        netIncome: netIncome,
        expenseData: expenseData,
      );

      // Refresh data after successful correction runs
      await fetchInitialData();

    } on FirebaseException catch (e) {
      _showRetryDialog("Firestore error: ${e.code} - ${e.message}");
    } catch (e, stack) {
      debugPrint("Unexpected error: $e");
      debugPrint("Stacktrace: $stack");
      _showRetryDialog("Unexpected error occurred: date=$selectedDate, weekRange=$weekRange, dayOfWeek=$dayOfWeek. Please try again.");
    } finally {
      // 3. This block ALWAYS fires, ensuring your UI state variable is unlocked 
      if (mounted) {
        setState(() {
          isClockingOut = false;
        });
      }
    }
  }

  Future<void> _updateYearlyAndMonthlyStats({
    required String userName, // <-- pass this from clockOut
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
  
  void _showRetryDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title Row - Centered
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Correction Failed",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Large warning icon - centered
                Icon(
                  Icons.wifi_off_outlined,
                  color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                  size: 64,
                ),
                const SizedBox(height: 20),
                
                // Message - fully centered
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Buttons - spaced evenly
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text("Retry"),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text("Cancel"),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> deleteThisRequirement({
    required String uid,
    required String targetDate, // e.g. "09 Dec 2025"
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userDocRef = firestore.collection('users').doc(uid);

    try {
      // Get current requirements map
      final docSnap = await userDocRef.get();
      if (!docSnap.exists) {
        throw Exception('User document not found');
      }

      final data = docSnap.data();
      final requirements = data?['requirements'] as Map<String, dynamic>?;
      
      if (requirements == null) {
        throw Exception('No requirements found');
      }

      // Find the timestamp key with matching date
      String? timestampKeyToDelete;
      requirements.forEach((timestampKey, requirementData) {
        if (requirementData['date'] == targetDate) {
          timestampKeyToDelete = timestampKey;
        }
      });

      if (timestampKeyToDelete == null) {
        throw Exception('No requirement found for date: $targetDate');
      }
      // Delete the specific timestamp key
      await userDocRef.update({
        'requirements.$timestampKeyToDelete': FieldValue.delete(),
      });

      ToastService.success("$targetDate cleared.");
      grossIncomeController.clear();
      todaysIABController.clear();
      await fetchInitialData(); // refresh UI

    } catch (e) {
      ToastService.error('Error: $e');
    }
  }

  String resolveCorrectionsText({
    required bool isLoading,
    required bool isOnline,
    required bool isBlocked,
  }) {
    if (_isOnline == false) return "You are offline";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Correct";
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


                Text(
                  "Deviation: KSh ${deviation.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deviation < 0 ? Colors.red : Colors.green,
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: _buildDropdownField<String>(
                    value: selectedKey,
                    label: 'Select Date',
                    hint: 'Choose a date',
                    icon: Icons.calendar_today_outlined,
                    items: requirements.entries.map((entry) {
                      final key = entry.key;
                      final data = Map<String, dynamic>.from(entry.value);
                      return DropdownMenuItem(
                        value: key,
                        child: Text(data['date'] ?? "Unknown Date"),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) _updateVariables(value);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                

                // Gross Income
                _buildTextField(
                  controller: grossIncomeController,
                  label: 'Gross Income',
                  hint: 'Enter total income',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Commission (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: TextEditingController(), // Empty controller for disabled display
                  label: '${(commissionPercentage * 100).toStringAsFixed(0)}% Commission',
                  hint: 'Commission calculated',
                  icon: Icons.percent_outlined,
                ),
                const SizedBox(height: 12),


                // Today's IAB
                _buildTextField(
                  controller: todaysIABController,
                  label: "In-App Balance",
                  hint: 'Enter IAB for that day',
                  icon: Icons.analytics_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Previous IAB (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: prevIABController,
                  label: 'Previous IAB',
                  hint: 'Auto-filled from records',
                  icon: Icons.history_outlined,
                ),
                const SizedBox(height: 20),

                const Text("Expenses", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Expenses checkboxes
                ...expensesChecked.keys.map((key) {
                  final isEnabled = expensesChecked[key] ?? false;
                  final theme = Theme.of(context);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isEnabled,
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
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: expenseControllers[key],
                              enabled: isEnabled,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isEnabled 
                                  ? theme.colorScheme.onSurface  // Theme-aware text color
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter amount",
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: isEnabled 
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                                prefixIcon: Icon(
                                  Icons.attach_money_outlined,
                                  color: isEnabled 
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  size: 24,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: theme.colorScheme.outline!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: theme.colorScheme.outline!),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface,  // Theme surface color
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      controller: otherExpenseController,
                      decoration: const InputDecoration(
                        labelText: "Other Expense Description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Net Income
                Text(
                  "Net Income: KSh ${netIncome.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Correct Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!hasClockedOutToday && canCorrect && !isClockingOut && (_isOnline == true))
                        ? showCorrectionsConfirmationDialog
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
                            resolveCorrectionsText(
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
  required TextEditingController controller,
  bool enabled = true,
  required String label,
  required String hint,
  required IconData icon,
  TextInputType? keyboardType,
  bool obscureText = false,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    obscureText: obscureText,
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

// Reusable Dropdown Widget
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
    initialValue: value,
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
