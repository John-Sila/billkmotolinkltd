import 'dart:async';

import 'package:billkmotolinkltd/pages/widgets/qr_scanner.dart';
import 'package:billkmotolinkltd/services/config_service.dart';
import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:billkmotolinkltd/utils/utility_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SwapBatteries extends StatefulWidget {
  const SwapBatteries({super.key});

  @override
  State<SwapBatteries> createState() => SwapBatteriesState();
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


class SwapBatteriesState extends State<SwapBatteries> {
  bool scanningOnload = false;
  bool scanningOffload = false;

  List<String> scannedOnBatteries = [];
  List<String> scannedOnBatteryCodes = [];
  List<String> scannedOffBatteries = [];
  List<String> scannedOffBatteryCodes = [];

  List<String> destinations = [];
  String? selectedDestination;

  static const int maxOnScans = 1;
  static const int maxOffScans = 1;
  bool isSwapping = false;

  bool? isClockedIn;
  String userName = "";
  String currentBike = "";
  String _timeString = "";
  late Timer _timer;
  bool? _isOnline;
  bool freeAssignment = false;
  
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFreeAssignment();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    initializerFunctions();
    checkIsOnline();
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

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
    });
  }

  Future<void> initializerFunctions() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      isClockedIn = data['isClockedIn'] ?? false;
      userName = data['userName'] ?? "User";
      currentBike = data['currentBike'] ?? "None";
      isLoading = false;
    });

    // Fetch destinations
    final generalDoc =
        await FirebaseFirestore.instance.collection('general').doc('general_variables').get();
    destinations = List<String>.from(generalDoc.data()?['destinations'] ?? []);

  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
  Future<void> scanOffLoadBattery() async {
    if (scannedOffBatteries.length >= maxOffScans) {
      ToastService.warning("You have reached the 1-battery limit");
      return;
    }

    try {
      setState(() => scanningOffload = true);

      final qrCodeRaw = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );

      if (qrCodeRaw == null) {
        ToastService.warning("Scan was called off.");
        setState(() => scanningOffload = false);
        return;
      }

      final qrCode = cleanExtract(qrCodeRaw);

      // Prevent duplicate scans
      if (scannedOffBatteryCodes.contains(qrCode)) {
        ToastService.warning("Battery already scanned");
        setState(() => scanningOffload = false);
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('batteries')
          .where('qr_code', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ToastService.error("Battery not found");
        setState(() => scanningOffload = false);
        return;
      }

      final data = query.docs.first.data();
      final assignedRider = data['assignedRider']?.toString() ?? "None";
      final batteryName = data['batteryName'] ?? "Unknown Battery";

      if (assignedRider == userName) {
        setState(() {
          scannedOffBatteries.add(batteryName);
          scannedOffBatteryCodes.add(qrCode);
          scanningOffload = false;
        });
      } else {
        ToastService.error("Battery needs to be assigned to you first");
        setState(() => scanningOffload = false);
      }
    } catch (e) {
      ToastService.error("Error: ${e.toString()}");
      setState(() => scanningOffload = false);
    }
  }

  Future<void> scanOnLoadBattery() async {
    if (scannedOnBatteries.length >= maxOnScans) {
      ToastService.warning("You have reached the 2-battery limit");
      return;
    }

    try {
      setState(() => scanningOnload = true);

      final qrCodeRaw = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );

      if (qrCodeRaw == null) {
        ToastService.warning("Scan was called off.");
        setState(() => scanningOnload = false);
        return;
      }

      final qrCode = cleanExtract(qrCodeRaw);

      // Prevent duplicate scans
      if (scannedOnBatteryCodes.contains(qrCode)) {
        ToastService.warning("Battery already scanned");
        setState(() => scanningOnload = false);
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('batteries')
          .where('qr_code', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ToastService.error("Battery not found");
        setState(() => scanningOnload = false);
        return;
      }

      final data = query.docs.first.data();
      final assignedRider = data['assignedRider']?.toString() ?? "None";
      final assignedBike = data['assignedBike']?.toString() ?? "None";
      final batteryName = data['batteryName'] ?? "Unknown Battery";
      final isBooked = data['isBooked'] ?? false;
      final bookedBy = data['bookedBy'] ?? "another rider.";
      final storeAssignedRider = data['storeAssignedRider'] ?? "None";

      final isConfirmed = data['confirmedStatus'] ?? true; // default to true if field is missing, to avoid false negatives

      if (freeAssignment == false && isConfirmed == false) {
        ToastService.error("$batteryName's status hasn't been confirmed. Please try again later.");
        setState(() => scanningOnload = false);
        return;
      }

      if (isBooked && bookedBy != userName) {
        ToastService.error("Battery is booked by $bookedBy");
        setState(() => scanningOnload = false);
        return;
      }

      if (freeAssignment == false && storeAssignedRider != userName) {
        ToastService.warning("$batteryName is reserved. Contact manager.");
        setState(() => scanningOnload = false);
        return;
      }

      if (assignedRider == "None" && assignedBike == "None") {
        ToastService.success("Battery usable");
        setState(() {
          scannedOnBatteries.add(batteryName);
          scannedOnBatteryCodes.add(qrCode);
          scanningOnload = false;
        });
      } else {
        ToastService.error("Battery needs to be free");
        setState(() => scanningOnload = false);
      }
    } catch (e) {
      ToastService.error("Error: ${e.toString()}");
      setState(() => scanningOnload = false);
    }
  }
  
  Future<void> swapBatteries() async {
    if (scannedOnBatteries.isEmpty || scannedOffBatteries.isEmpty) {
      ToastService.warning("You need a battery from both lists.");
      return;
    }

    setState(() => isSwapping = true);

    final now = DateTime.now();
    final selectedLoc = selectedDestination;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final batch = FirebaseFirestore.instance.batch();

    try {
      /// --- 1. Update battery traces and metadata ---
      Future<void> updateBattery(String batteryName, {required bool onLoad}) async {
        final query = await FirebaseFirestore.instance
            .collection('batteries')
            .where('batteryName', isEqualTo: batteryName)
            .limit(1)
            .get();

        if (query.docs.isEmpty) return;

        final ref = query.docs.first.reference;
 
        // update battery state
        batch.update(ref, {
          'assignedRider': onLoad ? userName : "None",
          'storeAssignedRider': onLoad ? userName : "None",
          'assignedBike': onLoad ? currentBike : "None",
          'confirmedStatus': onLoad ? true : false,
          'isBooked': false,
          'batteryLocation': onLoad ? "In Motion" : selectedLoc ?? "Warehouse",
          'offTime': now,
        });
      }

      // Update onload batteries (None → assigned)
      for (final battery in scannedOnBatteries) {
        await updateBattery(battery, onLoad: true);
        
        // Update corresponding store document
        final storeQueryOnload = await FirebaseFirestore.instance
            .collection("store")
            .where("name", isEqualTo: battery)
            .limit(1)
            .get();

        if (storeQueryOnload.docs.isNotEmpty) {
          final ref = storeQueryOnload.docs.first.reference;
          final message = "Swapped in by $userName on ${AppDateUtils.formatStandard(now)}.";
          
          batch.update(ref, {
            "assignedTo": userName,
            "assignedToUid": uid,
            "movement": "Outgoing",
            "isAssigned": true,
            "confirmedStatus": true,
            "transactions": FieldValue.arrayUnion([{
              "message": message,
              "time": now,
            }]),
          });
        }
      }

      // Update offload batteries (assigned → None)
      for (final battery in scannedOffBatteries) {
        await updateBattery(battery, onLoad: false);
        
        // Update corresponding store document
        final storeQueryOffload = await FirebaseFirestore.instance
            .collection("store")
            .where("name", isEqualTo: battery)
            .limit(1)
            .get();

        if (storeQueryOffload.docs.isNotEmpty) {
          final ref = storeQueryOffload.docs.first.reference;
          final message = "Swapped out by $userName on ${AppDateUtils.formatStandard(now)}.";
          
          batch.update(ref, {
            "assignedTo": "None",
            "assignedToUid": "None",
            "isAssigned": false,
            "confirmedStatus": false,
            "movement": "Incoming",
            "droppedBy": userName,
            "transactions": FieldValue.arrayUnion([{
              "message": message,
              "time": now,
            }]),
          });
        }
      }

      /// --- 2. Commit all changes ---
      await batch.commit();

      ToastService.success("Battery swap successful!");
      setState(() => isSwapping = false);
      resetScans();
    } catch (e) {
      ToastService.error("Swap failed: ${e.toString()}");
      setState(() => isSwapping = false);
    }
  }

  /// Reset scanned batteries AND selected bike
  void resetScans() {
    setState(() {
      scannedOnBatteries.clear();
      scannedOnBatteryCodes.clear();
      scannedOffBatteries.clear();
      scannedOffBatteryCodes.clear();

      scanningOnload = false;
      scanningOffload = false;
    });
    ToastService.info("Scans reset successfully.");
  }

  void showSwapConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Swap"),
          content: Text(
              "Confirm battery swap."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSwapping
                  ? null
                  : () async {
                      Navigator.pop(context);
                      setState(() => isSwapping = true);
                      await swapBatteries(); // your async clock-in function
                      setState(() => isSwapping = false);
                    },
              child: isSwapping
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }
  
  String resolveSwapText({
    required bool isOnline,
    required bool isClockedIn,
    required bool isLoading,
    required bool isBlocked,
  }) {
    if (_isOnline == false) return "You are offline";
    if (!isClockedIn) return "You are not clocked in";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Swap";
  }


  @override
  Widget build(BuildContext context) {
    if (isClockedIn == null) {
      // still fetching
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


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


                // Live clock
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

                // -----------------------
                // 1. OFFLOAD SECTION
                // -----------------------
                const Text(
                  "Offload Batteries",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),
                if (scannedOffBatteries.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: scannedOffBatteries.map((battery) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          "Offload $battery",
                          style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.w900),
                        ),
                      );
                    }).toList(),
                  ),



                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: scanningOffload || scannedOffBatteries.length >= maxOffScans
                        ? null
                        : scanOffLoadBattery,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      scannedOffBatteries.length >= maxOffScans
                          ? "Scan Limit Reached"
                          : (scanningOffload ? "Scanning..." : "Scan Battery QR"),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 28),

                // -----------------------
                // 2. ONLOAD SECTION
                // -----------------------
                const Text(
                  "Onload Batteries",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),


                const SizedBox(height: 12),

                if (scannedOnBatteries.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: scannedOnBatteries.map((battery) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          "Load $battery",
                          style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.w900),
                        ),
                      );
                    }).toList(),
                  ),


                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: scanningOnload || scannedOnBatteries.length >= maxOnScans
                        ? null
                        : scanOnLoadBattery,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      scannedOnBatteries.length >= maxOnScans
                          ? "Scan Limit Reached"
                          : (scanningOnload ? "Scanning..." : "Scan Battery QR"),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 28),

                // location
                _buildDropdownField<String>(
                  value: selectedDestination,
                  label: "Select Location",
                  hint: destinations.isEmpty ? "No destinations available" : "Choose destination",
                  icon: Icons.location_on,
                  items: (destinations).map((loc) {
                    return DropdownMenuItem<String>(
                      value: loc,
                      child: Text(loc),
                    );
                  }).toList(),
                  onChanged: destinations.isEmpty ? null : (val) {
                    setState(() => selectedDestination = val);
                  },
                ),
                const SizedBox(height: 20),

                // -----------------------
                // Swap / Submit Button
                // -----------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (
                            scannedOnBatteries.isNotEmpty &&
                            scannedOffBatteries.isNotEmpty &&
                            selectedDestination != null &&
                            !isSwapping)
                        ? showSwapConfirmationDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isLoading) ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSwapping
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            resolveSwapText(
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
          ),
        ),
      ),
    );
  }

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

