import 'dart:async';

import 'package:billkmotolinkltd/pages/widgets/qr_scanner.dart';
import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:billkmotolinkltd/utils/utility_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ClockIn extends StatefulWidget {
  const ClockIn({super.key});

  @override
  State<ClockIn> createState() => _ClockInState();
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

class _ClockInState extends State<ClockIn> {
  String? selectedBike;
  Map<String, dynamic> bikes = {}; // all bikes from general_variables

  bool scanning = false;

  List<String> scannedBatteries = [];      // Stores battery names
  List<String> scannedBatteryCodes = [];   // Stores cleaned QR codes
  static const int maxScans = 2;
  bool isClockingIn = false;

  bool? isClockedIn;
  bool? isWorkingOnSunday;
  bool? isVerified;
  String userName = "";
  String _timeString = "";
  late Timer _timer;
  bool? _isOnline;
  bool isLoading = true;
  late Future<Map<String, dynamic>> _bikesDisplayFuture;


  final _firestore = FirebaseFirestore.instance;

  /// The shift ('day' | 'night') this rider was assigned to on the Assignments
  /// page. null = not set yet (e.g. assigned before shifts existed).
  String? assignedShift;

  /// Reads the rider's single assigned bike + shift, set via the Assignments page.
  Future<void> _loadAssignedBike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    setState(() {
      selectedBike = data['assignedBikeName']?.toString();
      if (selectedBike != null && selectedBike!.isEmpty) selectedBike = null;

      final rawShift = data['assignedShift']?.toString().trim().toLowerCase();
      assignedShift =
          (rawShift == 'day' || rawShift == 'night') ? rawShift : null;
    });
  }

  String _shiftText() {
    switch (assignedShift) {
      case 'day':
        return 'Day shift';
      case 'night':
        return 'Night shift';
      default:
        return 'Shift not set';
    }
  }

  /// Small pill showing the shift on the assigned-bike card.
  Widget _buildShiftChip() {
    final isSet = assignedShift != null;
    final isNight = assignedShift == 'night';

    final Color color = !isSet
        ? Colors.orange
        : (isNight ? Colors.indigo[400]! : Colors.amber[800]!);
    final IconData icon = !isSet
        ? Icons.help_outline_rounded
        : (isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded);
    final String text =
        isSet ? _shiftText() : 'Shift not set — contact your admin';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bikesDisplayFuture = fetchBikes();

    _loadAssignedBike();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    checkClockInStatus();
    checkIsOnline();
    loadBikes();
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

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
    });
  }

  Future<void> checkClockInStatus() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      isClockedIn = data['isClockedIn'] ?? false;
      isWorkingOnSunday = data['isWorkingOnSunday'] ?? false;
      isVerified = data['isVerified'] ?? false;
      userName = data['userName'] ?? "User";
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> loadBikes() async {
    final data = await fetchBikes();
    setState(() {
      bikes = Map<String, dynamic>.from(data); // deep copy
      _bikesDisplayFuture = Future.value(bikes);
    });
  }

  /// Fetch all bikes
  Future<Map<String, dynamic>> fetchBikes() async {
    
    final doc = await FirebaseFirestore.instance
        .collection('general')
        .doc('general_variables')
        .get();

    final bikes = doc.data()?['bikes'] as Map<String, dynamic>? ?? {};
    return bikes;
  }

  /// Clean QR code extract
  String cleanExtract(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  /// Scan battery
  Future<void> scanBattery() async {
    if (scannedBatteries.length >= maxScans) {
      ToastService.warning("You can only scan up to $maxScans batteries");
      return;
    }

    try {
      setState(() => scanning = true);

      final qrCodeRaw = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );

      if (qrCodeRaw == null) {
        ToastService.warning("Scan was called off");
        setState(() => scanning = false);
        return;
      }

      final qrCode = cleanExtract(qrCodeRaw);

      // Prevent duplicate scans
      if (scannedBatteryCodes.contains(qrCode)) {
        ToastService.warning("You have already scanned this battery");
        setState(() => scanning = false);
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('batteries')
          .where('qr_code', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ToastService.error("This battery is unregistered in the system");
        setState(() => scanning = false);
        return;
      }

      final data = query.docs.first.data();
      final assignedRider = data['assignedRider']?.toString() ?? "None";
      final assignedBike = data['assignedBike']?.toString() ?? "None";
      final batteryName = data['batteryName'] ?? "Unknown Battery";

      final isBooked = data['isBooked'] ?? false;
      final bookedBy = data['bookedBy'] ?? "another rider.";

      if (isBooked && bookedBy != userName) {
        ToastService.warning("$batteryName is currently booked by $bookedBy");
        return;
      }

      if (assignedRider == "None") {
        ToastService.success("$batteryName scanned successfully");
        setState(() {
          scannedBatteries.add(batteryName);
          scannedBatteryCodes.add(qrCode);
          scanning = false;
        });
      } else {
        ToastService.warning("$batteryName is currently assigned to $assignedRider with $assignedBike");
        setState(() => scanning = false);
      }
    } catch (e) {
      ToastService.error("Error: ${e.toString()}");
      setState(() => scanning = false);
    }
  }


  Future<void> clockIn() async {
    if (selectedBike == null) {
      ToastService.error("Select a bike");
      return;
    }

    // Local copies so they can't change under us mid-flight.
    final bikeName = selectedBike!;
    final shift = assignedShift;
    if (shift == null) {
      ToastService.error("Your shift isn't set — ask your admin to re-assign your bike");
      return;
    }

    if (scannedBatteries.isEmpty) {
      ToastService.error("Scan at least one battery");
      return;
    }

    if (isClockingIn) return;

    setState(() {
      isClockingIn = true;
    });

    try {
      ToastService.info("Clocking in...");

      final now = DateTime.now();
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(uid);

      final userSnapshot = await userDocRef.get();

      final userName =
          userSnapshot.data()?['userName']?.toString() ?? "Unknown";

      final notificationId =
          DateTime.now().millisecondsSinceEpoch.toString();

      await userDocRef.update({
        'currentBike': selectedBike,
        // Remembered so clock-out closes out the SAME shift even if an admin
        // re-assigns this rider while they're on the road.
        'currentShift': shift,
        'clockInTime': now,
        'isClockedIn': true,
        'notifications.$notificationId': {
          'isRead': false,
          'message': "You're now clocked in.",
          'time': now,
        },
        'numberOfNotifications': FieldValue.increment(1),
      });

      // Update batteries
      for (final batteryName in scannedBatteries) {
        final batteryQuery = await FirebaseFirestore.instance
            .collection('batteries')
            .where('batteryName', isEqualTo: batteryName)
            .limit(1)
            .get();

        if (batteryQuery.docs.isEmpty) continue;

        await batteryQuery.docs.first.reference.update({
          'assignedRider': userName,
          'assignedBike': selectedBike,
          'isBooked': false,
          'batteryLocation': 'In Motion',
          'offTime': now,
        });
      }

      // Update the bike's slot for THIS rider's shift only. A bike has a day
      // slot and a night slot; the other shift's rider must never be touched.
      // Field-level update (not a rewrite of the whole `bikes` map) so a day
      // rider and a night rider clocking in around shift change can't
      // overwrite each other.
      final generalRef = FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables');

      final generalSnapshot = await generalRef.get();

      final bikes = Map<String, dynamic>.from(
        generalSnapshot.data()?['bikes'] ?? {},
      );

      if (bikes.containsKey(bikeName)) {
        await generalRef.update({
          'bikes.$bikeName.$shift.isAssigned': true,
          'bikes.$bikeName.$shift.assignedRider': userName,
        });
      }

      ToastService.success("Clock-in successful");

      setState(() {
        isClockedIn = true;
      });

      resetScans();
    } catch (e, stackTrace) {
      debugPrint("ClockIn Error: $e");
      debugPrint(stackTrace.toString());

      ToastService.error("Clock-in failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          isClockingIn = false;
        });
      }
    }
  }

  /// Reset scanned batteries only — the assigned bike stays put
  void resetScans() {
    setState(() {
      scannedBatteries.clear();
      scannedBatteryCodes.clear();
      scanning = false;
    });
    ToastService.info("Scans reset");
  }

  void showClockInDialog() {
    if (selectedBike == null || assignedShift == null) return;
    showClockInConfirmationDialog();
  }

  void showClockInConfirmationDialog() {
    final localTheme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.access_time,
            color: localTheme.colorScheme.primary,
            size: 48,
          ),
          title: Text(
            'Confirm Clock-In',
            style: localTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review your details before clocking in:',
                style: localTheme.textTheme.bodyMedium?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                localTheme,
                icon: Icons.bike_scooter,
                label: 'Bike',
                value: selectedBike ?? 'None selected',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                localTheme,
                icon: assignedShift == 'night'
                    ? Icons.nightlight_round
                    : Icons.wb_sunny_rounded,
                label: 'Shift',
                value: _shiftText(),
                isWarning: assignedShift == null,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                localTheme,
                icon: Icons.battery_full,
                label: 'Batteries',
                value: scannedBatteries.isNotEmpty 
                  ? scannedBatteries.join(', ') 
                  : 'None scanned',
                isWarning: scannedBatteries.isEmpty,
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
                backgroundColor: isClockingIn 
                  ? localTheme.colorScheme.primaryContainer 
                  : localTheme.colorScheme.primary,
                surfaceTintColor: Colors.transparent,
              ),
              onPressed: isClockingIn
                  ? null
                  : () async {
                      // 1. Close the dialog immediately
                      Navigator.pop(dialogContext);
                      
                      // 2. Trigger the primary logging execution flow 
                      // (It handles its own state updates internally)
                      await clockIn();
                    },
              child: isClockingIn
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

  Widget _buildInfoRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    bool isWarning = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isWarning 
            ? theme.colorScheme.error 
            : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ':',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isWarning 
              ? theme.colorScheme.error 
              : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  String resolveClockInText({
    required bool isOnline,
    required bool isClockedIn,
    required bool isLoading,
    required bool isBlocked,
  }) {
    if (_isOnline == false) return "You are offline";
    if (isClockedIn) return "You are clocked in already";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Clock In";
  }

  @override
  Widget build(BuildContext context) {
    if (isClockedIn == null || isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final isSunday = now.weekday == DateTime.sunday;

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _bikesDisplayFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bikes = snapshot.data!;
          bikes.entries
            .where((entry) => entry.value['isAssigned'] != true)
            .map((entry) => entry.key)
            .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSunday && isWorkingOnSunday == false)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
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
                            'You cannot clock in today.',
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

                if (!isVerified!)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.yellow[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You need to be verified to continue.',
                            style: TextStyle(
                              color: Colors.yellow[700],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _timeString,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                /// Assigned bike (set via the Assignments page — not editable here)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: selectedBike != null
                        ? Colors.blue.withOpacity(0.08)
                        : Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedBike != null
                          ? Colors.blue.withOpacity(0.25)
                          : Colors.red.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.two_wheeler_outlined,
                        color: selectedBike != null ? Colors.blue[600] : Colors.red,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Your assigned bike",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedBike ?? "No bike assigned yet - contact your admin",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: selectedBike != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.red,
                              ),
                            ),
                            if (selectedBike != null) ...[
                              const SizedBox(height: 8),
                              _buildShiftChip(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                /// Scan Battery button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: scanning || scannedBatteries.length >= maxScans
                        ? null
                        : scanBattery,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      scannedBatteries.length >= maxScans
                          ? "Scan Limit Reached"
                          : (scanning ? "Scanning..." : "Scan Battery QR"),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// Reset button (red, borderless)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: resetScans,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.all(0),
                    ),
                    child: const Text("Reset"),
                  ),
                ),

                const SizedBox(height: 22),

                /// Display scanned batteries
                if (scannedBatteries.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: scannedBatteries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final battery = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withValues(alpha: 0.1),
                              Colors.blue.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue,
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    battery,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    height: 2,
                                    width: 60,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withValues(alpha: 0.6),
                                          Colors.blue.withValues(alpha: 0.2),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedBike != null &&
                            assignedShift != null &&
                            scannedBatteries.isNotEmpty &&
                            !isClockingIn &&
                            (!isSunday || isWorkingOnSunday == true) &&
                            isVerified == true)
                        ? showClockInDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (isClockedIn ?? false) ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isClockingIn
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            resolveClockInText(
                              isOnline: (_isOnline == true) ? true : false,
                              isClockedIn: isClockedIn == true,
                              isLoading: isLoading,
                              isBlocked: false,
                            ),
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              
              
              ],
            ),
          );
        }
      ),
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