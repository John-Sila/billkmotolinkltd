import 'package:billkmotolinkltd/pages/settings/calendar_of_events.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:billkmotolinkltd/pages/settings/help_and_faq.dart';
import 'package:billkmotolinkltd/pages/settings/my_profile.dart';
import 'package:billkmotolinkltd/pages/settings/terms_and_conditions.dart';
import 'package:billkmotolinkltd/pages/settings/view_and_clear_app_data.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UserSettings extends StatefulWidget {
  const UserSettings({super.key});

  @override
  State<UserSettings> createState() => _UserSettingsState();
}

class _UserSettingsState extends State<UserSettings> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version; // e.g., "1.0.1"

      if (mounted) {
        setState(() {
          _appVersion = version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'unknown';
        });
      }
    }
  }
  Future<String> getCurrentAppVersion() async {
    WidgetsFlutterBinding.ensureInitialized(); // Required before runApp()
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version; // e.g., "1.0.1"
  }

  Future<void> logout() async {
    // Implement your logout logic here
    FirebaseAuth.instance.signOut();
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          // Account Section
          _buildSectionHeader('Account'),
          _buildNavTile(
            context,
            Icons.person_outline,
            'My Profile',
            'Manage your account details',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyProfile()),
            ),
          ),

          const SizedBox(height: 24),

          // Data & Storage
          _buildSectionHeader('Data & Storage'),
          _buildNavTile(
            context,
            Icons.storage,
            'Manage Storage',
            'View and clear app data',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ViewAndClearAppData()),
            ),
          ),
          const SizedBox(height: 24),

          // Support Section
          _buildSectionHeader('Support'),
          _buildNavTile(
            context,
            Icons.help_outline,
            'Help & FAQ',
            'Get help with common issues',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpAndFAQ()),
            ),
          ),
          _buildNavTile(
            context,
            Icons.format_list_bulleted,
            'Terms of Service',
            'Review our terms and conditions',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TermsAndConditions()),
            ),
          ),
          _buildNavTile(
            context,
            Icons.calendar_month,
            'Company Calendar',
            'View company events',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CalendarOfEvents()),
            ),
          ),
          _buildNavTile(
            context,
            Icons.info_outline,
            'About BILLK MOTOLINK LTD',
            'Version $_appVersion | Learn more about us',
            () {},
          ),

          const SizedBox(height: 32),
          
          // Logout
          _buildDestructiveTile(
            context,
            Icons.logout,
            'Log Out',
            () {
              _showLogoutConfirmationDialog(context);
            },
          ),
        
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    final localTheme = Theme.of(context);
    final colorScheme = localTheme.colorScheme;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.logout,
            color: colorScheme.error,
            size: 48,
          ),
          title: Text(
            'Log Out',
            style: localTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to log out?',
                style: localTheme.textTheme.bodyMedium?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You will need to sign in again to access your account and data.',
                style: localTheme.textTheme.bodySmall?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
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
                backgroundColor: colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                logout();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            Icons.logout,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text('Logged out successfully'),
                        ],
                      ),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Log Out',
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



  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.teal, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, 
                   color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestructiveTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final primaryError = colorScheme.error;
    
    final containerGradient = LinearGradient(
      colors: [
        primaryError.withValues(alpha: 0.12),
        primaryError.withValues(alpha: isDark ? 0.3 : 0.08).withValues(alpha: 0.8),
        primaryError.withValues(alpha: 0.08),
      ],
    );
    
    final iconGradient = RadialGradient(
      colors: [primaryError.withValues(alpha: 0.8), primaryError.withValues(alpha: 1.0)],
    );
    
    final textGradient = RadialGradient(
      colors: [primaryError.withValues(alpha: 0.9), primaryError.withValues(alpha: 1.0)],
    );
    
    final arrowGradient = RadialGradient(
      colors: [primaryError.withValues(alpha: 0.7), primaryError.withValues(alpha: 0.9)],
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: containerGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryError.withValues(alpha: isDark ? 0.5 : 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryError.withValues(alpha: isDark ? 0.35 : 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: primaryError.withValues(alpha: isDark ? 0.2 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: primaryError.withValues(alpha: isDark ? 0.35 : 0.25),
          highlightColor: primaryError.withValues(alpha: isDark ? 0.2 : 0.12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                // Adaptive Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: iconGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryError.withValues(alpha: isDark ? 0.6 : 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                    shadows: [
                      Shadow(
                        color: (isDark ? Colors.black : Colors.black87).withValues(alpha: 0.5),
                        offset: const Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Adaptive Title
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => textGradient.createShader(bounds),
                    blendMode: BlendMode.srcATop,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: (isDark ? Colors.black : Colors.black87).withValues(alpha: 0.5),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Adaptive Arrow
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(value * 3, 0),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: arrowGradient,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: primaryError.withValues(alpha: isDark ? 0.7 : 0.6),
                              blurRadius: 10,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 14,
                          shadows: [
                            Shadow(
                              color: (isDark ? Colors.black : Colors.black54).withValues(alpha: 0.4),
                              offset: const Offset(1, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
