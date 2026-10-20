// ignore_for_file: use_build_context_synchronously

import 'package:daitom/pages/widgets/mpesa_payment_dialog.dart';
import 'package:daitom/pages/widgets/progress_steps_dialog.dart';
import 'package:daitom/services/mpesa_payment_service.dart';
import 'package:daitom/services/payment_config.dart';
import 'package:daitom/services/toast_service.dart';
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

  /// A payment that went through but whose correction could not be saved
  /// (network drop, Firestore error...). It is reused on the next attempt so
  /// the rider is never asked to pay twice for the same correction.
  /// Held in memory only: it is lost if the app is closed.
  MpesaPaymentResult? _unrecordedPayment;

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

  void _updateState() {
    if (mounted) setState(() {});
  }

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
      // Always replace the local copy. If there are none left (e.g. the last
      // one was just corrected) the screen must not keep showing the old date,
      // otherwise the same day could be corrected, and charged, twice.
      final reqMap = Map<String, dynamic>.from(userData['requirements'] ?? {});
      requirements = reqMap;
      if (reqMap.isNotEmpty) {
        _updateVariables(reqMap.keys.first);
      } else {
        selectedKey = null;
        selectedDate = "";
        dayOfWeek = "";
        weekRange = "";
        appBalance = 0;
        prevIABController.clear();
      }

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      ToastService.error("Error fetching data: $e");
      if (mounted) setState(() => isLoading = false);
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

  bool _isNum(String s) => double.tryParse(s.trim()) != null;

  bool get canCorrect {
    // A requirement must be selected
    if (selectedKey == null) return false;

    // Every number must actually be a number (not just non-empty)
    if (!_isNum(grossIncomeController.text) ||
        !_isNum(todaysIABController.text) ||
        !_isNum(prevIABController.text)) {
      return false;
    }

    // All checked expenses must have a valid value
    for (var key in expensesChecked.keys) {
      if (!expensesChecked[key]!) continue;

      if (!_isNum(expenseControllers[key]!.text)) return false;

      // Other must have both amount AND description
      if (key == 'Other' && otherExpenseController.text.trim().isEmpty) {
        return false;
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
              if (_unrecordedPayment != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Your earlier M-Pesa payment will be used. You will not be charged again.',
                  style: localTheme.textTheme.bodySmall?.copyWith(
                    color: localTheme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (kMpesaPaymentEnabled && netIncome.round() >= 1) ...[
                const SizedBox(height: 12),
                Text(
                  'You will get an M-Pesa prompt for KES ${NumberFormat('#,##0').format(netIncome.round())}. Keep your phone nearby.',
                  style: localTheme.textTheme.bodySmall?.copyWith(
                    color: localTheme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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

  /// Extra line for error messages when money was taken but not recorded.
  String _paidNote() {
    final p = _unrecordedPayment;
    if (p == null) return '';
    return "\n\nYour M-Pesa payment (receipt ${p.receipt}) went through. "
        "Tap Retry and you will not be charged again.";
  }

  Future<void> correct(BuildContext dialogContext) async {
    // 1. Guard check BEFORE mutating processing states or dismissing UI
    if (!canCorrect) {
      ToastService.warning("Complete all required fields");
      return;
    }

    // Set synchronously, before any await, so a second tap cannot slip in.
    if (isClockingOut) return;

    // 2. Set loading state and close dialog safely
    setState(() {
      isClockingOut = true;
    });

    if (Navigator.canPop(dialogContext)) {
      Navigator.pop(dialogContext);
    }

    // The "what's happening now" dialog shown after the payment succeeds.
    ProgressStepsController? progress;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();

      final fs = FirebaseFirestore.instance;
      final userRef = fs.collection('users').doc(uid);
      final generalRef = fs.collection('general').doc('general_variables');

      // Capture the requirement being corrected now, so nothing on screen can
      // change it while the payment dialog is open.
      final reqKey = selectedKey!;

      // The day being corrected decides EVERY date-based path below, not today:
      //   users/{uid}                  clockouts.<dd MMM yyyy>
      //   users/{uid}                  netIncomes.<Month> / workedDays.<Month>
      //   deviations/<week label>      <userName>.<weekday>
      //   general/general_variables    annual_incomes.<year>... / monthly_incomes.<year>_<Month>...
      final correctedDate = _parseRequirementDate(selectedDate);
      if (correctedDate == null) {
        _showRetryDialog(
          "Could not read the date \"$selectedDate\". Pull down to refresh and try again.",
          allowRetry: false,
        );
        return;
      }
      final dateKey = DateFormat("dd MMM yyyy", "en_US").format(correctedDate);
      final weekdayLabel = DateFormat("EEEE", "en_US").format(correctedDate);
      final weekLabel = getWeekLabel(correctedDate);
      final monthName = DateFormat("MMMM").format(correctedDate);
      final year = correctedDate.year.toString();
      final monthKey = "${year}_$monthName";
      if (weekRange.isNotEmpty && weekRange != weekLabel) {
        debugPrint(
          'Requirement weekRange "$weekRange" differs from "$weekLabel"; '
          'using "$weekLabel", the same label clock-out uses.',
        );
      }
      final deviationsRef = fs.collection('deviations').doc(weekLabel);

      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        ToastService.error("User not found");
        return;
      }

      final riderName = (userSnap.data()?['userName'] ?? '').toString();

      // All parsing happens BEFORE the payment, so a bad number can never
      // cost the rider money.
      final prevInApp = double.parse(prevIABController.text);
      final todaysIAB = double.parse(todaysIABController.text);

      // Expenses compilation
      final Map<String, dynamic> expenseData = {};
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

      final double newExpenses =
          expenseData.values.whereType<num>().fold(0.0, (s, v) => s + v);

      final gross = double.parse(double.parse(grossIncomeController.text).toStringAsFixed(2));
      final commission = commissionPercentage;
      final netIncome = double.parse((gross * (1 - commission)
              - (todaysIAB - prevInApp)
              - newExpenses)
          .toStringAsFixed(2));

      // ---- M-Pesa payment ---------------------------------------------------
      // Same prompt as a normal clock-out. Nothing is written unless the
      // payment succeeds, and what gets recorded is what Safaricom confirmed.
      // If an earlier attempt was paid but not saved, that payment is reused
      // instead of prompting again.
      final amountDue = netIncome.round();
      var payment = _unrecordedPayment;
      if (payment == null && kMpesaPaymentEnabled && amountDue >= 1) {
        if (!mounted) return;
        payment = await showMpesaPaymentDialog(
          context,
          amount: amountDue,
          initialPhone: (userSnap.data()?['phoneNumber'] ?? '').toString(),
        );
        if (payment == null) {
          ToastService.warning("Correction cancelled. The payment was not completed.");
          return;
        }
        _unrecordedPayment = payment; // keep it until the save succeeds
      }
      final paidAmount = payment?.amount ?? 0;

      // ---- Progress dialog --------------------------------------------------
      // Opens the moment the payment is confirmed and stays until every write
      // is finished, so the rider knows when it is really done.
      progress = ProgressStepsController([
        if (payment != null) 'Payment confirmed',
        'Saving correction',
        'Refreshing your data',
      ], title: 'Finishing correction');
      if (!mounted) return;
      progress.show(context);
      progress.begin();
      if (payment != null) await progress.next(); // Payment confirmed

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
        if (payment != null)
          "payment": {
            "method": "mpesa_stk",
            "checkoutId": payment.checkoutId,
            "receipt": payment.receipt,
            "amountDue": amountDue,
            "amountPaid": payment.amount,
            "paidAt": DateTime.now(),
          },
      };

      final deviationData = {
        "grossIncome": gross,
        "netIncome": netIncome,
        "grossDeviation": gross - target,
        "netGrossDifference": gross - netIncome,
      };

      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

      double r2(double v) => double.parse(v.toStringAsFixed(2));

      // ---- One atomic save ----------------------------------------------------
      // Clock-out record, pending amount, monthly totals, deviations, annual and
      // monthly stats and the requirement delete all succeed or fail together.
      // Increments (not absolute values) are used so a stale read can never
      // overwrite a newer number.
      var requirementGone = false;

      await fs.runTransaction((tx) async {
        requirementGone = false; // the handler can run more than once

        final data = (await tx.get(userRef)).data() ?? {};

        // The requirement must still exist. If it doesn't, someone (another
        // device, an admin) already used or changed it: write nothing.
        final reqs = Map<String, dynamic>.from(data['requirements'] ?? {});
        if (!reqs.containsKey(reqKey)) {
          requirementGone = true;
          return;
        }

        // If this day already has a record we are REPLACING it, so only the
        // difference is applied and the day is not counted as worked twice.
        final old = (data['clockouts'] as Map?)?[dateKey] as Map?;
        final hadRecord = old != null;
        final double oldNet = ((old?['netIncome'] ?? 0) as num).toDouble();
        final double oldGross = ((old?['grossIncome'] ?? 0) as num).toDouble();
        final double oldExp = ((old?['expenses'] as Map?)?.values ?? const [])
            .whereType<num>()
            .fold(0.0, (s, v) => s + v);

        final dNet = netIncome - oldNet;
        final dGross = gross - oldGross;
        final dExp = newExpenses - oldExp;

        tx.update(userRef, {
          "clockouts.$dateKey": clockoutData,
          "pendingAmount": FieldValue.increment(r2(dNet - paidAmount)),
          "netIncomes.$monthName": FieldValue.increment(r2(dNet)),
          if (!hadRecord) "workedDays.$monthName": FieldValue.increment(1),
          "requirements.$reqKey": FieldValue.delete(),
          'notifications.$notificationId': {
            'isRead': false,
            'message': 'You have successfully corrected this date.',
            'time': now,
          },
          "numberOfNotifications": FieldValue.increment(1),
        });

        tx.set(
          deviationsRef,
          {
            riderName: {weekdayLabel: deviationData}
          },
          SetOptions(merge: true),
        );

        tx.set(
          generalRef,
          {
            'annual_incomes': {
              year: {
                riderName: {
                  'gross': FieldValue.increment(r2(dGross)),
                  'net': FieldValue.increment(r2(dNet)),
                  'expenses': FieldValue.increment(r2(dExp)),
                  'dateAppended': now,
                }
              }
            },
            'monthly_incomes': {
              monthKey: {
                riderName: {
                  'gross': FieldValue.increment(r2(dGross)),
                  'net': FieldValue.increment(r2(dNet)),
                  'expenses': FieldValue.increment(r2(dExp)),
                  'dateAppended': now,
                }
              }
            },
          },
          SetOptions(merge: true),
        );
      });

      if (requirementGone) {
        // Nothing was written. Any payment stays remembered (see _paidNote) and
        // is credited on the rider's next correction.
        await progress.abort();
        _showRetryDialog(
          "This requirement was already corrected or changed. Pull down to refresh."
          "${_unrecordedPayment != null ? "\n\nYour M-Pesa payment (receipt ${_unrecordedPayment!.receipt}) went through. If you were charged, show this receipt to an admin." : ""}",
          allowRetry: false,
        );
        await fetchInitialData();
        return;
      }

      // Saved. The payment is now accounted for.
      _unrecordedPayment = null;

      if (payment != null) {
        try {
          await MpesaPaymentService().consume(payment.checkoutId);
        } catch (e) {
          debugPrint('Could not mark payment as used: $e');
        }
      }
      await progress.next(); // Saving correction

      if (!mounted) return;
      _resetForm();
      await fetchInitialData();
      await progress.next(); // Refreshing your data

      await progress.finish(); // all green, then closes
      ToastService.success("Correction was completed successfully");
    } on FirebaseException catch (e) {
      await progress?.abort();
      _showRetryDialog("Firestore error: ${e.code} - ${e.message}${_paidNote()}");
    } catch (e, stack) {
      await progress?.abort();
      debugPrint("Unexpected error: $e");
      debugPrint("Stacktrace: $stack");
      _showRetryDialog(
        "Unexpected error occurred: date=$selectedDate, weekRange=$weekRange, dayOfWeek=$dayOfWeek. Please try again.${_paidNote()}",
      );
    } finally {
      // Safety net: never leave the progress dialog stuck on screen.
      progress?.close();

      // 3. This block ALWAYS fires, ensuring your UI state variable is unlocked
      if (mounted) {
        setState(() {
          isClockingOut = false;
        });
      }
    }
  }

  /// Clears everything the rider typed so the next correction starts clean.
  void _resetForm() {
    grossIncomeController.clear();
    todaysIABController.clear();
    otherExpenseController.clear();
    expenseControllers.forEach((_, c) => c.clear());
    setState(() {
      expensesChecked.updateAll((_, __) => false);
      netIncome = 0.0;
      deviation = 0.0;
      totalExpenses = 0.0;
    });
  }

  /// Reads the requirement's date text (e.g. "09 Dec 2025").
  /// Returns null if it can't be read, so we never write to the wrong day.
  DateTime? _parseRequirementDate(String raw) {
    final text = raw.trim();
    for (final pattern in const ['dd MMM yyyy', 'd MMM yyyy', 'dd MMMM yyyy']) {
      try {
        return DateFormat(pattern, 'en_US').parse(text);
      } catch (_) {
        // try the next pattern
      }
    }
    return null;
  }

  void _showRetryDialog(String message, {bool allowRetry = true}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(dialogContext).colorScheme.surface,
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
                      color: Theme.of(dialogContext).colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Correction Failed",
                        style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(dialogContext).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Large warning icon - centered
                Icon(
                  Icons.wifi_off_outlined,
                  color: Theme.of(dialogContext).colorScheme.error.withOpacity(0.3),
                  size: 64,
                ),
                const SizedBox(height: 20),

                // Message - fully centered
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (allowRetry) ...[
                      Expanded(
                        child: TextButton.icon(
                          // Retry reopens the confirmation, so it really retries.
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            if (canCorrect && !isClockingOut) {
                              showCorrectionsConfirmationDialog();
                            }
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Retry"),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(dialogContext).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(allowRetry ? "Cancel" : "Close"),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
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
    if (!mounted) return;
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
      child: Scaffold(
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
                                    ? theme.colorScheme.onSurface // Theme-aware text color
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
                                  borderSide: BorderSide(color: theme.colorScheme.outline),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: theme.colorScheme.outline),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface, // Theme surface color
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
      ),
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
