import 'package:daitom/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_global.dart';
import 'package:intl/intl.dart';

// ── Who sees what ────────────────────────────────────────────────────────────
// Change the visibility rules for a role here, in one place.

enum _Status { clockedIn, verified, active, charging }

class _RoleView {
  /// "Daily Target" and "Previous Net" cards at the top.
  final bool statCards;

  /// The "Work Stats" section (bike, balance, notifications...).
  final bool workStats;

  /// "Change Photo" and "Apply Leave" buttons.
  final bool actions;

  /// Which chips appear under "Status".
  final Set<_Status> statuses;

  const _RoleView({
    required this.statCards,
    required this.workStats,
    required this.actions,
    required this.statuses,
  });

  static const _everything = _RoleView(
    statCards: true,
    workStats: true,
    actions: true,
    statuses: {_Status.clockedIn, _Status.verified, _Status.active, _Status.charging},
  );

  static const _rider = _RoleView(
    statCards: true,
    workStats: true,
    actions: true,
    statuses: {_Status.clockedIn, _Status.verified, _Status.active}, // no Charging
  );

  static const _leadership = _RoleView(
    statCards: false,
    workStats: false,
    actions: false,
    statuses: {_Status.verified, _Status.active}, // no Clocked In, no Charging
  );

  static _RoleView of(String? rank) {
    switch (rank?.trim().toLowerCase()) {
      case 'systems, it':
        return _everything;
      case 'ceo':
      case 'manager':
        return _leadership;
      case 'rider':
        return _rider;
      default:
        // Staff, Technician, Human Resource and any new role: same as a rider.
        return _rider;
    }
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────
class MyProfile extends StatefulWidget {
  const MyProfile({super.key});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  late Future<Map<String, dynamic>?> _future = FirebaseService.fetchUserData();

  Future<void> applyLeave() async {
    ToastService.warning("Leave application feature is under maintenance...");
  }

  Future<void> changeProfilePhoto() async {
    ToastService.warning("Profile photo change feature is under maintenance...");
  }

  Future<void> _refresh() async {
    final next = FirebaseService.fetchUserData();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return _ErrorView(error: snapshot.error?.toString());
          }

          final userData = snapshot.data!;
          final role = _RoleView.of(userData['userRank']?.toString());

          return RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top + 64,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ProfileHeaderDelegate(
                    topInset: MediaQuery.paddingOf(context).top,
                    name: userData['userName']?.toString() ?? 'Unknown',
                    rank: userData['userRank']?.toString() ?? '',
                    picUrl: userData['pfp_url']?.toString(),
                    isActive: userData['isActive'] == true,
                    canPop: Navigator.of(context).canPop(),
                    scheme: Theme.of(context).colorScheme,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ProfileBody(
                    userData: userData,
                    role: role,
                    onChangePhoto: changeProfilePhoto,
                    onApplyLeave: applyLeave,
                  ),
                ),
              ],
            ),
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
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
    final scheme = Theme.of(context).colorScheme;
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
                  color: scheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_off_rounded, size: 36, color: scheme.error),
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
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Go Back'),
                style: FilledButton.styleFrom(
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

// ── Header ───────────────────────────────────────────────────────────────────
/// Pinned header. Expanded: big photo, name and rank centred. As you scroll, the same
/// three elements glide into a slim bar: small photo on the left, name above rank.
/// Nothing disappears, so who you are looking at is always on screen.
class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ProfileHeaderDelegate({
    required this.topInset,
    required this.name,
    required this.rank,
    required this.picUrl,
    required this.isActive,
    required this.canPop,
    required this.scheme,
  });

  final double topInset; // status bar height: the header paints underneath it
  final String name;
  final String rank;
  final String? picUrl;
  final bool isActive;
  final bool canPop;
  final ColorScheme scheme;

  static const double _expandedBody = 272;
  static const double _collapsedBody = 64;

  @override
  double get maxExtent => topInset + _expandedBody;

  @override
  double get minExtent => topInset + _collapsedBody;

  @override
  bool shouldRebuild(covariant _ProfileHeaderDelegate old) =>
      old.topInset != topInset ||
      old.name != name ||
      old.rank != rank ||
      old.picUrl != picUrl ||
      old.isActive != isActive ||
      old.canPop != canPop ||
      old.scheme != scheme;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final e = Curves.easeInOutCubic.transform(t);
    final on = scheme.onPrimary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        // Photo
        final avatar = _lerp(100, 38, e);
        final avatarLeft = _lerp((w - 100) / 2, canPop ? 56 : 16, e);
        final avatarTop = _lerp(topInset + 60, topInset + (_collapsedBody - 38) / 2, e);

        // Name and rank share one left/right box and slide from centred to left-aligned.
        final textLeft = _lerp(24, (canPop ? 56 : 16) + 38 + 12, e);
        final textRight = _lerp(24, 16, e);
        final textAlign = Alignment.lerp(Alignment.topCenter, Alignment.topLeft, e)!;
        final nameTop = _lerp(topInset + 172, topInset + 9, e);
        final rankTop = _lerp(topInset + 206, topInset + 33, e);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.primary.withValues(alpha: 0.82)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(_lerp(28, 0, e))),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.22 * t),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Decorative circles fade out as the header collapses.
              Positioned(
                top: -40,
                right: -40,
                child: Opacity(
                  opacity: 1 - e,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: on.withValues(alpha: 0.06)),
                  ),
                ),
              ),
              Positioned(
                top: 30,
                right: 60,
                child: Opacity(
                  opacity: 1 - e,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: on.withValues(alpha: 0.05)),
                  ),
                ),
              ),

              Positioned(
                left: avatarLeft,
                top: avatarTop,
                child: _Avatar(
                  size: avatar,
                  picUrl: picUrl,
                  name: name,
                  isActive: isActive,
                  ringColor: on,
                  shadowColor: scheme.shadow,
                  fillColor: scheme.primaryContainer,
                  letterColor: scheme.onPrimaryContainer,
                ),
              ),

              Positioned(
                left: textLeft,
                right: textRight,
                top: nameTop,
                child: Align(
                  alignment: textAlign,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: on,
                      fontSize: _lerp(22, 16, e),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),

              if (rank.isNotEmpty)
                Positioned(
                  left: textLeft,
                  right: textRight,
                  top: rankTop,
                  child: Align(
                    alignment: textAlign,
                    child: Container(
                      height: _lerp(28, 20, e),
                      padding: EdgeInsets.symmetric(horizontal: _lerp(14, 9, e)),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: on.withValues(alpha: 0.28)),
                      ),
                      child: Text(
                        rank,
                        style: TextStyle(
                          color: on,
                          fontSize: _lerp(12, 10.5, e),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),

              if (canPop)
                Positioned(
                  left: 4,
                  top: topInset + 8,
                  child: IconButton(
                    tooltip: 'Back',
                    icon: Icon(Icons.arrow_back_rounded, color: on),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final double size;
  final String? picUrl;
  final String name;
  final bool isActive;
  final Color ringColor;
  final Color shadowColor;
  final Color fillColor;
  final Color letterColor;

  const _Avatar({
    required this.size,
    required this.picUrl,
    required this.name,
    required this.isActive,
    required this.ringColor,
    required this.shadowColor,
    required this.fillColor,
    required this.letterColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = size > 60 ? 3.5 : 2.0;
    final dot = (size * 0.22).clamp(9.0, 22.0);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final hasPic = picUrl != null && picUrl!.isNotEmpty;

    final fallback = Container(
      color: fillColor,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(color: letterColor, fontSize: size * 0.42, fontWeight: FontWeight.w800),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: ring),
              boxShadow: [
                BoxShadow(color: shadowColor.withValues(alpha: 0.25), blurRadius: size * 0.16, offset: Offset(0, size * 0.06)),
              ],
            ),
            child: ClipOval(
              child: hasPic
                  ? Image.network(
                      picUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => fallback,
                      loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
                    )
                  : fallback,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: isActive ? scheme.primaryContainer : scheme.outline,
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: size > 60 ? 2.5 : 1.5),
              ),
              child: isActive
                  ? Icon(Icons.check_rounded, size: dot * 0.7, color: scheme.onPrimaryContainer)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────
class _ProfileBody extends StatelessWidget {
  final Map<String, dynamic> userData;
  final _RoleView role;
  final VoidCallback onChangePhoto;
  final VoidCallback onApplyLeave;

  const _ProfileBody({
    required this.userData,
    required this.role,
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

  bool _flag(String key) => userData[key] == true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final chips = <Widget>[
      if (role.statuses.contains(_Status.clockedIn))
        _StatusChip(label: 'Clocked In', active: _flag('isClockedIn'), icon: Icons.access_time_rounded),
      if (role.statuses.contains(_Status.verified))
        _StatusChip(label: 'Verified', active: _flag('isVerified'), icon: Icons.verified_rounded),
      if (role.statuses.contains(_Status.active))
        _StatusChip(label: 'Active', active: _flag('isActive'), icon: Icons.circle),
      if (role.statuses.contains(_Status.charging))
        _StatusChip(label: 'Charging', active: _flag('isCharging'), icon: Icons.battery_charging_full_rounded),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 40 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (role.statCards) ...[
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Daily Target',
                    value: _formatNumber(userData['dailyTarget']),
                    icon: Icons.flag_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Previous Net',
                    value: _formatNumber(userData['netClockedLastly']),
                    icon: Icons.trending_up_rounded,
                    color: scheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          if (role.actions) ...[
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Change Photo',
                    icon: Icons.photo_camera_rounded,
                    color: scheme.primary,
                    onTap: onChangePhoto,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Apply Leave',
                    icon: Icons.event_busy_rounded,
                    color: scheme.error,
                    onColor: scheme.onError,
                    onTap: onApplyLeave,
                    filled: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],

          const _SectionHeader(title: 'Profile Details'),
          const SizedBox(height: 12),
          _InfoGroup(
            items: [
              _InfoRow(icon: Icons.person_rounded,      label: 'Name',      value: _str(userData['userName'])),
              _InfoRow(icon: Icons.badge_rounded,       label: 'Role',      value: _str(userData['userRank'])),
              _InfoRow(icon: Icons.phone_rounded,       label: 'Phone',     value: _str(userData['phoneNumber']), copyable: true),
              _InfoRow(icon: Icons.email_rounded,       label: 'Email',     value: _str(userData['email']),       copyable: true),
              _InfoRow(icon: Icons.credit_card_rounded, label: 'ID Number', value: _str(userData['idNumber']),    copyable: true),
              _InfoRow(icon: Icons.wc_rounded,          label: 'Gender',    value: _str(userData['gender'])),
            ],
          ),

          if (role.workStats) ...[
            const SizedBox(height: 28),
            const _SectionHeader(title: 'Work Stats'),
            const SizedBox(height: 12),
            _InfoGroup(
              accentColor: scheme.tertiary,
              items: [
                _InfoRow(icon: Icons.flag_rounded,                   label: 'Daily Target',  value: _formatNumber(userData['dailyTarget'])),
                _InfoRow(icon: Icons.directions_bike_rounded,        label: 'Current Bike',  value: _str(userData['currentBike'], 'None')),
                _InfoRow(icon: Icons.account_balance_wallet_rounded, label: 'Balance',       value: _formatCurrency(userData['currentInAppBalance'])),
                _InfoRow(icon: Icons.notifications_rounded,          label: 'Notifications', value: _str(userData['numberOfNotifications'], '0')),
              ],
            ),
          ],

          if (chips.isNotEmpty) ...[
            const SizedBox(height: 28),
            const _SectionHeader(title: 'Status'),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: chips),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

BoxDecoration _cardDecoration(ColorScheme scheme, {Color? glow}) => BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: scheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: (glow ?? scheme.shadow).withValues(alpha: glow == null ? 0.05 : 0.10),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

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
            color: Theme.of(context).colorScheme.primary,
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
  final bool copyable;
  const _InfoRow({required this.icon, required this.label, required this.value, this.copyable = false});
}

class _InfoGroup extends StatelessWidget {
  final List<_InfoRow> items;
  final Color? accentColor;

  const _InfoGroup({required this.items, this.accentColor});

  Future<void> _copy(BuildContext context, _InfoRow item) async {
    await Clipboard.setData(ClipboardData(text: item.value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item.label} copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;

    return Container(
      decoration: _cardDecoration(scheme),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          final canCopy = item.copyable && item.value != 'N/A';
          return Column(
            children: [
              InkWell(
                onTap: canCopy ? () => _copy(context, item) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: accent, size: 18),
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
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canCopy)
                        Icon(Icons.copy_rounded, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, indent: 64, color: scheme.outlineVariant),
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(scheme, glow: color),
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
              color: scheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
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
  final Color? onColor; // icon/text colour when filled
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onColor,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? (onColor ?? Theme.of(context).colorScheme.onPrimary) : color;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: active ? 0.30 : 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
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
