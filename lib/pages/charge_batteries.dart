import 'dart:async';

import 'package:billkmotolinkltd/pages/widgets/qr_scanner.dart';
import 'package:billkmotolinkltd/services/config_service.dart';
import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:billkmotolinkltd/utils/utility_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

class ChargeBatteries extends StatefulWidget {
  const ChargeBatteries({super.key});

  @override
  State<ChargeBatteries> createState() => ChargeBatteriesState();
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


class ChargeBatteriesState extends State<ChargeBatteries> {
  bool scanning = false;

  List<String> scannedBatteries = [];
  List<String> scannedBatteryCodes = [];

  List<String> destinations = [];
  String? selectedDestination;

  static const int maxScans = 1;
  bool isCharging = false;

  bool? isClockedIn;
  String userName = "";
  String currentBike = "";
  String _timeString = "";
  late Timer _timer;
  bool? _isOnline;
  bool isLoading = true;
  bool freeAssignment = false;

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
  void initState() {
    super.initState();
    _loadFreeAssignment();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    initializerFunctions();
    checkIsOnline();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
    });
  }

  Future<void> _loadFreeAssignment() async {
    final value = await ConfigService.getFreeAssignment();

    setState(() {
      freeAssignment = value;
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
  Future<void> scanBattery() async {
    if (scannedBatteries.length >= maxScans) {
      ToastService.warning("You have reached the 1-battery limit");
      return;
    }

    try {
      setState(() => scanning = true);

      final qrCodeRaw = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );

      if (qrCodeRaw == null) {
        ToastService.warning("Scan cancelled");
        setState(() => scanning = false);
        return;
      }

      final qrCode = cleanExtract(qrCodeRaw);

      // Prevent duplicate scans
      if (scannedBatteryCodes.contains(qrCode)) {
        ToastService.warning("Battery already scanned");
        setState(() => scanning = false);
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('batteries')
          .where('qr_code', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ToastService.warning("Battery not found");
        setState(() => scanning = false);
        return;
      }

      final data = query.docs.first.data();
      final assignedRider = data['assignedRider']?.toString() ?? "None";
      final batteryName = data['batteryName'] ?? "Unknown Battery";
      final storeAssignedRider = data['storeAssignedRider'] ?? "None";
      
      if (assignedRider == userName) {
        setState(() {
          scannedBatteries.add(batteryName);
          scannedBatteryCodes.add(qrCode);
          scanning = false;
        });
      } else {
        ToastService.warning("To charge, you must first be assigned to this battery");
        setState(() => scanning = false);
      }
    } catch (e) {
      ToastService.error("Error: ${e.toString()}");
      setState(() => scanning = false);
    }
  }

  Future<void> chargeBatteries() async {
    if (scannedBatteries.isEmpty) {
      ToastService.warning("No batteries scanned to charge");
      return;
    }

    setState(() => isCharging = true);

    final now = DateTime.now();
    final selectedLoc = selectedDestination;
    final batch = FirebaseFirestore.instance.batch();

    try {
      /// 1. Update battery documents

      Future<void> updateBattery(String batteryName, {required bool onCharge}) async {
        final batteryQuery = await FirebaseFirestore.instance
            .collection('batteries')
            .where('batteryName', isEqualTo: batteryName)
            .limit(1)
            .get();

        if (batteryQuery.docs.isEmpty) return;

        final batteryRef = batteryQuery.docs.first.reference;

        // battery state
        batch.update(batteryRef, {
          'assignedRider': "None",
          'assignedBike': "None",
          'confirmedStatus': false,
          'storeAssignedRider': "None",
          'batteryLocation': "Charging at $selectedLoc",
          'offTime': now,
        });
      }

      // Update scanned batteries
      for (final battery in scannedBatteries) {
        await updateBattery(battery, onCharge: true);
      }

      /// 2. Update store documents for the scanned batteries only
      for (final batteryName in scannedBatteries) {
        // Find the exact store document where batteryName matches the scanned battery
        final storeQuery = await FirebaseFirestore.instance
            .collection("store")
            .where("name", isEqualTo: batteryName)
            .limit(1)
            .get();

        if (storeQuery.docs.isNotEmpty) {
          final ref = storeQuery.docs.first.reference;
          final message =
              "Dropped to charge by $userName on ${AppDateUtils.formatStandard(now)}. Awaiting confirmation.";

          batch.update(ref, {
            "assignedTo": "None",
            "assignedToUid": "None",
            "isAssigned": false,
            "confirmedStatus": false,
            "movement": "Incoming",
            "droppedBy": userName,
            "transactions": FieldValue.arrayUnion([
              {
                "message": message,
                "time": now,
              }
            ]),
          });
        }
      }



      /// 3. Commit all changes
      await batch.commit();

      ToastService.success("Batteries successfully sent to charge");

      setState(() => isCharging = false);
      resetScans();
    } catch (e) {
      ToastService.error("Error sending batteries to charge: ${e.toString()}");
      setState(() => isCharging = false);
    }
  }

  /// Reset scanned batteries AND selected bike
  void resetScans() {
    setState(() {
      scannedBatteries.clear();
      scannedBatteryCodes.clear();
      scanning = false;
    });
    ToastService.info("Scans reset");
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
              onPressed: isCharging
                  ? null
                  : () async {
                      Navigator.pop(context);
                      setState(() => isCharging = true);
                      await chargeBatteries(); // your async clock-in function
                      setState(() => isCharging = false);
                    },
              child: isCharging
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

  String resolveChargeText({
    required bool isOnline,
    required bool isClockedIn,
    required bool isLoading,
    required bool isBlocked,
  }) {
    if (_isOnline == false) return "You are offline";
    if (!isClockedIn) return "You are not clocked in";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Charge";
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
                  "Charge Batteries",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),
                if (scannedBatteries.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: scannedBatteries.map((battery) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          "Charge $battery",
                          style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.w900),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 12),
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
                
                const SizedBox(height: 28),

                // Location dropdown
                _buildDropdownField<String>(
                    value: selectedDestination,
                    label: "Select Location",
                    hint: "Choose destination",
                    icon: Icons.location_on,
                    items: destinations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc,
                        child: Text(loc),
                      );
                    }).toList(),
                    onChanged: (val) {
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
                            scannedBatteries.isNotEmpty &&
                            selectedDestination != null &&
                            !isCharging)
                        ? showSwapConfirmationDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isCharging) ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isCharging
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            resolveChargeText(
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
