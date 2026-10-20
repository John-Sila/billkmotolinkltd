import 'dart:ffi';

import 'package:daitom/pages/widgets/mpesa_payment_dialog.dart';
import 'package:daitom/pages/widgets/progress_steps_dialog.dart';
import 'package:daitom/services/mpesa_payment_service.dart';
import 'package:daitom/services/payment_config.dart';
import 'package:daitom/services/toast_service.dart';
import 'package:daitom/utils/utility_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:convert';

/// Where the rider was when they clocked out (used when there are no Daitom
/// batteries, so there is no drop-off location to pick).
class ClockoutLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String? address;
  final DateTime capturedAt;
  final bool isMocked;

  const ClockoutLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.address,
    required this.capturedAt,
    required this.isMocked,
  });

  /// What gets saved on the clock-out record in Firestore.
  Map<String, dynamic> toMap() => {
        'geoPoint': GeoPoint(latitude, longitude),
        'status': address == null ? 'not_found' : 'found',
        if (address != null) 'address': address else 'reason': 'address_unknown',
        'accuracyMeters': double.parse(accuracyMeters.toStringAsFixed(1)),
        'capturedAt': capturedAt,
        'isMocked': isMocked,
      };
}

/// What the "Fix" button on the location card should open.
enum LocationErrorAction { none, openLocationSettings, openAppSettings }

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

  final Geocoding _geocoding = Geocoding();

  Map<String, TextEditingController> expenseControllers = {};
  List<String> destinations = [];
  String? selectedDestination;
  double commissionPercentage = 0.0;
  double target = 0.0;
  bool isClockedIn = false;
  bool hasClockedOutToday = false;
  bool isClockingOut = false;
  bool? _isOnline;

  /// general/general_variables/battery_availability
  /// true  -> the business has batteries: ask for the drop-off location and
  ///          release the rider's batteries (full flow).
  /// false -> batteries are rented / not registered: no location, and nothing
  ///          is written to `batteries` (short flow).
  /// A missing field is treated as true so existing behaviour is unchanged.
  bool batteryAvailability = true;

  static bool _readBatteryAvailability(Map<String, dynamic>? data) =>
      data?['battery_availability'] != false;

  // ---- Where the rider is clocking out -------------------------------------
  // With no Daitom batteries there is no drop-off location to pick, so the
  // phone's GPS tells us where the rider clocked out instead.
  ClockoutLocation? _location;
  bool _locating = false;
  String? _locationError;
  LocationErrorAction _locationAction = LocationErrorAction.none;
  String? _locationFailure; // 'gps_off', 'permission_denied', ... (saved with the record)

  /// Reads the GPS position and turns it into a readable place name.
  ///
  /// Never throws and never blocks clock-out: when anything goes wrong the
  /// location is left empty and [_locationFailure] says why.
  ///
  /// [askPermission] false skips the system permission prompt (used at
  /// clock-out time, so a rider who already said no isn't asked again).
  Future<void> _captureLocation({
    bool askPermission = true,
    Duration gpsTimeout = const Duration(seconds: 20),
  }) async {
    if (_locating) {
      // A capture is already running: wait for it instead of starting a second.
      for (var i = 0; i < 100 && _locating && mounted; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      return;
    }

    if (mounted) {
      setState(() {
        _locating = true;
        _locationError = null;
        _locationAction = LocationErrorAction.none;
      });
    }

    ClockoutLocation? fix;
    String? error;
    String? failure;
    var action = LocationErrorAction.none;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error =
            "Your phone's location (GPS) is off. Turn it on to record where you clock out.";
        action = LocationErrorAction.openLocationSettings;
        failure = 'gps_off';
      } else {
        var permission = await Geolocator.checkPermission();
        if (askPermission && permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.deniedForever) {
          error =
              'Location permission is blocked. Allow it in the app settings to record where you clock out.';
          action = LocationErrorAction.openAppSettings;
          failure = 'permission_blocked';
        } else if (permission == LocationPermission.denied) {
          error = 'Location access was not allowed.';
          failure = 'permission_denied';
        } else {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: gpsTimeout,
            ),
          );
          final address =
              await _resolveAddress(position.latitude, position.longitude);
          fix = ClockoutLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            address: address,
            capturedAt: DateTime.now(),
            isMocked: position.isMocked,
          );
        }
      }
    } on TimeoutException {
      error = 'Could not get a GPS signal. Move to an open area and tap Refresh.';
      failure = 'no_signal';
    } catch (e) {
      debugPrint('Location error: $e');
      error = 'Could not read your location. Tap Refresh to try again.';
      failure = 'error';
    }

    if (!mounted) return;
    setState(() {
      _locating = false;
      _location = fix; // null when we could not get one
      _locationError = error;
      _locationAction = action;
      _locationFailure = failure;
    });
  }

  /// Coordinates -> "Thika Road, Kasarani, Nairobi" (as specific as the map
  /// data allows). Tries the phone's own geocoder first, then OpenStreetMap.
  /// Returns null when neither can name the place.
  Future<String?> _resolveAddress(double lat, double lng) async {
    int parts(String s) => s.isEmpty ? 0 : s.split(', ').length;
    var best = '';

    // 1) The phone's built-in geocoder.
    try {
      final marks = await _geocoding.placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 8));
      if (marks.isNotEmpty) {
        final p = marks.first;
        var text = _composeAddress([
          (p.thoroughfare ?? '').isNotEmpty ? p.thoroughfare : p.street,
          p.subLocality,
          p.locality,
        ]);
        if (text.isEmpty) {
          text = _composeAddress([p.subAdministrativeArea, p.administrativeArea]);
        }
        best = text;
      }
    } catch (e) {
      debugPrint('Geocoder failed: $e');
    }

    // 2) OpenStreetMap, only if the phone gave us nothing or just a city.
    //    (Some phones, e.g. without Google services, have no geocoder.)
    if (parts(best) < 2) {
      try {
        final res = await http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/reverse'
            '?format=jsonv2&zoom=18&addressdetails=1&accept-language=en'
            '&lat=$lat&lon=$lng',
          ),
          headers: {'User-Agent': 'DaitomApp/1.0 (clock-out location)'},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final a = (jsonDecode(res.body)['address'] as Map?) ?? {};
          final osm = _composeAddress([
            a['road'],
            a['neighbourhood'],
            a['suburb'] ?? a['city_district'],
            a['city'] ?? a['town'] ?? a['village'] ?? a['county'],
          ]);
          if (parts(osm) > parts(best)) best = osm;
        }
      } catch (e) {
        debugPrint('Reverse geocoding fallback failed: $e');
      }
    }

    return best.isEmpty ? null : best;
  }

  /// Joins address parts, dropping blanks, duplicates, "Unnamed Road" and
  /// Google plus codes (e.g. "7RMV+8X").
  String _composeAddress(Iterable<dynamic> parts) {
    final seen = <String>{};
    final out = <String>[];
    final plusCode = RegExp(r'^\w{4,8}\+\w{2,}');
    for (final raw in parts) {
      final p = raw?.toString().trim() ?? '';
      if (p.isEmpty) continue;
      if (plusCode.hasMatch(p)) continue;
      if (p.toLowerCase() == 'unnamed road') continue;
      if (seen.add(p.toLowerCase())) out.add(p);
    }
    return out.join(', ');
  }



  double deviation = 0.0;
  double netIncome = 0.0;
  double totalExpenses = 0.0;
  bool isLoading = true;
  String userName = "";

  /// The bike and shift this rider clocked in with (shown on the page and
  /// used to attribute the clock-out to the right shift).
  String? activeBike;
  String? activeShift; // 'day' | 'night' | null (unknown, e.g. clocked in before shifts existed)

  /// 'day' / 'night' or null for anything else (missing, "None", etc.).
  String? _validShift(dynamic value) {
    final s = value?.toString().trim().toLowerCase();
    return (s == 'day' || s == 'night') ? s : null;
  }

  /// Shift the rider clocked in on. Prefers `currentShift` (written at
  /// clock-in) and falls back to `assignedShift` for anyone who clocked in
  /// before this field existed.
  String? _shiftFromUserData(Map<String, dynamic> data) =>
      _validShift(data['currentShift']) ?? _validShift(data['assignedShift']);

  Widget _buildShiftInfoCard() {
    final isNight = activeShift == 'night';
    final Color color = activeShift == null
        ? Colors.blueGrey
        : (isNight ? Colors.indigo[400]! : Colors.amber[800]!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            activeShift == null
                ? Icons.two_wheeler_outlined
                : (isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded),
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeShift == null
                      ? 'Current shift'
                      : (isNight ? 'Night shift' : 'Day shift'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeBike ?? 'Bike not recorded',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shown instead of the drop-off dropdown when there are no Daitom batteries.
  /// Informational only: it never stops the rider from clocking out.
  Widget _buildLocationCard() {
    final loc = _location;
    final address = loc?.address;
    final found = address != null;
    final Color color =
        found ? Colors.teal : (_locating ? Colors.blueGrey : Colors.orange);

    final String hint = _locationError ??
        (loc != null
            ? "We have your position but couldn't work out the place name."
            : '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _locating
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        found ? Icons.location_on : Icons.location_off,
                        color: color,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (found)
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'You are clocking out from '),
                            TextSpan(
                              text: address,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 15),
                      )
                    else
                      Text(
                        _locating
                            ? 'Finding your location...'
                            : "Location couldn't be found",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _locating ? color : Colors.orange[800]!,
                        ),
                      ),
                    if (found && loc != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'GPS accuracy about ${loc.accuracyMeters.round()} m',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    if (!found && !_locating) ...[
                      const SizedBox(height: 4),
                      Text(
                        hint.isEmpty
                            ? 'You can still clock out.'
                            : '$hint You can still clock out.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!_locating)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  if (_locationAction == LocationErrorAction.openLocationSettings)
                    TextButton(
                      onPressed: () => Geolocator.openLocationSettings(),
                      child: const Text('Location settings'),
                    ),
                  if (_locationAction == LocationErrorAction.openAppSettings)
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text('App settings'),
                    ),
                  TextButton.icon(
                    onPressed: _captureLocation,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
    expenseControllers.forEach((key, ctrl) => ctrl.addListener(_updateState));
    otherExpenseController.addListener(_updateState);
  }

  void _updateState() => setState(() {});

  @override
  void dispose() {
    grossIncomeController.dispose();
    todaysIABController.dispose();
    prevIABController.dispose();
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

      final bikeRaw = userData['currentBike']?.toString().trim();
      activeBike = (bikeRaw == null || bikeRaw.isEmpty || bikeRaw == 'None') ? null : bikeRaw;
      activeShift = _shiftFromUserData(userData);

      // Fetch commission
      final generalDoc =
          await FirebaseFirestore.instance.collection('general').doc('general_variables').get();
      commissionPercentage =
          ((generalDoc.data()?['commissionPercentage'] ?? 0) as num).toDouble() / 100.0;

      // Are there Daitom batteries? Decides whether we ask for a location
      // and whether batteries are touched at clock-out.
      batteryAvailability = _readBatteryAvailability(generalDoc.data());
      if (!batteryAvailability) {
        selectedDestination = null;
        // Fire and forget: the location card shows the progress.
        unawaited(_captureLocation());
      }

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
        prevIABController.text.isEmpty) {
      return false;
    }

    // With batteries the rider picks the drop-off location. Without batteries
    // there is nothing to pick. (The GPS location is recorded when we have it,
    // but it is never required.)
    if (batteryAvailability && selectedDestination == null) {
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
                activeShift == null
                    ? 'Are you sure you want to end this shift?'
                    : 'Are you sure you want to end this ${activeShift == 'night' ? 'night' : 'day'} shift?',
                style: localTheme.textTheme.bodyMedium?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                batteryAvailability
                    ? 'This will finalize your batteries and shift data.'
                    : 'This will finalize your shift data.',
                style: localTheme.textTheme.bodySmall?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!batteryAvailability && !_locating) ...[
                const SizedBox(height: 12),
                Text(
                  _location?.address != null
                      ? 'You are clocking out from ${_location!.address}.'
                      : "Location couldn't be found.",
                  style: localTheme.textTheme.bodyMedium?.copyWith(
                    color: _location?.address != null
                        ? localTheme.colorScheme.primary
                        : localTheme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (kMpesaPaymentEnabled && netIncome.round() >= 1) ...[
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
              onPressed: isClockingOut
                  ? null
                  : () async {
                      // Let clockOut manage state mutations safely
                      await clockOut(dialogContext);
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

  Future<void> clockOut(BuildContext dialogContext) async {
    // 1. First UI Guard Check
    if (!canClockOut) {
      Fluttertoast.showToast(msg: "Complete all required fields");
      return;
    }

    if (isClockingOut) return;

    // 2. Safe State Lock Setup
    setState(() {
      isClockingOut = true;
    });

    // The "what's happening now" dialog shown after the payment succeeds.
    ProgressStepsController? progress;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();

      final fs = FirebaseFirestore.instance;
      final userRef = fs.collection('users').doc(uid);
      final batteriesRef = fs.collection('batteries');
      final weekLabel = getWeekLabel(now);
      final deviationsRef = fs.collection('deviations').doc(weekLabel);

      // Fetch user details for validation checks
      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        Fluttertoast.showToast(msg: "User not found");
        return; 
      }

      // Read battery_availability fresh. It decides how we write:
      //   true  -> full flow (location + release batteries)
      //   false -> short flow (no battery writes at all)
      final generalSnap = await fs.collection('general').doc('general_variables').get();
      final useBatteries = _readBatteryAvailability(generalSnap.data());
      if (mounted && useBatteries != batteryAvailability) {
        setState(() => batteryAvailability = useBatteries);
      }

      // The flag flipped to true after the form was filled: a location is
      // needed now. Stop before any payment is taken.
      if (useBatteries && selectedDestination == null) {
        Fluttertoast.showToast(msg: "Select a drop-off location");
        return;
      }
      
      // No Daitom batteries: record where the rider is, using GPS. This NEVER
      // blocks clock-out. Use the fix the screen already has if it is recent,
      // otherwise try for a fresh one (briefly, and without asking for
      // permission again). If we still have nothing, the record simply says
      // the location couldn't be found. An old fix is never saved as if it
      // were current.
      Map<String, dynamic>? locationReport;
      if (!useBatteries) {
        bool isFresh(ClockoutLocation? l) =>
            l != null &&
            DateTime.now().difference(l.capturedAt) <= const Duration(minutes: 2);

        if (!isFresh(_location)) {
          await _captureLocation(
            askPermission: false,
            gpsTimeout: const Duration(seconds: 8),
          );
        }

        final fix = isFresh(_location) ? _location : null;
        locationReport = fix?.toMap() ??
            {
              'status': 'not_found',
              'reason': _locationFailure ?? 'unavailable',
            };
      }

      final userName = userSnap.get('userName');

      // The shift this rider is actually closing out (from the fresh doc, not
      // the possibly-stale page state). Never blocks clock-out if it's unknown —
      // money settlement matters more than the label.
      final shift = _shiftFromUserData(userSnap.data() ?? {});

      final pendingAmountOld = userSnap.get('pendingAmount') ?? 0.0;
      final prevInApp = double.parse(prevIABController.text);
      final todaysIAB = double.parse(todaysIABController.text);
      final selectedLoc = selectedDestination;

      // 4. ALL VALIDATIONS PASSED: Dismiss the dialog safely now
      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }

      // Expense compilation
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

      // Net income calculation
      final gross = double.parse(double.parse(grossIncomeController.text).toStringAsFixed(2));
      final commission = commissionPercentage; 
      final netIncome = double.parse((gross * (1 - commission)
          - (todaysIAB - prevInApp)
          - expenseData.values.whereType<num>().fold(0.0, (s, v) => s + v)).toStringAsFixed(2));

      // ---- M-Pesa payment ---------------------------------------------------
      // The rider pays today's net income through an M-Pesa PIN prompt. Nothing
      // below (battery release, clock-out record, pending amount) runs unless the
      // payment succeeds, and what gets recorded is what Safaricom confirmed.
      MpesaPaymentResult? payment;
      final amountDue = netIncome.round();
      if (kMpesaPaymentEnabled && amountDue >= 1) {
        if (!mounted) return;
        payment = await showMpesaPaymentDialog(
          context,
          amount: amountDue,
          initialPhone: (userSnap.data()?['phoneNumber'] ?? '').toString(),
        );
        if (payment == null) {
          Fluttertoast.showToast(msg: "Clock-out cancelled. The payment was not completed.");
          return;
        }
      }
      final paidAmount = payment?.amount ?? 0;

      // ---- Progress dialog --------------------------------------------------
      // Opens the moment the payment is confirmed and stays until every write
      // is finished, so the rider knows when it is really done.
      progress = ProgressStepsController([
        if (payment != null) 'Payment confirmed',
        if (useBatteries) 'Releasing batteries',
        'Saving clock-out record',
        'Updating weekly deviations',
        'Updating monthly & yearly stats',
      ], title: 'Finishing clock-out');
      if (!mounted) return;
      progress.show(context);
      progress.begin();
      if (payment != null) await progress.next(); // Payment confirmed

      final dateKey = todayHumanKey();                  
      final weekDay = weekdayName();                    

      // Release Batteries (bikes stay assigned to the rider — that's managed
      // separately via the Assignments page, not reset on every clock-out.
      // Each bike has a day slot and a night slot, so leaving the slot alone
      // here also guarantees we never disturb the OTHER shift's rider.
      // This clock-out is recorded against `shift` below.)
      //
      // Only when the business has batteries. With battery_availability ==
      // false there is nothing to release, so `batteries` is not touched.
      if (useBatteries) {
        final batteryQuery = await batteriesRef.where('assignedRider', isEqualTo: userName).get();
        for (var b in batteryQuery.docs) {
          await b.reference.update({
            'assignedRider': "None",
            'assignedBike': "None",
            'confirmedStatus': false,
            'batteryLocation': selectedLoc,
            'offTime': now,
          });
        }
        await progress.next(); // Releasing batteries
      }

      // Process shift timelines
      int timeElapsed = (now.millisecondsSinceEpoch - userSnap.get('clockInTime').millisecondsSinceEpoch) as int;
      final clockoutData = {
        "grossIncome": gross,
        "todaysInAppBalance": double.parse(todaysIAB.toStringAsFixed(2)),
        "previousInAppBalance": double.parse((prevInApp).toStringAsFixed(2)),
        "inAppDifference": todaysIAB - prevInApp,
        "expenses": expenseData,
        "netIncome": netIncome,
        "posted_at": now,
        "timeElapsed": formatTimeElapsed(timeElapsed),
        if (shift != null) "shift": shift,
        if (locationReport != null) "clockoutLocation": locationReport,
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

      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
        
      await userRef.update({
        "clockouts.$dateKey": clockoutData,
        "currentInAppBalance": todaysIAB,
        "isClockedIn": false,
        "netClockedLastly": netIncome,
        "pendingAmount": double.parse((pendingAmountOld + netIncome - paidAmount).toStringAsFixed(2)),
        "lastClockDate": now,
        "currentBike": "None",
        "currentShift": "None",
        'notifications.$notificationId': {
          'isRead': false,
          'message': 'You\'re clocked out for today.',
          'time': now,
        },
        "numberOfNotifications": FieldValue.increment(1),
      });

      if (payment != null) {
        try {
          await MpesaPaymentService().consume(payment.checkoutId);
        } catch (e) {
          debugPrint('Could not mark payment as used: $e');
        }
      }
      await progress.next(); // Saving clock-out record

      final deviationData = {
        "grossIncome": gross,
        "netIncome": netIncome,
        "grossDeviation": gross - target,
        "netGrossDifference": gross - netIncome,
      };

      await deviationsRef.set({
        userName: {weekDay: deviationData}
      }, SetOptions(merge: true));
      await progress.next(); // Updating weekly deviations

      // Handle monthly and yearly stats over transactions safely
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(userRef);
        final now = DateTime.now();
        final monthName = DateFormat("MMMM").format(now);
        final nextMonth = DateFormat("MMMM").format(DateTime(now.year, now.month + 1, now.day));

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

      setState(() {
        hasClockedOutToday = true;
      });

      await _updateYearlyAndMonthlyStats(
        userName: '$userName',
        gross: gross,
        netIncome: netIncome,
        expenseData: expenseData,
      );
      await progress.next(); // Updating monthly & yearly stats

      await progress.finish(); // all green, then closes
      ToastService.success("Clock-out successful! See you next time.");
    } catch (e) {
      if (!mounted) return;

      // Turn the running step red and close the progress dialog first.
      await progress?.abort();
      
      // Explicitly dismiss confirmation dialog on structural database breakdown error before opening next window
      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Clock-Out Failed"),
          content: SingleChildScrollView(
            child: SelectableText(
              e.toString(),
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
    } finally {
      // Safety net: never leave the progress dialog stuck on screen.
      progress?.close();

      // 5. Unlocks UI processing state unconditionally
      if (mounted) {
        setState(() {
          isClockingOut = false;
        });
      }
    }
  }

  String formatTimeElapsed(int timeElapsedMs) {
    int hours = timeElapsedMs ~/ 3600000; // 3600 * 1000 ms per hour
    int minutes = (timeElapsedMs % 3600000) ~/ 60000; // 60 * 1000 ms per minute
    
    return '${hours.toString().padLeft(1)} hrs ${minutes.toString().padLeft(2)} mins';
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

                if (isClockedIn && (activeBike != null || activeShift != null))
                  _buildShiftInfoCard(),

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



                // With batteries: the rider picks the drop-off location.
                // Without batteries: no selector, the GPS location card instead.
                if (batteryAvailability) ...[
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
                ] else ...[
                  _buildLocationCard(),
                  const SizedBox(height: 20),
                ],


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
                    onPressed: (!hasClockedOutToday && canClockOut && !isClockingOut && isClockedIn && (_isOnline == true))
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