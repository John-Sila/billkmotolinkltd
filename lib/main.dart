import 'dart:async';

import 'package:daitom/pages/absenteesm.dart';
import 'package:daitom/services/toast_service.dart';
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
import 'theme/app_theme.dart';

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
import 'pages/assignments.dart';
import 'pages/charge_batteries.dart';
import 'pages/settings.dart';
import 'pages/swap_batteries.dart';
import 'services/notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge: the app draws behind the status bar and navigation bar. The bar
  // colours/icon brightness follow the theme (see DaitomApp.builder below).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Paint the logo splash straight away. Firebase and notifications are
  // initialised behind it (see AppBootstrap) instead of before the first frame,
  // which is what used to leave a blank screen on launch.
  runApp(const DaitomApp());
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


class DaitomApp extends StatelessWidget {
  const DaitomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAITOM MOTORLINK LTD',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: const AppBootstrap(),
      // Transparent system bars, with icon colours that follow light/dark theme.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final icons = isDark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons, // Android
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // iOS
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: icons,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  ThemeData _lightTheme() => AppTheme.light();

  ThemeData _darkTheme() => AppTheme.dark();
}

/// Shows the splash while the app's services start, then fades into [AuthGate].
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  /// The logo never flashes by: show it for at least this long even when
  /// start-up is faster. Lower it (or set to Duration.zero) to launch faster.
  static const Duration _minSplash = Duration(milliseconds: 1200);

  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_error != null) setState(() => _error = null);

    final minSplash = Future<void>.delayed(_minSplash);
    try {
      await _initialiseServices();
      await minSplash;
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('App start-up failed: $e\n$st');
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _initialiseServices() async {
    // Already initialised on a retry or hot restart.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (e) {
      // Firestore refuses settings changes once it has been used (hot restart).
      debugPrint('Firestore settings not applied: $e');
    }

    // Notifications are optional: never block the app from opening on them.
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('Notification setup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      child: _ready
          ? const AuthGate(key: ValueKey('app'))
          : SplashScreen(
              key: const ValueKey('splash'),
              error: _error,
              onRetry: _start,
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
          return const SplashScreen(settled: true);
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

  // Connectivity state lives here (not in build) so a network blip or an app
  // resume never tears the page tree down. We start optimistic (online) and only
  // overlay the "No Internet" screen on top of the scaffold if a check fails.
  bool _online = true;
  bool _verifyingConnection = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  late AnimationController _controller;
  bool _isExpanded = false;
  Timer? _animationTimer;
  String? _ourUID;
  StreamSubscription<DocumentSnapshot>? _userActiveListener;

  // Filled by the single user-doc listener in _setupUserActiveListener(). Because
  // these live in State, the drawer and the app bar always have the current values
  // the moment they build (a broadcast stream would not replay them to a drawer
  // that is built later, which is what hid your menu items).
  String _userRank = 'Staff';
  int _notificationCount = 0;

  final List<Widget> _pages = [
    Dashboard(), // 0
    ClockIn(), // 1
    SwapBatteries(), // 2
    ChargeBatteries(), // 3
    ClockOut(), // 4
    Corrections(), // 5
    Batteries(uid: FirebaseAuth.instance.currentUser!.uid), // 6
    Polls(), // 7
    CreateBudget(), // 8
    Requirements(), // 9
    AssetManager(), // 10
    UserManager(), // 11
    Profiles(), // 12
    CreatePoll(), // 13
    ActivityScheduler(), // 14
    AddToCalendar(), // 15
    Reports(), // 16
    CreateMemo(), // 17
    Assignments(), // 18
    Devices(), // 19
    UserSettings(), // 20
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Clock In',
    'Swap Batteries',
    'Charge Batteries',
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
    'Memo',
    'Assignments',
    'Devices',
    'Settings',
  ];

  final Map<String, List<int>> _rolePermissions = {
    'Staff': [0],
    'Rider': [0, 1, 2, 3, 4, 5, 6, 7, 20],
    'Manager': [0, 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 18, 20],
    'Systems, IT': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    'Technician': [0, 20],
    'Human Resource': [0, 8, 20],
    'CEO': [0, 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 18, 19, 20],
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
        final rank = data?['userRank']?.toString() ?? 'Staff';
        final count = (data?['numberOfNotifications'] as num?)?.toInt() ?? 0;
        if (mounted && (rank != _userRank || count != _notificationCount)) {
          setState(() {
            _userRank = rank;
            _notificationCount = count;
          });
        }

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
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _startPulsing();

    // Each of these used to run twice (the user listener leaked a subscription and
    // the version check hit Firestore twice). Once each is enough.
    _setupUserActiveListener();
    _checkAppVersion();

    // React to network changes in the background instead of rebuilding the UI
    // around a FutureBuilder.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) => _verifyConnection());
    _verifyConnection();
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
          if (mounted) {
            setState(() {
              _appOutdated = true;
            });
          }
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
      _verifyConnection();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationTimer?.cancel();
    _userActiveListener?.cancel();
    _connectivitySub?.cancel();
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

  /// Checks connectivity in the background and only calls setState when the
  /// online/offline answer actually CHANGES. No spinner, no widget swap, so the
  /// current page keeps its state.
  Future<void> _verifyConnection() async {
    if (_verifyingConnection) return;
    _verifyingConnection = true;
    try {
      var online = await _hasInternet();
      if (!online) {
        // The network is often not ready for a moment after resume or a
        // Wi-Fi <-> mobile data switch. Give it one more shot before we block the UI.
        await Future.delayed(const Duration(seconds: 2));
        online = await _hasInternet();
      }
      if (mounted && online != _online) {
        setState(() => _online = online);
      }
    } finally {
      _verifyingConnection = false;
    }
  }

  Future<bool> _hasInternet() async {
    final results = await Connectivity().checkConnectivity();
    if (results.every((result) => result == ConnectivityResult.none)) return false;
    return _isOnline();
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
    final visibleIndices = _getVisibleIndices(_userRank);

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

    // The Scaffold is ALWAYS in the tree from here on. The "No Internet" screen is
    // just an overlay on top of it, so the current page is never disposed and
    // rebuilt when connectivity is re-checked.
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
              Builder(
                builder: (context) {
                  final notificationCount = _notificationCount;

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
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: theme.colorScheme.surface,
            child: SafeArea(
              // The header paints under the status bar itself (edge-to-edge), so only
              // the bottom inset (gesture bar) is handled here.
              top: false,
              child: Column(
                children: [
                  // One scroll view for header + menu: the header scrolls away with the
                  // list, shrinking until only the rank pill is left, pinned top-left.
                  Expanded(
                    child: CustomScrollView(
                      // Remembers the scroll position across close/open (one double in
                      // PageStorage; nothing is kept alive). Keyed by user so the next
                      // person to log in doesn't inherit it.
                      key: PageStorageKey('drawer-scroll-${FirebaseAuth.instance.currentUser?.uid}'),
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _DrawerHeaderDelegate(
                            topInset: MediaQuery.paddingOf(context).top,
                            rank: _userRank,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: visibleIndices.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 6),
                            itemBuilder: (context, listIndex) =>
                                _buildDrawerItem(theme, visibleIndices[listIndex]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildBottomActions(context),
                ],
              ),
            ),
          ),

          // Edge-to-edge: pages draw behind the system bars, so keep their content
          // clear of the bottom gesture/navigation bar. (The AppBar already pads the
          // status bar itself.)
          body: SafeArea(top: false, child: _pages[_selectedIndex]),
        ),

        // Offline overlay: sits ON TOP of the scaffold instead of replacing it.
        if (!_online)
          Positioned.fill(
            child: _buildNoInternetPage(
              theme,
              _verifyConnection,
              () => SystemNavigator.pop(),
            ),
          ),
      ],
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
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
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

  /// One menu row: tinted icon tile (solid when selected), soft shadow and a
  /// trailing chevron on the selected row only.
  Widget _buildDrawerItem(ThemeData theme, int index) {
    final isSelected = _selectedIndex == index;

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onDrawerItemTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getDrawerIcon(index),
                  color: isSelected ? Colors.white : theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _titles[index],
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
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
      case 4: return Icons.cloud_sync_sharp;
      case 5: return Icons.webhook_sharp;
      case 6: return Icons.battery_4_bar_outlined;
      case 7: return Icons.poll_rounded;
      case 8: return Icons.restaurant_menu_rounded;
      case 9: return Icons.add_comment_sharp;
      case 10: return Icons.electric_bike;
      case 11: return Icons.account_tree_rounded;
      case 12: return Icons.supervised_user_circle_rounded;
      case 13: return Icons.how_to_vote_rounded;
      case 14: return Icons.timer;
      case 15: return Icons.calendar_month_rounded;
      case 16: return Icons.bar_chart_rounded;
      case 17: return Icons.support_agent_rounded;
      case 18: return Icons.assignment_ind_rounded;
      case 19: return Icons.phone_android;
      case 20: return Icons.settings;
      default: return Icons.circle;
    }
  }

  void _onDrawerItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.of(context).pop();
  }
}

/// Drawer header that lives inside the menu's scroll view.
///
/// Expanded: logo, app name and the rank pill under them. As the menu scrolls, the
/// logo and name fade up and out while the rank pill glides to the top-left and stays
/// pinned there as a slim bar (with a small logo fading in on the right).
class _DrawerHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DrawerHeaderDelegate({
    required this.topInset,
    required this.rank,
    required this.color,
  });

  final double topInset; // status bar height: the header paints underneath it
  final String rank;
  final Color color;

  static const double _expandedBody = 124;
  static const double _collapsedBody = 56;
  static const double _logoSize = 60;
  static const double _pillHeight = 28;

  @override
  double get maxExtent => topInset + _expandedBody;

  @override
  double get minExtent => topInset + _collapsedBody;

  @override
  bool shouldRebuild(covariant _DrawerHeaderDelegate old) =>
      old.topInset != topInset || old.rank != rank || old.color != color;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  Widget _logo(double size, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Colors.white.withValues(alpha: 0.15),
          child: Icon(Icons.school_rounded, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final e = Curves.easeOutCubic.transform(t);

    // Big logo + name leave first (fully gone by ~55% of the scroll); the small logo
    // arrives last.
    final bigOpacity = (1 - t / 0.55).clamp(0.0, 1.0);
    final smallOpacity = ((t - 0.6) / 0.4).clamp(0.0, 1.0);

    final pillTop = _lerp(topInset + 14 + _logoSize + 10, topInset + (_collapsedBody - _pillHeight) / 2, e);
    final pillLeft = _lerp(20, 16, e);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.82)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(_lerp(28, 18, e))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22 * t),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Large logo and app name.
          Positioned(
            left: 20,
            top: _lerp(topInset + 14, topInset - 6, e),
            child: Opacity(
              opacity: bigOpacity,
              child: Transform.scale(
                scale: _lerp(1, 0.8, e),
                alignment: Alignment.topLeft,
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _logo(_logoSize, 16),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Daitom',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Small logo in the collapsed bar.
          Positioned(
            right: 16,
            top: topInset + (_collapsedBody - 30) / 2,
            child: Opacity(opacity: smallOpacity, child: _logo(30, 9)),
          ),

          // The rank pill: glides from under the logo to the top-left and sticks.
          Positioned(
            left: pillLeft,
            top: pillTop,
            child: Container(
              height: _pillHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _lerp(0.18, 0.26, e)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                rank.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
