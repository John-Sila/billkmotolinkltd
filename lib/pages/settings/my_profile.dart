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
      body: FutureBuilder<Map<String, dynamic>?>(
        future: FirebaseService.fetchUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error?.toString() ?? 'No data available',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          final userData = snapshot.data!;
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(userData),
              SliverToBoxAdapter(child: _buildProfileContent(context, userData)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> userData) {
    final profilePic = userData['pfp_url'] ??
        'https://play-lh.googleusercontent.com/-mwzZp4kxOZmCkGEOlOHbLtYz_Vn565KlSBW0zEr-rJfUBV232pRKdOtCnKwccPp2E33';
    
    return SliverAppBar(
      expandedHeight: 280,
      floating: true,
      snap: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Container(  // ✅ Title moves to AppBar level
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userData['userName'] ?? 'Unknown User',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            Text(
              userData['userRank'] ?? '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),  // ✅ Fixed opacity
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff0043ba), Color(0xff006df1)],
                ),
              ),
            ),
            // Profile image positioned properly
            Positioned(
              bottom: 20,  // ✅ Raised higher to avoid title overlap
              left: 20,
              right: 20,
              child: Center(
                child: _buildProfileImage(profilePic, userData['isActive'] ?? false),
              ),
            ),
            // Subtle gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(String profilePic, bool isActive) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: NetworkImage(profilePic),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileContent(BuildContext context, Map<String, dynamic> userData) {
    Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          _buildStatsRow(context, userData),
          
          const SizedBox(height: 32),
          
          // Quick Actions
          _buildActionButtons(context),
          
          const SizedBox(height: 32),
          
          // Profile Details
          _buildSectionHeader(context, 'Profile Details'),
          _buildInfoCard(context, 'userName', 'Name', _safeToString(userData['userName'], '')),
          _buildInfoCard(context, 'userRank', 'Role', _safeToString(userData['userRank'], '')),
          _buildInfoCard(context, 'phoneNumber', 'Phone', _safeToString(userData['phoneNumber'], '')),
          _buildInfoCard(context, 'email', 'Email', _safeToString(userData['email'], '')),
          _buildInfoCard(context, 'idNumber', 'ID Number', _safeToString(userData['idNumber'], '')),
          _buildInfoCard(context, 'gender', 'Gender', _safeToString(userData['gender'], 'N/A')),
          
          const SizedBox(height: 24),
          
          // Work Stats
          
          if (userData['userRank']?.toString().toLowerCase() != 'ceo') ...[
            _buildSectionHeader(context, 'Work Stats'),
            _buildWorkInfoCard(context, 'dailyTarget', 'Daily Target', _formatNumber(userData['dailyTarget'])),
            _buildWorkInfoCard(context, 'currentBike', 'Current Bike', _safeToString(userData['currentBike'], 'None')),
            _buildWorkInfoCard(context, 'currentInAppBalance', 'Balance', _formatCurrency(userData['currentInAppBalance'])),
            _buildWorkInfoCard(context, 'numberOfNotifications', 'Notifications', _formatNumber(userData['numberOfNotifications'])),
            const SizedBox(height: 24),
          ],

          
          // Status Indicators
          _buildSectionHeader(context, 'Status'),
          _buildStatusRow(context, userData),
        ],
      ),
    );
  }

  // Add these helper methods to your class:
  String _safeToString(dynamic value, [String defaultValue = 'N/A']) {
    if (value == null) return defaultValue;
    return value.toString();
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

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Ksh 0';
    final numValue = (value is num) ? value : double.tryParse(value.toString()) ?? 0.0;
    return 'Ksh ${numValue.toStringAsFixed(0)}';
  }

  Widget _buildStatsRow(BuildContext context, Map<String, dynamic> userData) {
    if (userData['userRank'] == "CEO") {
      return const SizedBox.shrink();
    }
    final items = [
      StatsItem('Daily Target', _formatNumber(userData['dailyTarget'])),
      StatsItem('Previous Net', _formatNumber(userData['netClockedLastly'])),
    ];

    return Row(
      children: items
          .map((item) => Expanded(child: _buildStatCard(context, item)))
          .toList(),
    );
  }

  Widget _buildStatCard(BuildContext context, StatsItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              item.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => changeProfilePhoto(),
            icon: const Icon(Icons.image_search, size: 20),
            label: const Text('Change Photo'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed:() => applyLeave(),
              icon: const Icon(Icons.work_outline, size: 20),
              label: const Text('Apply Leave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          
        const SizedBox(width: 12),

        
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, String key, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.teal),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkInfoCard(BuildContext context, String key, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.trending_up, color: Colors.orange),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, Map<String, dynamic> userData) {
    final statusData = [
      StatusItem('Clocked In', userData['isClockedIn'] ?? false, Icons.access_time),
      StatusItem('Verified', userData['isVerified'] ?? false, Icons.verified),
      StatusItem('Active', userData['isActive'] ?? false, Icons.circle),
      StatusItem('Charging', userData['isCharging'] ?? false, Icons.battery_charging_full),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: statusData.map((status) => _buildStatusChip(status)).toList(),
    );
  }

  Widget _buildStatusChip(StatusItem status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: status.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status.isActive ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, 
               color: status.isActive ? Colors.green : Colors.grey,
               size: 18),
          const SizedBox(width: 8),
          Text(status.title,
               style: TextStyle(
                 color: status.isActive ? Colors.green : Colors.grey,
                 fontWeight: FontWeight.w600,
               )),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(title, 
               style: Theme.of(context).textTheme.titleLarge?.copyWith(
                 fontWeight: FontWeight.w700,
               )),
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
