import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:billkmotolinkltd/services/notifier.dart';
import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  DocumentSnapshot<Map<String, dynamic>>? _userDoc;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _events = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _polls = [];
  bool _loading = true;
  String? _error;
  final NotificationService _notificationService = NotificationService();
  final _auth = FirebaseAuth.instance;
  String? _appVersion;
  String? differentialRank;
  double _commissionPercentage = 0.0;
  bool _isEditingCommission = false;
  final TextEditingController _commissionController = TextEditingController();

  bool _showMemoOverlay = false;
  Map<String, dynamic>? _currentMemo;
  Timer? _expiredEventsTimer;



  @override
  void initState() {
    super.initState();
    _loadAll();

    // Prompt, automatic cleanup of expired events: runs immediately and
    // then on a recurring timer so events disappear as soon as they
    // expire, without needing a manual refresh or full dashboard reload.
    _cleanupExpiredEvents();
    _expiredEventsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanupExpiredEvents(),
    );

    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        // User logged in - start notification listeners
        _notificationService.onUserLoggedIn();
        uploadDeviceDataToFirestore(user.uid);
      } else {
        // User logged out - stop notification listeners
        _notificationService.onUserLoggedOut();
      }
    });

  }

  Future<void> _updateCommission() async {
    if (!_isEditingCommission) return;

    final newCommission = double.tryParse(_commissionController.text) ?? 0.0;
    
    try {
      await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .update({'commissionPercentage': newCommission});
      
      setState(() {
        _commissionPercentage = newCommission;
        _isEditingCommission = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating commission: $e')),
        );
      }
    }
  }

  /// Lightweight, read-mostly cleanup that only touches the `events`
  /// collection: deletes anything whose `event_time` has already
  /// passed and refreshes the visible list. Safe to call frequently
  /// (e.g. from a periodic timer) since it does not touch users,
  /// polls, memos, or any other collection, and never writes new
  /// documents — it only deletes documents that are already expired.
  Future<void> _cleanupExpiredEvents() async {
    if (!mounted) return;
    try {
      final now = DateTime.now();
      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('event_time', descending: true)
          .get();

      final validEvents = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in eventsSnap.docs) {
        final data = doc.data();
        final ts = data['event_time'] as Timestamp?;
        if (ts == null) continue;

        if (ts.toDate().isBefore(now)) {
          await doc.reference.delete().catchError((e) {});
        } else {
          validEvents.add(doc);
        }
      }

      if (mounted) {
        setState(() {
          _events = validEvents;
        });
      }
    } catch (e) {
      // Silent: this is a background convenience cleanup, the full
      // _loadAll() call already surfaces errors to the user.
    }
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final uid = user.uid;

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userSnap.exists || !mounted) {
        setState(() => _loading = false);
        return;
      }

      final now = DateTime.now();

      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('event_time', descending: true)
          .get();

      final validEvents = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in eventsSnap.docs) {
        final data = doc.data();
        final ts = data['event_time'] as Timestamp?;

        if (ts == null) continue;

        if (ts.toDate().isBefore(now)) {
          // Expired: remove promptly instead of lingering for a week.
          await doc.reference.delete().catchError((e) {});
        } else {
          validEvents.add(doc);
        }
      }

      final memoRef = FirebaseFirestore.instance.collection('memo').doc('latest');
      final memoSnap = await memoRef.get();
      Map<String, dynamic>? memoData;

      if (memoSnap.exists) {
        final data = memoSnap.data() ?? {};
        final expiresAt = data['expiresAt'] as Timestamp?;

        if (expiresAt != null && expiresAt.toDate().isBefore(now)) {
          await memoRef.delete().catchError((e) {});
        } else {
          memoData = data;
        }
      }

      final userData = userSnap.data() ?? {};
      final userRank = userData['userRank']?.toString() ?? '';

      List<QueryDocumentSnapshot<Map<String, dynamic>>> polls = [];
      if (userRank.isNotEmpty) {
        try {
          final pollsSnap = await FirebaseFirestore.instance
              .collection('polls')
              .orderBy('deadline')
              .get();
          polls = pollsSnap.docs;
        } catch (e) {
          // Ignore poll errors
        }
      }

      final generalSnap = await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .get();

      if (generalSnap.exists) {
        final generalData = generalSnap.data() ?? {};
        final commission = (generalData['commissionPercentage'] ?? 0.0) as num;
        _commissionPercentage = commission.toDouble();
        _commissionController.text = _commissionPercentage.toStringAsFixed(1);
      }

      final version = await getCurrentAppVersion();
      _appVersion = version;

      if (mounted) {
        setState(() {
          _userDoc = userSnap;
          _events = validEvents;
          _polls = polls;
          differentialRank = userRank;
          _loading = false;
        });

        if (memoData != null) {
          final readBy = (memoData['readBy'] as List? ?? <String>[]).cast<String>();
          if (!readBy.contains(uid)) {
            setState(() {
              _currentMemo = memoData;
              _showMemoOverlay = true;
            });
          }
        }
      }

      await _notificationService.checkNotificationsManually();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load dashboard: $e';
        });
      }
    }
  }
    
  Future<void> uploadDeviceDataToFirestore(String uid) async {
    try {
      // Check authentication first
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || uid != user.uid) {
        throw Exception('User not authenticated or UID mismatch');
      }

      // Initialize device info
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      Battery battery = Battery();
      Connectivity connectivity = Connectivity();

      Map<String, dynamic> deviceData = {
        'lastUploadTimestamp': FieldValue.serverTimestamp(),
        'uid': uid,
        'userEmail': user.email,
      };

      // Device hardware/software info - CORRECTED PROPERTIES
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceData.addAll({
          'platform': 'android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
          'deviceId': androidInfo.id,
          'product': androidInfo.product,
          'hardware': androidInfo.hardware,
          'display': androidInfo.display,
          'host': androidInfo.host,
          'osVersion': androidInfo.version.release,
          'apiLevel': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
          'supportedAbis': androidInfo.supportedAbis,
        });
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceData.addAll({
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'localizedModel': iosInfo.localizedModel,
          'utsnameMachine': iosInfo.utsname.machine,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        });
      }

      // Battery information
      try {
        deviceData['batteryLevel'] = await battery.batteryLevel;
        BatteryState state = await battery.batteryState;
        // Convert enum to readable string
        switch (state) {
          case BatteryState.full:
            deviceData['batteryState'] = 'Full';
            break;
          case BatteryState.charging:
            deviceData['batteryState'] = 'Charging';
            break;
          case BatteryState.discharging:
            deviceData['batteryState'] = 'Discharging';
            break;
          case BatteryState.unknown:
            deviceData['batteryState'] = 'Unknown';
            break;
          case BatteryState.connectedNotCharging:
            deviceData['batteryState'] = 'Connected (Not Charging)';
            break;
        }
      } catch (e) {
        deviceData['batteryLevel'] = null;
        deviceData['batteryState'] = 'Error';
        deviceData['batteryError'] = e.toString();
      }


      // Network connectivity - FIXED for new connectivity_plus API
      try {
        List<ConnectivityResult> results = await connectivity.checkConnectivity();
        
        // Take first result or prioritize (WiFi > Mobile > Other)
        ConnectivityResult primaryResult = ConnectivityResult.none;
        if (results.contains(ConnectivityResult.wifi)) {
          primaryResult = ConnectivityResult.wifi;
        } else if (results.contains(ConnectivityResult.mobile)) {
          primaryResult = ConnectivityResult.mobile;
        } else if (results.isNotEmpty) {
          primaryResult = results.first;
        }
        
        // Convert to readable string
        switch (primaryResult) {
          case ConnectivityResult.wifi:
            deviceData['networkType'] = 'WiFi';
            break;
          case ConnectivityResult.mobile:
            deviceData['networkType'] = 'Mobile Data';
            break;
          case ConnectivityResult.ethernet:
            deviceData['networkType'] = 'Ethernet';
            break;
          case ConnectivityResult.vpn:
            deviceData['networkType'] = 'VPN';
            break;
          case ConnectivityResult.bluetooth:
            deviceData['networkType'] = 'Bluetooth';
            break;
          case ConnectivityResult.other:
            deviceData['networkType'] = 'Other';
            break;
          case ConnectivityResult.none:
            deviceData['networkType'] = 'Offline';
            break;
        }
      } catch (e) {
        deviceData['networkType'] = 'Unknown';
      }

      // Screen information (Flutter 3+ compatible)
      final window = WidgetsBinding.instance.window;
      final mediaQuery = MediaQueryData.fromView(window);
      deviceData.addAll({
        'screenWidth': mediaQuery.size.width,
        'screenHeight': mediaQuery.size.height,
        'pixelRatio': mediaQuery.devicePixelRatio,
        'screenPadding': {
          'top': mediaQuery.padding.top,
          'bottom': mediaQuery.padding.bottom,
          'left': mediaQuery.padding.left,
          'right': mediaQuery.padding.right,
        },
      });

      // Update as a map in users/{uid}/device_info document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            'device_info': deviceData,
            'appVersion': _appVersion,
          }, SetOptions(merge: true));

    } catch (e) {
      rethrow;
    }
  }

  Future<String> getCurrentAppVersion() async {
    WidgetsFlutterBinding.ensureInitialized(); // Required before runApp()
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version; // e.g., "1.0.1"
  }

  Future<void> _markAsRead(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('memo')
          .doc('latest')
          .update({
        'readBy': FieldValue.arrayUnion([uid]),
      });
      
      setState(() {
        _showMemoOverlay = false;
        _currentMemo = null;
      });
      
      ToastService.success("Memo marked as read!");
    } catch (e) {
      ToastService.error("Failed to mark memo as read: $e");
    }
  }

  Widget _buildMemoOverlay(ThemeData theme, Map<String, dynamic> memoData) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final department = (memoData['department'] ?? '').toString();
    final to = (memoData['to'] ?? 'All Staff').toString();
    final from = (memoData['from'] ?? 'Unknown').toString();
    final title = (memoData['title'] ?? '').toString();
    final body = (memoData['body'] ?? '').toString();

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() {
                _showMemoOverlay = false;
                _currentMemo = null;
              }),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700, maxHeight: 760),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 40,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.campaign_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Memo',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          to,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() {
                                      _showMemoOverlay = false;
                                      _currentMemo = null;
                                    }),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (department.isNotEmpty) ...[
                                      _pill(theme, department, theme.colorScheme.primary),
                                      const SizedBox(height: 16),
                                    ],
                                    Text(
                                      title,
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        body,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          height: 1.7,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_2_rounded,
                                          size: 18,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            from,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: FilledButton.icon(
                                        onPressed: () => _markAsRead(uid),
                                        icon: const Icon(Icons.mark_chat_read_rounded),
                                        label: const Text('Mark as Read'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 3,
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.withValues(alpha: 0.1), Colors.red.withValues(alpha: 0.05)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red[600],
                    size: 64,
                    shadows: const [
                      Shadow(color: Colors.red, offset: Offset(0, 4), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    shadowColor: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Safe user data access
    final userData = _userDoc?.data() ?? {};
    final userName = userData['userName']?.toString() ?? 'User';
    final userRank = userData['userRank']?.toString() ?? 'User';

    final now = DateTime.now();
    final hour = now.hour;
    String greeting = _getGreeting(hour);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAll,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            child: CustomScrollView(
            slivers: [
              // ✅ PREMIUM SLIVERAPPBAR
              SliverAppBar(
                expandedHeight: 280, // Increased for more beauty
                floating: true,
                snap: true,
                pinned: true,
                collapsedHeight: kToolbarHeight + 8,
                backgroundColor: Colors.transparent,
                foregroundColor: theme.colorScheme.onInverseSurface,
                elevation: 0,
                shadowColor: Colors.transparent,

                // TITLE
                title: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.waving_hand_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // GORGEOUS FLEXIBLE SPACE
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.95),
                          isDark 
                              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.85)
                              : theme.colorScheme.secondary.withValues(alpha: 0.9),
                        ],
                      ),
                      // BOTTOM ROUNDED CORNERS ONLY
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ANIMATED AVATAR
                          Hero(
                            tag: 'user_avatar',
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.1),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black45),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // TIME-BASED GREETING
                          ShaderMask(
                            shaderCallback: (bounds) => RadialGradient(
                              colors: [Colors.white, Colors.white.withValues(alpha: 0.8)],
                            ).createShader(bounds),
                            child: Text(
                              greeting,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(offset: Offset(0, 4), blurRadius: 16, color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Username with gradient
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [Colors.white, theme.colorScheme.primary.withValues(alpha: 0.9)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ).createShader(bounds),
                                child: Text(
                                  userName,
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.1,
                                    shadows: const [
                                      Shadow(offset: Offset(0, 4), blurRadius: 20, color: Colors.black54),
                                      Shadow(offset: Offset(2, 2), blurRadius: 12, color: Colors.black26),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 6),

                              // Badge
                              Transform.translate(
                                offset: const Offset(0, -3), // ← move up (tweak -2 to -5 to taste)
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    gradient: _toBool(userData['isVerified'])
                                        ? LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade800])
                                        : LinearGradient(colors: [Colors.grey.shade500, Colors.grey.shade700]),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _toBool(userData['isVerified']) 
                                            ? Colors.blue.withValues(alpha: 0.4)
                                            : Colors.grey.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _toBool(userData['isVerified'])
                                        ? Icons.verified_rounded
                                        : Icons.warning_rounded,
                                    color: Colors.white,
                                    size: 16,
                                    shadows: const [
                                      Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26),
                                    ],
                                  ),
                                ),
                              ),
                                ],
                              ),
                          
                          // RANK BADGE
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            margin: const EdgeInsets.only(top: 15),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.white.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              userRank.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // CONTENT
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Events Section
                      if (_events.isNotEmpty) ...[
                        _buildEventsSection(theme),
                        const SizedBox(height: 28),
                      ],

                      // Polls Section
                      if (_polls.isNotEmpty) ...[
                        _buildPollsSection(theme),
                        const SizedBox(height: 28),
                      ],
                      // Stats Cards
                      _buildStatsCards(theme, userData),
                      
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),

          if (_showMemoOverlay && _currentMemo != null)
            Positioned.fill(
              child: _buildMemoOverlay(theme, _currentMemo!),
            ),
        ],
      ),
    );



  }

  // HELPER
  String _getGreeting(int hour) {
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  Widget _buildEventsSection(ThemeData theme) {
    return Card(
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.event, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Upcoming Events (${_events.length})',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Events List - Now clickable
            ..._events.map((doc) {
              final data = doc.data();
              final ts = data['event_time'] as Timestamp?;
              if (ts == null) return const SizedBox.shrink();
              
              final dt = ts.toDate();
              final isFuture = dt.isAfter(DateTime.now());
              
              return GestureDetector(
                onTap: () => _showEventDetails(context, doc, theme),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isFuture 
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFuture 
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: isFuture ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isFuture ? Icons.schedule : Icons.history,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Event Preview Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title']?.toString() ?? 'No Title',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ) ?? const TextStyle(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['description']?.toString() ?? 'No description',
                                style: theme.textTheme.bodyMedium ?? const TextStyle(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Date + Arrow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('dd MMM').format(dt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ) ?? const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            DateFormat('HH:mm').format(dt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ) ?? const TextStyle(),
                          ),
                          const SizedBox(height: 4),
                          Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Add this method to your _DashboardState class
  void _showEventDetails(BuildContext context, QueryDocumentSnapshot doc, ThemeData theme) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['event_time'] as Timestamp?;
    final dt = ts?.toDate() ?? DateTime.now();
    final isFuture = dt.isAfter(DateTime.now());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFuture ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isFuture ? Icons.schedule : Icons.history,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data['title']?.toString() ?? 'Event Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date/Time
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(dt),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          DateFormat('HH:mm').format(dt),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Full Description
              Text(
                'Description',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data['description']?.toString() ?? 'No description available',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPollsSection(ThemeData theme) {
    return Card(
      elevation: 8,
      shadowColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.poll, color: theme.colorScheme.secondary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Polls (${_polls.length})',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._polls.map((doc) {
              final data = doc.data();
              final deadlineTs = data['deadline'] as Timestamp?;
              if (deadlineTs == null) return const SizedBox.shrink();
              
              final deadline = deadlineTs.toDate();
              final expired = deadline.isBefore(DateTime.now());
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: expired 
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: expired 
                      ? theme.colorScheme.error
                      : theme.colorScheme.secondary,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      expired ? Icons.schedule_send : Icons.how_to_vote,
                      color: expired ? theme.colorScheme.error : theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title']?.toString() ?? 'No Title',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ) ?? const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Deadline: ${DateFormat('dd MMM yyyy').format(deadline)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: expired 
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSecondaryContainer,
                            ) ?? const TextStyle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatHours(Map<String, dynamic> user) {
    final isClockedIn = _toBool(user['isClockedIn']);
    if (!isClockedIn) return 'Unavailable';
    
    final clockInTime = user['clockInTime'] as Timestamp?;
    if (clockInTime == null) return 'Unavailable';
    
    final now = DateTime.now();
    final clockInDate = clockInTime.toDate();
    final hours = now.difference(clockInDate).inHours;
    final minutes = now.difference(clockInDate).inMinutes.remainder(60);
    
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  Widget _buildStatsCards(ThemeData theme, Map<String, dynamic> user) {
    final isDark = theme.brightness == Brightness.dark;
    final String rank = user['userRank']?.toString() ?? '';

    // 2. Admin Check
    if (rank == 'CEO' || rank == 'Systems, IT' || rank == 'Manager') {
      return _buildAdminDashboard(theme);
    }

    final stats = [
      {'label': 'Daily Target', 'value': _formatNumber(user['dailyTarget']), 'color': Colors.blue},
      {'label': 'Sunday Target', 'value': _formatNumber(user['sundayTarget']), 'color': Colors.orange},
      {'label': 'Pending Amount', 'value': _formatNumber(user['pendingAmount']), 'color': Colors.red},
      {'label': 'In-App Balance', 'value': _formatNumber(user['currentInAppBalance']), 'color': Colors.green},
      {'label': 'Bike', 'value': (user['currentBike'] ?? 'N/A').toString(), 'color': Colors.purple},
      {'label': 'Hours', 'value': _formatHours(user), 'color': Colors.teal},
    ];

    return Column(
      children: [
        // ✅ BEAUTIFIED HEADER
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.1),
                theme.colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(Icons.analytics_outlined, 
                  color: Colors.white, 
                  size: 28,
                  shadows: const [
                    Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Stats',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Performance overview',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: (theme.colorScheme.onPrimaryContainer).withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ✅ PREMIUM STATS GRID
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            mainAxisExtent: 124,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            final color = stat['color'] as Color?;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (color ?? theme.colorScheme.primary).withValues(alpha: 0.15),
                    (color ?? theme.colorScheme.primary).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: (color ?? theme.colorScheme.primary).withValues(alpha: isDark ? 0.4 : 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.2),
                    blurRadius: isDark ? 16 : 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {}, // Add tap action if needed
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: color ?? theme.colorScheme.primary,
                          size: 28,
                          shadows: [
                            Shadow(
                              color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          stat['value'] as String,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stat['label'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // ✅ ENHANCED STATUS ROW
        _buildStatusRow(theme, user, isDark),
      ],
    );
  }

  Widget _buildAdminDashboard(ThemeData theme) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPerformanceSection(data['monthly_incomes'] ?? {}, theme, true),
              const SizedBox(height: 20),
              _buildPerformanceSection(data['annual_incomes'] ?? {}, theme, false),
              const SizedBox(height: 20),
              _buildSystemOverview(data, theme),
            ],
          ),
        );
      },
    );
  }

  DateTime _getLatestDate(Map<String, dynamic> riderGroup) {
    DateTime latest = DateTime(2000);
    riderGroup.forEach((_, data) {
      final stamp = data['dateAppended'];
      if (stamp is Timestamp) {
        final date = stamp.toDate();
        if (date.isAfter(latest)) latest = date;
      }
    });
    return latest;
  }

  List<MapEntry<String, Map<String, dynamic>>> _sortIncomeData(Map<String, dynamic> source) {
    final sortedKeys = source.keys.toList()
      ..sort((a, b) {
        final dataA = source[a] as Map<String, dynamic>;
        final dataB = source[b] as Map<String, dynamic>;
        final dateA = _getLatestDate(dataA);
        final dateB = _getLatestDate(dataB);
        return dateB.compareTo(dateA);
      });
    return sortedKeys.map((key) => MapEntry(key, source[key] as Map<String, dynamic>)).toList();
  }

  Widget _buildPerformanceSection(
    Map<String, dynamic> source,
    ThemeData theme,
    bool isMonthly,
  ) {
    if (source.isEmpty) {
      return _buildEmptyState(
        isMonthly ? 'No monthly data' : 'No annual data',
        Icons.analytics_outlined,
      );
    }

    final sortedEntries = _sortIncomeData(source);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompactSectionHeader(
              title: isMonthly ? 'Monthly Income' : 'Annual Income',
              subtitle: isMonthly ? 'Chronological monthly performance' : 'Yearly performance',
              icon: isMonthly ? Icons.calendar_month : Icons.assessment,
              accentColor: isMonthly ? Colors.blue : Colors.deepPurple,
              theme: theme,
            ),
            const SizedBox(height: 12),
            ...sortedEntries.map((entry) => _buildIncomeExpansionTile(entry, theme)),
          ],
        ),
      ),
    );
  }

  Totals _calculateRiderTotals(Map<String, dynamic> ridersMap) {
    double totalGross = 0, totalNet = 0, totalExp = 0;
    ridersMap.forEach((_, riderData) {
      totalGross += (riderData['gross'] ?? 0).toDouble();
      totalNet += (riderData['net'] ?? 0).toDouble();
      totalExp += (riderData['expenses'] ?? 0).toDouble();
    });
    return Totals(totalGross, totalNet, totalExp);
  }

  Widget _buildIncomeExpansionTile(MapEntry<String, Map<String, dynamic>> entry, ThemeData theme) {
    final ridersMap = entry.value;
    final totals = _calculateRiderTotals(ridersMap);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key.replaceAll('_', ' ').trim(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              _buildCompactChip(totals.totalGross, Colors.green),
              const SizedBox(width: 6),
              _buildCompactChip(totals.totalNet, Colors.blue),
            ],
          ),
          children: [
            ...ridersMap.entries.map((riderEntry) => _buildCompactRiderTile(riderEntry, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRiderTile(MapEntry<String, dynamic> riderEntry, ThemeData theme) {
    final riderData = riderEntry.value as Map<String, dynamic>;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        minLeadingWidth: 40,
        leading: CircleAvatar(
          radius: 16, // Smaller avatar
          backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
          child: Text(
            riderEntry.key.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          riderEntry.key,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "Exp: ${_formatNumber(riderData['expenses'])}",
          style: theme.textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "G: ${_formatNumber(riderData['gross'])}",
              style: TextStyle(
                color: Colors.green[600],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "N: ${_formatNumber(riderData['net'])}",
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemOverview(Map<String, dynamic> data, ThemeData theme) {
    final bikes = data['bikes'] as Map<String, dynamic>? ?? {};
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompactSectionHeader(
              title: 'System Overview',
              subtitle: 'General app stats and controls',
              icon: Icons.settings_suggest,
              accentColor: Colors.teal,
              theme: theme,
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 700 ? 2 : 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildCompactMetricCard(
                  'Bikes',
                  bikes.length.toString(),
                  Icons.pedal_bike,
                  Colors.indigo,
                ),
                _buildCompactCommissionCard(theme),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            _buildCompactSectionHeader(
              title: 'Bike Status',
              subtitle: 'Current condition and availability',
              icon: Icons.directions_bike,
              accentColor: Colors.green,
              theme: theme,
            ),
            const SizedBox(height: 12),

            ...bikes.entries.map((bikeEntry) => _buildCompactBikeTile(bikeEntry, theme)),
          ]
        ),
      ),
    );
  }

  Widget _buildCompactCommissionCard(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isEditingCommission ? theme.primaryColor : theme.dividerColor,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isEditingCommission ? null : () => setState(() => _isEditingCommission = true),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.percent, color: Colors.green[600], size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Commission',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_isEditingCommission)
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            controller: _commissionController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.0%',
                              hintStyle: const TextStyle(fontSize: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.left,
                            onSubmitted: (_) => _updateCommission(),
                          ),
                        )
                      else
                        Text(
                          '${_commissionPercentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isEditingCommission) ...[
                  IconButton(
                    onPressed: _updateCommission,
                    icon: const Icon(Icons.check, color: Colors.green, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditingCommission = false;
                        _commissionController.text = _commissionPercentage.toStringAsFixed(1);
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ] else
                  Icon(Icons.edit, 
                  size: 18, 
                  color: theme.brightness == Brightness.dark 
                      ? Colors.white70 
                      : theme.primaryColor)
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBikeTile(MapEntry<String, dynamic> bikeEntry, ThemeData theme) {
    final bikeInfo = bikeEntry.value as Map<String, dynamic>;
    final isAssigned = bikeInfo['isAssigned'] ?? false;
    final bikeId = bikeEntry.key;
    final assignedRider = bikeInfo['assignedRider'] ?? 'None';
    
    return InkWell(
      onTap: () {
        if (isAssigned) {
          _showDropBikeDialog(context, bikeId, assignedRider);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isAssigned ? Colors.green : Colors.red).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isAssigned ? Colors.green : Colors.red).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isAssigned ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                bikeId,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            Text(
              assignedRider,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
    
  void _showDropBikeDialog(BuildContext context, String bikeId, String riderName) {
    final localTheme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.bike_scooter,
            color: localTheme.colorScheme.error,
            size: 48,
          ),
          title: Text(
            'Drop this bike?',
            style: localTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to unassign',
                style: localTheme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                bikeId,
                style: localTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: localTheme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'from $riderName?',
                style: localTheme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: localTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: localTheme.colorScheme.error,
                backgroundColor: localTheme.colorScheme.errorContainer.withOpacity(0.1),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                try {
                  await FirebaseFirestore.instance
                      .collection('general')
                      .doc('general_variables')
                      .update({
                    'bikes.$bikeId.isAssigned': false,
                    'bikes.$bikeId.assignedRider': 'None',
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Bike $bikeId successfully dropped.'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to drop bike: $e'),
                        backgroundColor: localTheme.colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: localTheme.colorScheme.error,
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

  Widget _buildCompactSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required ThemeData theme,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactChip(double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatNumber(amount),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.grey),
            const SizedBox(width: 16),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14, color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(ThemeData theme, Map<String, dynamic> user, bool isDark) {
    final statuses = [
      {'label': 'Clocked In', 'value': _toBool(user['isClockedIn']), 'icon': Icons.access_time_filled},
      {'label': 'Charging', 'value': _toBool(user['isCharging']), 'icon': Icons.battery_charging_full_rounded},
      {'label': 'Active', 'value': _toBool(user['isActive']), 'icon': Icons.power_settings_new_rounded},
      {'label': 'Verified', 'value': _toBool(user['isVerified']), 'icon': Icons.verified_rounded},
      {'label': 'Sunday', 'value': _toBool(user['isWorkingOnSunday']), 'icon': Icons.calendar_month_rounded},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainer.withValues(alpha: 0.7),
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle_notifications_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Status Overview',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: statuses.map((status) {
                  final isActive = status['value'] as bool;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive
                            ? [theme.colorScheme.primary.withValues(alpha: 0.15), theme.colorScheme.primary.withValues(alpha: 0.05)]
                            : [Colors.transparent, Colors.transparent],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.4)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            status['icon'] as IconData,
                            size: 18,
                            color: isActive 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          status['label'] as String,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return 'KSh 0';
    final numValue = value is num ? value : num.tryParse(value.toString()) ?? 0;
    
    if (numValue >= 1000000) {
      return 'KSh ${(numValue / 1000000).toStringAsFixed(1)}M';
    }
    
    // ✅ ALWAYS show full number with commas - no K rounding
    final formatter = NumberFormat('#,##0');
    return 'KSh ${formatter.format(numValue.toInt())}';
  }

  @override
  void dispose() {
    _expiredEventsTimer?.cancel();
    _notificationService.dispose();
    _commissionController.dispose();
    super.dispose();
  }
}

class Totals {
  final double totalGross;
  final double totalNet;
  final double totalExpenses;
  Totals(this.totalGross, this.totalNet, this.totalExpenses);
}