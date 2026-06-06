import 'dart:async';

import 'package:billkmotolinkltd/pages/queued_damages.dart';
import 'package:billkmotolinkltd/pages/report_damages.dart';
import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/firebase_options.dart';

// Pages & Services
import 'pages/dashboard.dart';
import 'pages/clock_in.dart';
import 'pages/clock_out.dart';
import 'pages/corrections.dart';
import 'pages/batteries.dart';
import 'pages/polls.dart';
import 'pages/create_a_budget.dart';
import 'pages/require.dart';
import 'pages/asset_manager.dart';
import 'pages/user_manager.dart';
import 'pages/profiles.dart';
import 'pages/create_a_poll.dart';
import 'pages/activity_scheduler.dart';
import 'pages/reports.dart';
import 'pages/app_notifications.dart';
import 'pages/login.dart';
import 'pages/splash_screen.dart';
import 'pages/add_company_calendar.dart';
import 'pages/devices.dart';
import 'pages/memo.dart';
import 'pages/store.dart';
import 'pages/charge_batteries.dart';
import 'pages/settings.dart';
import 'pages/swap_batteries.dart';
import 'services/notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await NotificationService().initialize();

  runApp(const BillkMotolinkApp());
}

Future<bool> requestAllPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.notification,
    Permission.scheduleExactAlarm,
  ].request();

  bool allGranted = statuses[Permission.notification]?.isGranted ?? false;
  return allGranted;
}

Future<void> setupNotificationSystem() async {
  WidgetsFlutterBinding.ensureInitialized();

  final permissionsGranted = await requestAllPermissions();
  if (!permissionsGranted) return;

  await Firebase.initializeApp();
}


class BillkMotolinkApp extends StatelessWidget {
  const BillkMotolinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BILLK MOTOLINK LTD',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: const AuthGate(),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.teal,
      fontFamily: 'MyFont',
      scaffoldBackgroundColor: Colors.grey[100],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[100],
        elevation: 0.5,
        foregroundColor: Colors.black87,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
      listTileTheme: const ListTileThemeData(iconColor: Colors.black87),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.teal,
      fontFamily: 'MyFont',
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0.5,
        foregroundColor: Colors.white,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF1E1E1E)),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
      colorScheme: const ColorScheme.dark(
        primary: Colors.teal,
        secondary: Colors.tealAccent,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData) {
          return MainScaffold(
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
            },
          );
        }

        return LoginPage(onLogin: () async {});
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  const MainScaffold({
    super.key,
    required this.onLogout,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isCheckingConnectivity = true;

  late AnimationController _controller;
  bool _isExpanded = false;
  Timer? _animationTimer;
  String? _ourUID;
  StreamSubscription<DocumentSnapshot>? _userActiveListener;

  final List<Widget> _pages = [
    Dashboard(),
    ClockIn(),
    SwapBatteries(),
    ChargeBatteries(),
    ReportDamages(uid: FirebaseAuth.instance.currentUser!.uid),
    ClockOut(),
    Corrections(),
    Batteries(uid: FirebaseAuth.instance.currentUser!.uid),
    Polls(),
    CreateBudget(),
    Requirements(),
    AssetManager(),
    UserManager(),
    Profiles(),
    CreatePoll(),
    ActivityScheduler(),
    AddToCalendar(),
    Reports(),
    QueuedDamages(),
    CreateMemo(),
    CreateAndManageStore(),
    Devices(),
    UserSettings(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Clock In',
    'Swap Batteries',
    'Charge Batteries',
    'Report Damages',
    'Clock Out',
    'Correction',
    'Batteries',
    'Polls',
    'Create a Budget',
    'Require',
    'Asset Manager',
    'User Manager',
    'Profiles',
    'Create a Poll',
    'Activity Scheduler',
    'Add to Calendar',
    'Reports',
    'Queued Damages',
    'Memo',
    'Warehouse',
    'Devices',
    'Settings',
  ];

  final Map<String, List<int>> _rolePermissions = {
    'Staff': [0],
    'Rider': [0, 1, 2, 3, 4, 5, 6, 7, 8, 22],
    'Manager': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22],
    'Systems, IT': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22],
    'Technician': [0, 18, 22],
    'Store Keeper': [0, 20, 22],
    'Human Resource': [0, 9, 22],
    'CEO': [0, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22],
  };

  void _setupUserActiveListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _ourUID = user.uid;

    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(_ourUID)
        .snapshots();

    _userActiveListener = userDoc.listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data();
        final isActive = data?['isActive'] as bool? ?? true;

        if (!isActive) {
          await FirebaseAuth.instance.signOut();
          ToastService.error('Your account has been deactivated. Please contact support.');
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkAppVersion();
    setState(() => _isCheckingVersion = false);

    _setupUserActiveListener();
    _checkAppVersion();
    _setupUserActiveListener();
    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _startPulsing();
    _checkInitialConnectivity();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _isCheckingVersion = true;
  bool _appOutdated = false;
  String? _requiredVersion;
  String? _currentVersion;

  Future<void> _checkAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      final doc = await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .get();

      if (doc.exists) {
        _requiredVersion = doc.data()?['app_version'] as String?;

        if (_requiredVersion != null && _requiredVersion != _currentVersion) {
          setState(() {
            _appOutdated = true;
          });
          return;
        }
      }
    } catch (e) {
      print('Version check error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVersion = false;
        });
      }
    }
  }

  Widget _buildVersionMismatchDialog(ThemeData theme) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceVariant.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.orange, Colors.orange[600]!]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'App Update Required',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.orange[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your app is outdated.\n\nCurrent: $_currentVersion\nRequired: $_requiredVersion\n\nPlease update to the latest version.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => SystemNavigator.pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Close App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startPulsing() {
    _animationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isExpanded) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
      _isExpanded = !_isExpanded;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    widget.onLogout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialConnectivity();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationTimer?.cancel();
    _userActiveListener?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<int> _getVisibleIndices(String userRank) {
    final allIndices = <int>[];
    allIndices.addAll(_rolePermissions['all'] ?? []);
    final roleIndices = _rolePermissions[userRank] ?? [];
    allIndices.addAll(roleIndices);
    return allIndices.toSet().toList();
  }

  Color _getDrawerContentBg(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.white;
  }

  Future<void> _checkInitialConnectivity() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    final hasNetwork = results.any((result) => result != ConnectivityResult.none);

    if (!hasNetwork || !await _isOnline()) {
      if (mounted) setState(() => _isCheckingConnectivity = false);
    } else {
      if (mounted) setState(() => _isCheckingConnectivity = false);
    }
  }

  Widget _buildBottomActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: _getDrawerContentBg(theme),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black.withValues(alpha: 0.1)).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.red.shade700, Colors.red.shade500]
                  : [Colors.red, Colors.redAccent],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _logout,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isCheckingConnectivity) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isCheckingVersion) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking app version...'),
            ],
          ),
        ),
      );
    }

    if (_appOutdated) {
      return _buildVersionMismatchDialog(theme);
    }

    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      initialData: const [ConnectivityResult.none],
      builder: (context, connectivitySnapshot) {
        if (connectivitySnapshot.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final hasNetwork = connectivitySnapshot.data!.any((result) =>
            result != ConnectivityResult.none);

        return FutureBuilder<bool>(
          future: hasNetwork ? _isOnline() : Future.value(false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final isOnline = snapshot.data ?? false;
            if (!isOnline) {
              return _buildNoInternetPage(theme, () {
                setState(() => _isCheckingConnectivity = true);
              }, () => SystemNavigator.pop());
            }

            return Stack(
              children: [
                Scaffold(
                  appBar: AppBar(
                    title: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _titles[_selectedIndex],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    elevation: 0,
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: isDark ? 0.95 : 0.9),
                    shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                    actions: [
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final notificationCount = snapshot.data?.data() is Map<String, dynamic>
                              ? (snapshot.data!.data() as Map<String, dynamic>)['numberOfNotifications'] ?? 0
                              : 0;

                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [theme.colorScheme.primary.withValues(alpha: 0.2), Colors.transparent],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.notifications_outlined,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const AppNotifications()),
                                    );
                                  },
                                ),
                                if (notificationCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const AppNotifications()),
                                        );
                                      },
                                      child: AnimatedBuilder(
                                        animation: _controller,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: 0.8 + (_controller.value * 0.15),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [Colors.red.shade500, Colors.red.shade700],
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.red.withValues(alpha: 0.4),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                              child: Text(
                                                notificationCount > 99 ? '99+' : notificationCount.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.1,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  drawer: Drawer(
                    elevation: 16,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                                  theme.colorScheme.surfaceContainer.withValues(alpha: 0.9),
                                  theme.colorScheme.surface.withValues(alpha: 0.95),
                                ]
                              : [
                                  theme.colorScheme.primary.withValues(alpha: 0.15),
                                  theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                                  theme.colorScheme.surface.withValues(alpha: 0.98),
                                ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            // Header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary.withValues(alpha: 0.95),
                                    theme.colorScheme.primaryContainer,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(32),
                                  bottomRight: Radius.circular(32),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 92,
                                    height: 92,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/logo.png',
                                      fit: BoxFit.contain,
                                      color: isDark ? Colors.white : null,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(FirebaseAuth.instance.currentUser?.uid)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      final userRank = snapshot.data?['userRank']?.toString() ?? 'Staff';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)]),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          userRank.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Nav items
                            Expanded(
                              child: StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser?.uid)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  String userRank = 'Staff';
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    userRank = snapshot.data!['userRank']?.toString() ?? 'Staff';
                                  }

                                  final visibleIndices = _getVisibleIndices(userRank);

                                  return ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                                    itemCount: visibleIndices.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, listIndex) {
                                      final index = visibleIndices[listIndex];
                                      final isSelected = _selectedIndex == index;

                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        height: 60,
                                        margin: const EdgeInsets.symmetric(vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? LinearGradient(
                                                  colors: [
                                                    theme.colorScheme.primary.withValues(alpha: 0.2),
                                                    Colors.transparent,
                                                  ],
                                                )
                                              : null,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(20),
                                            onTap: () => _onDrawerItemTapped(index),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    padding: EdgeInsets.zero,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: isSelected
                                                            ? [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)]
                                                            : [theme.colorScheme.primary.withValues(alpha: 0.15), Colors.transparent],
                                                      ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      _getDrawerIcon(index),
                                                      color: isSelected ? Colors.white : theme.colorScheme.primary,
                                                      size: 22,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      _titles[index],
                                                      style: theme.textTheme.titleMedium?.copyWith(
                                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : theme.colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.chevron_right_rounded,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            _buildBottomActions(context),
                          ],
                        ),
                      ),
                    ),
                  ),

                  body: _pages[_selectedIndex],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _isOnline() async {
    try {
      final response = await http.get(
        Uri.parse("https://clients3.google.com/generate_204"),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Widget _buildNoInternetPage(ThemeData theme, VoidCallback onRefresh, VoidCallback onQuit) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_outlined,
                size: 120,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 32),
              Text(
                'No Internet Connection',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Your device is offline. Please check your connection.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: onQuit,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    label: const Text('Quit', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDrawerIcon(int index) {
    switch (index) {
      case 0: return Icons.dashboard;
      case 1: return Icons.add_link_outlined;
      case 2: return Icons.swap_horiz;
      case 3: return Icons.battery_charging_full;
      case 4: return Icons.precision_manufacturing_rounded;
      case 5: return Icons.cloud_sync_sharp;
      case 6: return Icons.webhook_sharp;
      case 7: return Icons.battery_4_bar_outlined;
      case 8: return Icons.poll_rounded;
      case 9: return Icons.restaurant_menu_rounded;
      case 10: return Icons.add_comment_sharp;
      case 11: return Icons.electric_bike;
      case 12: return Icons.account_tree_rounded;
      case 13: return Icons.supervised_user_circle_rounded;
      case 14: return Icons.how_to_vote_rounded;
      case 15: return Icons.timer;
      case 16: return Icons.calendar_month_rounded;
      case 17: return Icons.bar_chart_rounded;
      case 18: return Icons.precision_manufacturing_rounded;
      case 19: return Icons.support_agent_rounded;
      case 20: return Icons.warehouse_rounded;
      case 21: return Icons.phone_android;
      case 22: return Icons.settings;
      default: return Icons.circle;
    }
  }

  void _onDrawerItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.of(context).pop();
  }
}