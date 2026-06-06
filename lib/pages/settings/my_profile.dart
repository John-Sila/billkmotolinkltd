import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:flutter/material.dart';
import '../../services/firebase_global.dart';
import 'package:intl/intl.dart';

class MyProfile extends StatelessWidget {
  const MyProfile({super.key});

  Future<void> applyLeave() async {
    ToastService.warning("Leave application feature is under maintenance...");
  }

  Future<void> changeProfilePhoto() async {
    ToastService.warning("Profile photo change feature is under maintenance...");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: FirebaseService.fetchUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return _ErrorView(error: snapshot.error?.toString());
          }

          final userData = snapshot.data!;
          return CustomScrollView(
            slivers: [
              _ProfileAppBar(userData: userData),
              SliverToBoxAdapter(
                child: _ProfileBody(
                  userData: userData,
                  onChangePhoto: changeProfilePhoto,
                  onApplyLeave: applyLeave,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Loading ─────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Colors.teal),
            SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error ───────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String? error;
  const _ErrorView({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_off_rounded, size: 36, color: Colors.red),
              ),
              const SizedBox(height: 20),
              Text(
                'Could not load profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                error ?? 'No data available',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Go Back'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SliverAppBar ─────────────────────────────────────────────────────────────
class _ProfileAppBar extends StatelessWidget {
  final Map<String, dynamic> userData;
  const _ProfileAppBar({required this.userData});

  @override
  Widget build(BuildContext context) {
    final profilePic = userData['pfp_url'] ??
        'https://img.icons8.com/liquid-glass-color/1200/user-male-circle.jpg';
    final isActive = userData['isActive'] ?? false;

    return SliverAppBar(
      expandedHeight: 300,
      floating: true,
      snap: true,
      pinned: true,
      backgroundColor: const Color(0xFF0043BA),
      elevation: 0,
      title: Text(
        userData['userName'] ?? 'Profile',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.3,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient bg
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF003DA5), Color(0xFF0066EE)],
                ),
              ),
            ),

            // Decorative circles
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              top: 30,
              right: 60,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),

            // Avatar + name in expanded area
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  _AvatarWidget(profilePic: profilePic, isActive: isActive),
                  const SizedBox(height: 12),
                  Text(
                    userData['userName'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      userData['userRank'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.15)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  final String profilePic;
  final bool isActive;
  const _AvatarWidget({required this.profilePic, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
            ],
            image: DecorationImage(fit: BoxFit.cover, image: NetworkImage(profilePic)),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF22C55E) : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────
class _ProfileBody extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onChangePhoto;
  final VoidCallback onApplyLeave;

  const _ProfileBody({
    required this.userData,
    required this.onChangePhoto,
    required this.onApplyLeave,
  });

  String _str(dynamic v, [String fallback = 'N/A']) =>
      v == null ? fallback : v.toString();

  String _formatNumber(dynamic value) {
    if (value == null) return 'KSh 0';
    final n = value is num ? value : num.tryParse(value.toString()) ?? 0;
    if (n >= 1000000) return 'KSh ${(n / 1000000).toStringAsFixed(1)}M';
    return 'KSh ${NumberFormat('#,##0').format(n.toInt())}';
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Ksh 0';
    final n = value is num ? value : double.tryParse(value.toString()) ?? 0.0;
    return 'Ksh ${NumberFormat('#,##0').format(n.toInt())}';
  }

  bool get _isCEO => userData['userRank']?.toString().toLowerCase() == 'ceo';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Stats row (non-CEO only)
          if (!_isCEO) ...[
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Daily Target',
                    value: _formatNumber(userData['dailyTarget']),
                    icon: Icons.flag_rounded,
                    color: Colors.teal,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Previous Net',
                    value: _formatNumber(userData['netClockedLastly']),
                    icon: Icons.trending_up_rounded,
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Change Photo',
                  icon: Icons.photo_camera_rounded,
                  color: Colors.teal,
                  onTap: onChangePhoto,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'Apply Leave',
                  icon: Icons.event_busy_rounded,
                  color: Colors.red,
                  onTap: onApplyLeave,
                  isDark: isDark,
                  filled: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Profile details
          _SectionHeader(title: 'Profile Details'),
          const SizedBox(height: 12),
          _InfoGroup(
            isDark: isDark,
            items: [
              _InfoRow(icon: Icons.person_rounded,        label: 'Name',      value: _str(userData['userName'])),
              _InfoRow(icon: Icons.badge_rounded,         label: 'Role',      value: _str(userData['userRank'])),
              _InfoRow(icon: Icons.phone_rounded,         label: 'Phone',     value: _str(userData['phoneNumber'])),
              _InfoRow(icon: Icons.email_rounded,         label: 'Email',     value: _str(userData['email'])),
              _InfoRow(icon: Icons.credit_card_rounded,   label: 'ID Number', value: _str(userData['idNumber'])),
              _InfoRow(icon: Icons.wc_rounded,            label: 'Gender',    value: _str(userData['gender'])),
            ],
          ),

          if (!_isCEO) ...[
            const SizedBox(height: 28),
            _SectionHeader(title: 'Work Stats'),
            const SizedBox(height: 12),
            _InfoGroup(
              isDark: isDark,
              accentColor: Colors.orange,
              items: [
                _InfoRow(icon: Icons.flag_rounded,                    label: 'Daily Target',   value: _formatNumber(userData['dailyTarget'])),
                _InfoRow(icon: Icons.directions_bike_rounded,         label: 'Current Bike',   value: _str(userData['currentBike'], 'None')),
                _InfoRow(icon: Icons.account_balance_wallet_rounded,  label: 'Balance',        value: _formatCurrency(userData['currentInAppBalance'])),
                _InfoRow(icon: Icons.notifications_rounded,           label: 'Notifications',  value: _str(userData['numberOfNotifications'], '0')),
              ],
            ),
          ],

          const SizedBox(height: 28),

          // Status
          _SectionHeader(title: 'Status'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip(label: 'Clocked In', active: userData['isClockedIn'] ?? false,   icon: Icons.access_time_rounded),
              _StatusChip(label: 'Verified',   active: userData['isVerified'] ?? false,    icon: Icons.verified_rounded),
              _StatusChip(label: 'Active',     active: userData['isActive'] ?? false,      icon: Icons.circle),
              _StatusChip(label: 'Charging',   active: userData['isCharging'] ?? false,    icon: Icons.battery_charging_full_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
}

class _InfoGroup extends StatelessWidget {
  final List<_InfoRow> items;
  final bool isDark;
  final Color accentColor;

  const _InfoGroup({
    required this.items,
    required this.isDark,
    this.accentColor = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: accentColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 64,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isDark,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;

  const _StatusChip({required this.label, required this.active, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF22C55E) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class StatsItem {
  final String title;
  final String value;
  const StatsItem(this.title, this.value);
}

class StatusItem {
  final String title;
  final bool isActive;
  final IconData icon;
  const StatusItem(this.title, this.isActive, this.icon);
}