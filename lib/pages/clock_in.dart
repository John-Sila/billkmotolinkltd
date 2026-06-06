import 'dart:async';

import 'package:billkmotolinkltd/pages/widgets/qr_scanner.dart';
import 'package:billkmotolinkltd/services/config_service.dart';
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

class _AssignmentResult {
  final bool freeAssignment;
  final List<_AssignedItem> assignedItems;

  _AssignmentResult({
    required this.freeAssignment,
    required this.assignedItems,
  });
}

class _AssignedItem {
  final String id;
  final String name;
  final String assignedTo;

  _AssignedItem({
    required this.id,
    required this.name,
    required this.assignedTo,
  });
}

class _ClockInState extends State<ClockIn> {
  String? selectedBike;
  Map<String, dynamic> bikes = {}; // all bikes from general_variables
  List<String> bikeNamesForDropdown = []; // only unassigned bike
  List<String> assignedBikeIds = [];                // IDs from store
  Map<String, String> assignedBikeNameById = {};

  bool scanning = false;
  bool freeAssignment = false;

  List<String> scannedBatteries = [];      // Stores battery names
  List<String> scannedBatteryCodes = [];   // Stores cleaned QR codes
  static const int maxScans = 2;
  final TextEditingController mileageController = TextEditingController();
  bool isClockingIn = false;

  bool? isClockedIn;
  bool? isWorkingOnSunday;
  bool? isVerified;
  String userName = "";
  String _timeString = "";
  late Timer _timer;
  bool? _isOnline;
  bool isLoading = true;
  late final Future<_AssignmentResult> _assignmentFuture;


  final _firestore = FirebaseFirestore.instance;

  Future<_AssignmentResult> _loadAssignmentStatus({
    required String currentUserUid,
  }) async {
    // 1. Get freeAssignment flag
    final generalDoc = await _firestore
        .collection('general')
        .doc('general_variables')
        .get();

    final bool freeAssignment =
        (generalDoc.data()?['freeAssignment'] as bool?) ?? false;

    // If true, we don't need to query store
    if (freeAssignment) {
      return _AssignmentResult(
        freeAssignment: true,
        assignedItems: const [],
      );
    }

    // 2. Otherwise, fetch store items assigned to this rider (by UID)
    final storeSnapshot = await _firestore
        .collection('store')
        .where('assignedToUid', isEqualTo: currentUserUid)
        .get();

    final assignedItems = storeSnapshot.docs.map((doc) {
      final data = doc.data();
      return _AssignedItem(
        id: doc.id,
        name: data['itemName'] ?? data['name'] ?? doc.id,
        assignedTo: data['assignedTo'] ?? '',
      );
    }).toList();

    return _AssignmentResult(
      freeAssignment: false,
      assignedItems: assignedItems,
    );
  }

  @override
  void initState() {
    super.initState();
    final String userUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    _assignmentFuture = _loadAssignmentStatus(currentUserUid: userUid);

    _assignmentFuture.then((result) {
      if (!result.freeAssignment) {
        loadAssignedBikesFromStore(userName: userName);
      } else {
        loadBikes();
      }
    });

    _loadFreeAssignment();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
 
    mileageController.addListener(() {
      setState(() {}); // rebuild button when text changes
    });

    checkClockInStatus();
    checkIsOnline();
    loadBikes();
  }

  Future<void> _loadFreeAssignment() async {
    final value = await ConfigService.getFreeAssignment();

    setState(() {
      freeAssignment = value;
    });
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

  Future<void> loadAssignedBikesFromStore({
    required String userName,
  }) async {
    assignedBikeIds.clear();
    assignedBikeNameById.clear();

    try {
      final storeSnapshot = await _firestore
          .collection('store')
          .where('category', isEqualTo: "Bikes")
          .where('assignedTo', isEqualTo: userName)
          .get();

      final List<String> ids = [];
      final Map<String, String> nameMap = {};

      for (final doc in storeSnapshot.docs) {
        final id = doc.id;
        final data = doc.data();

        final displayName =
            (data['name'] ?? data['itemName'] ?? id).toString();

        ids.add(id);
        nameMap[id] = displayName;
      }

      setState(() {
        assignedBikeIds = ids;
        assignedBikeNameById = Map<String, String>.from(nameMap);
        bikeNamesForDropdown = ids.map((id) => nameMap[id]!).toList(); // list of names
        if (selectedBike == null && ids.isNotEmpty) {
          selectedBike = nameMap[ids.first]; // set name, not ID
        }
      });
    } catch (e) {
      setState(() {
        assignedBikeIds = [];
        assignedBikeNameById = {};
        bikeNamesForDropdown = [];
        selectedBike = null;
      });
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
    mileageController.dispose(); // only this controller exists here
    super.dispose();
  }

  Future<void> loadBikes() async {
    final data = await fetchBikes();
    setState(() {
      bikes = Map<String, dynamic>.from(data); // deep copy

      // Only unassigned bikes for the dropdown
      bikeNamesForDropdown = bikes.keys.toList();
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
      final storeAssignedRider = data['storeAssignedRider'] ?? "None";

      final isBooked = data['isBooked'] ?? false;
      final bookedBy = data['bookedBy'] ?? "another rider.";
      final isConfirmed = data['confirmedStatus'] ?? true; // default to true if field is missing, to avoid false negatives

      if (freeAssignment == false && isConfirmed == false) {
        ToastService.error("$batteryName's status hasn't been confirmed. Please try again later.");
        setState(() => scanning = false);
        return;
      }

      if (isBooked && bookedBy != userName) {
        ToastService.warning("$batteryName is currently booked by $bookedBy");
        return;
      }

      if (freeAssignment == false && storeAssignedRider != userName) {
          ToastService.warning("$batteryName is reserved. Contact manager.");
          setState(() => scanning = false);
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
    final mileageText = mileageController.text.trim();

    if (selectedBike == null) {
      ToastService.error("Select a bike");
      return;
    }

    if (scannedBatteries.isEmpty) {
      ToastService.error("Scan at least one battery");
      return;
    }

    if (mileageText.isEmpty) {
      ToastService.error("Enter mileage");
      return;
    }

    final int? parsedMileage = int.tryParse(mileageText);

    if (parsedMileage == null) {
      ToastService.error("Mileage must be a valid whole number");
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

      // Optional debugging for this issue
      debugPrint(
        "ClockIn -> User: $userName, Mileage Text: '$mileageText', Parsed: $parsedMileage",
      );

      await userDocRef.update({
        'currentBike': selectedBike,
        'clockInTime': now,
        'clockinMileage': parsedMileage, // guaranteed non-null
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
          'storeAssignedRider': userName,
          'batteryLocation': 'In Motion',
          'offTime': now,
        });
      }

      // Update bike assignment
      final generalRef = FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables');

      final generalSnapshot = await generalRef.get();

      final bikes = Map<String, dynamic>.from(
        generalSnapshot.data()?['bikes'] ?? {},
      );

      if (bikes.containsKey(selectedBike)) {
        bikes[selectedBike!] = {
          ...Map<String, dynamic>.from(bikes[selectedBike!]),
          'isAssigned': true,
          'assignedRider': userName,
        };
      }

      await generalRef.update({
        'bikes': bikes,
      });

      // Store transactions
      final storeQuery = await FirebaseFirestore.instance
          .collection('store')
          .where('assignedTo', isEqualTo: userName)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in storeQuery.docs) {
        batch.update(doc.reference, {
          'transactions': FieldValue.arrayUnion([
            {
              'message':
                  'Clocked in with $userName on ${AppDateUtils.formatStandard(now)}.',
              'time': now,
            }
          ]),
        });
      }

      await batch.commit();

      ToastService.success("Clock-in successful");

      setState(() {
        isClockedIn = true;
        selectedBike = null;
      });

      resetScans();
      mileageController.clear();
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

  /// Reset scanned batteries AND selected bike
  void resetScans() {
    setState(() {
      scannedBatteries.clear();
      scannedBatteryCodes.clear();
      selectedBike = null;
      scanning = false;
    });
    ToastService.info("Scans reset");
  }

  Future<List<QueryDocumentSnapshot>> _fetchUnresolvedDamages(String bikeId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('damagesReports')
        .doc(bikeId)
        .collection('items')
        .where('resolved', isEqualTo: true)
        .where('confirmed', isEqualTo: false)
        .get();

    return snapshot.docs;
  }

  void showClockInDialog() async {
    if (selectedBike == null) return;

    final unresolved = await _fetchUnresolvedDamages(selectedBike!);

    if (unresolved.isNotEmpty) {
      _showDamageResolutionDialog(unresolved);
      return;
    }

    showClockInConfirmationDialog(); // existing dialog
  }

  void _showDamageResolutionDialog(List<QueryDocumentSnapshot> items) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Pending Damage Reviews"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['message'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await doc.reference.update({
                                    'declined': true,
                                    'confirmed': false,
                                    'resolved': false,
                                    'declinedBy': userName,
                                    'declinedAt': DateTime.now(),
                                  });

                                  setState(() {
                                    items.remove(doc);
                                  });
                                  ToastService.info("Resolution declined");

                                  if (items.isEmpty) {
                                    Navigator.pop(context);
                                    showClockInConfirmationDialog();
                                  }
                                },
                                child: const Text("Decline"),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () async {
                                  await doc.reference.update({
                                    'confirmed': true,
                                    'declined': false,
                                    'resolved': true,
                                    'confirmedBy': userName,
                                    'confirmedAt': DateTime.now(),
                                  });

                                  setState(() {
                                    items.remove(doc);
                                  });
                                  ToastService.success("Resolution confirmed");
                                  if (items.isEmpty) {
                                    Navigator.pop(context);
                                    showClockInConfirmationDialog();
                                  }
                                },
                                child: const Text("Confirm"),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
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
                icon: Icons.battery_full,
                label: 'Batteries',
                value: scannedBatteries.isNotEmpty 
                  ? scannedBatteries.join(', ') 
                  : 'None scanned',
                isWarning: scannedBatteries.isEmpty,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                localTheme,
                icon: Icons.speed,
                label: 'Mileage',
                value: '${mileageController.text.trim()} km',
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
                      Navigator.pop(dialogContext);
                      setState(() => isClockingIn = true);
                      await clockIn();
                      setState(() => isClockingIn = false);
                    },
              child: isClockingIn
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
        future: fetchBikes(),
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

                /// Bike dropdown
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedBike,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Select Bike",
                      hintText: "Choose available bike",
                      prefixIcon: Icon(Icons.two_wheeler_outlined, color: Colors.blue[600]),
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
                      labelStyle: TextStyle(color: Colors.grey[700]),
                    ),

                    items: bikeNamesForDropdown.map((bikeName) {
                      final isAssigned = (bikes[bikeName]?['isAssigned'] ?? false) as bool;

                      final color = Theme.of(context).colorScheme.onSurface.withOpacity(
                        isAssigned ? 0.4 : 1.0, // lighter for disabled, full for enabled
                      );

                      final child = Text(
                        bikeName,
                        style: TextStyle(color: color),
                      );

                      return DropdownMenuItem<String>(
                        value: bikeName,
                        enabled: !isAssigned, // only unassigned bikes selectable
                        child: child,
                      );
                    }).toList(),
                                    
                    onChanged: (value) {
                      setState(() => selectedBike = value);
                    },
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

                const SizedBox(height: 20),

                _buildTextField(
                  enabled: true,
                  controller: mileageController,
                  label: 'Clock-In Mileage',
                  hint: '',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  icon: Icons.history,
                  validator: (v) => v == null || v.isEmpty ? 'Enter mileage' : null,
                ),
                const SizedBox(height: 24),

                // Fixed height so content never “jumps”
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60), // minimum 60px always
                  child: FutureBuilder<_AssignmentResult>(
                    future: _assignmentFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting ||
                          !snapshot.hasData) {
                        // Instead of shrink(), keep empty space:
                        return const SizedBox(height: 60);
                      }

                      final result = snapshot.data!;
                      final freeAssignment = result.freeAssignment;
                      final assignedItems = result.assignedItems;

                      if (freeAssignment) {
                        loadBikes();
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "You can use any bike and battery of your choice.",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.green.shade800),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        loadAssignedBikesFromStore(userName: userName);
                      }

                      if (assignedItems.isEmpty) {
                        return const SizedBox(height: 60); // keep height consistent
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "By clocking in, you assume responsibility of the following until confirmed back to the warehouse.",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.orange.shade800),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...assignedItems.map((item) {
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.electric_bike),
                                title: Text(item.name),
                                subtitle: Text("ID: ${item.id}"),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    
                    
                    
                    
                    },
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedBike != null &&
                            scannedBatteries.isNotEmpty &&
                            mileageController.text.trim().isNotEmpty &&
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
