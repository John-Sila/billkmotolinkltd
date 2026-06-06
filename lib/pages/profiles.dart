import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class Profiles extends StatefulWidget {
  const Profiles({super.key});

  @override
  State<Profiles> createState() => _ProfilesState();
}

class _ProfilesState extends State<Profiles> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('userName')
        .snapshots();
  }

  Future<void> _updateField(String uid, String field, dynamic value) async {
    final now = Timestamp.now();
    final notificationId =
        DateTime.now().millisecondsSinceEpoch.toString();
        
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
        'notifications.$notificationId': {
          'isRead': false,
          'message': 'Your account has been altered by an admin.',
          'time': now,
        },
        "numberOfNotifications": FieldValue.increment(1),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $field: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _settlePendingAmounts() async {
    final theme = Theme.of(context);
    final confirmed = await _showConfirmDialog(
      title: 'Settle All Pending Amounts',
      content: 'This will clear all pending amounts and add them to company income. This action cannot be undone.',
      action: 'Proceed',
    );

    if (!confirmed) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final usersSnapshot = await firestore.collection('users').get();
      
      int totalPending = 0;
      final batch = firestore.batch();

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final pending = _safeNum(data['pendingAmount'], 0).toInt();
        
        if (pending > 0) {
          totalPending += pending;
          batch.update(doc.reference, {'pendingAmount': 0});
        }
      }

      if (totalPending > 0) {
        batch.update(
          firestore.collection('general').doc('general_variables'),
          {'companyIncome': FieldValue.increment(totalPending)},
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No pending amounts to settle.'),
              backgroundColor: theme.colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 12),
                Text('Settlement completed: KSh $totalPending'),
              ],
            ),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement failed: $e'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatKenyanPhone(String phone) {
    if (phone == 'No phone') return phone;

    // Remove all non‑digits
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Normalize to Kenyan E.164-like
    String kenyaDigits;
    if (digits.length == 10 && digits.startsWith('0')) {
      // 0712345678 → 254712345678
      kenyaDigits = '254${digits.substring(1)}';
    } else if (digits.length == 9) {
      // 712345678 → 254712345678
      kenyaDigits = '254$digits';
    } else if (digits.length == 12 && digits.startsWith('254')) {
      kenyaDigits = digits;
    } else {
      return phone; // can't normalize
    }

    // Now format: +254730 234 778
    // Split: 730 (6‑chars group), 234 (3), 778 (3)
    if (kenyaDigits.length == 12) {
      final code = kenyaDigits.substring(0, 6);   // 254730
      final group1 = kenyaDigits.substring(6, 9);  // 234
      final group2 = kenyaDigits.substring(9, 12); // 778
      return '+$code $group1 $group2';
    }

    return phone; // fallback
  }

  // 1. Double-check that this line is added to the top of your _ProfilesState class:
  final Set<String> _expandedUserIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Workforce & Persons',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.account_balance_wallet, size: 18),
              label: const Text('Settle All', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
              onPressed: _settlePendingAmounts,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final visibleUsers = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final rank = _safeToString(data['userRank'], '').toLowerCase();
            return rank != 'ceoo' && rank != 'systems, itt';
          }).toList();

          if (visibleUsers.isEmpty) {
            return _buildNoEligibleUsers(context);
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 32),
            itemCount: visibleUsers.length,
            itemBuilder: (_, index) {
              final doc = visibleUsers[index];
              final uid = doc.id;
              final user = doc.data() as Map<String, dynamic>;
              final isExpanded = _expandedUserIds.contains(uid);

              return _buildUserCard(
                uid, 
                user, 
                theme,
                isExpanded: isExpanded,
                onToggleExpand: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedUserIds.remove(uid);
                    } else {
                      _expandedUserIds.add(uid);
                    }
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  // 2. Updated expandable card builder signature
  Widget _buildUserCard(
    String uid, 
    Map<String, dynamic> user, 
    ThemeData theme, {
    required bool isExpanded,
    required VoidCallback onToggleExpand,
  }) {
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    
    final String userRank = _safeToString(user['userRank'], 'Unknown').trim().toUpperCase();
    final bool isPrivileged = {'CEO', 'SYSTEMS, IT', 'MANAGER'}.contains(userRank);
    final bool isActive = _toBool(user['isActive']);
    
    final String rawPhone = _safeToString(user['phoneNumber'], 'No phone');
    final String formatted = _formatKenyanPhone(rawPhone);

    bool canCall = formatted.isNotEmpty && formatted != "No phone";
    String dialNumber = canCall ? "tel:$formatted" : "";

    final Color nameColor = isActive ? onSurfaceColor : theme.colorScheme.error;

    final List<Color> gradientColors = isPrivileged
        ? [
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
            theme.colorScheme.surfaceContainerHigh,
          ]
        : [
            surfaceColor,
            theme.colorScheme.surfaceContainerHighest,
          ];

    final Color shadowColor = isPrivileged
        ? theme.colorScheme.tertiary.withValues(alpha: 0.15)
        : theme.colorScheme.primary.withValues(alpha: 0.1);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isPrivileged ? 8 : 4,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isPrivileged 
            ? BorderSide(color: theme.colorScheme.tertiary.withValues(alpha: 0.25), width: 1.5)
            : BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4), width: 1),
      ),
      color: surfaceColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggleExpand,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Inactive Warning Banner
                if (!isActive) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 14, color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 6),
                        Text(
                          "INACTIVE ACCOUNT",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Header Data (Always visible)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPrivileged
                            ? theme.colorScheme.tertiary.withValues(alpha: 0.15)
                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isPrivileged ? Icons.verified_user : Icons.person, 
                        color: isPrivileged ? theme.colorScheme.tertiary : theme.colorScheme.primary, 
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _safeToString(user['userName'], 'Unnamed User'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: nameColor,
                                  ),
                                ),
                              ),
                              if (isPrivileged) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "PRO",
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onTertiary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _safeToString(user['userRank'], 'Unknown'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isPrivileged ? theme.colorScheme.tertiary : theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: onSurfaceVariant,
                    ),
                  ],
                ),

                // Animated Transition for expanding body
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.fastOutSlowIn,
                  child: isExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Divider(
                              height: 1, 
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              _safeToString(user['email'], 'No email'),
                              style: theme.textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: canCall
                                  ? () async {
                                      final Uri uri = Uri.parse(dialNumber);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      } else {
                                        ToastService.error("Could not launch dialer");
                                      }
                                    }
                                  : null,
                              child: Text(
                                formatted,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: canCall
                                      ? (isPrivileged ? theme.colorScheme.tertiary : theme.colorScheme.primary)
                                      : onSurfaceVariant,
                                  fontWeight: canCall ? FontWeight.w600 : null,
                                ),
                              ),
                            ),

                            if (!isPrivileged) ...[
                              const SizedBox(height: 20),
                              _EditableNumberField(
                                label: 'Daily Target',
                                value: _safeNum(user['dailyTarget'], 0).toInt(),
                                icon: Icons.trending_up,
                                color: theme.colorScheme.primary,
                                theme: theme,
                                onUpdate: (v) => _updateField(uid, 'dailyTarget', v),
                              ),
                              const SizedBox(height: 12),
                              _EditableNumberField(
                                label: 'Sunday Target',
                                value: _safeNum(user['sundayTarget'], 0).toInt(),
                                icon: Icons.calendar_today,
                                color: theme.colorScheme.tertiary,
                                theme: theme,
                                onUpdate: (v) => _updateField(uid, 'sundayTarget', v),
                              ),
                              const SizedBox(height: 12),
                              _PendingAmountField(
                                label: 'Pending Amount',
                                value: _safeNum(user['pendingAmount'], 0).toInt(),
                                icon: Icons.payment,
                                color: theme.colorScheme.secondary,
                                theme: theme,
                                uid: uid,
                                onValueUpdated: (v) => {},
                              ),
                              const SizedBox(height: 12),
                              _EditableNumberField(
                                label: 'In-App Balance',
                                value: _safeNum(user['currentInAppBalance'], 0).toInt(),
                                icon: Icons.account_balance_wallet,
                                color: Colors.green,
                                theme: theme,
                                onUpdate: (v) => _updateField(uid, 'currentInAppBalance', v),
                              ),
                              const SizedBox(height: 20),
                              Column(
                                children: [
                                  _EditableBoolField(
                                    label: 'Active',
                                    value: isActive,
                                    icon: Icons.power_settings_new,
                                    color: Colors.green,
                                    theme: theme,
                                    onUpdate: (v) => _updateField(uid, 'isActive', v),
                                  ),
                                  const SizedBox(height: 12),
                                  _EditableBoolField(
                                    label: 'Verified',
                                    value: _toBool(user['isVerified']),
                                    icon: Icons.verified,
                                    color: theme.colorScheme.primary,
                                    theme: theme,
                                    onUpdate: (v) => _updateField(uid, 'isVerified', v),
                                  ),
                                  const SizedBox(height: 12),
                                  _EditableBoolField(
                                    label: 'Clocked In',
                                    value: _toBool(user['isClockedIn']),
                                    icon: Icons.login,
                                    color: theme.colorScheme.primary,
                                    theme: theme,
                                    onUpdate: (v) => {},
                                  ),
                                  const SizedBox(height: 12),
                                  _EditableBoolField(
                                    label: 'Working on Sunday',
                                    value: _toBool(user['isWorkingOnSunday']),
                                    icon: Icons.calendar_month,
                                    color: theme.colorScheme.tertiary,
                                    theme: theme,
                                    onUpdate: (v) => _updateField(uid, 'isWorkingOnSunday', v),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'No users found',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users will appear here when added',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEligibleUsers(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'No eligible users',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Only non-admin users are shown',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }


  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String action,
  }) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, 
                 color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Text(title, 
                 style: theme.textTheme.titleMedium?.copyWith(
                   fontWeight: FontWeight.w600,
                 )),
          ],
        ),
        content: Text(content, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ?? false;
  }

}

class _PendingAmountField extends StatefulWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  final String uid; // Firestore document ID of user
  final Function(int) onValueUpdated; // optional callback if you need it higher up

  const _PendingAmountField({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
    required this.uid,
    required this.onValueUpdated,
  });

  @override
  State<_PendingAmountField> createState() => _PendingAmountFieldState();
}

class _PendingAmountFieldState extends State<_PendingAmountField> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant _PendingAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  Future<void> _showApproveDialog() async {
    final controller = TextEditingController(text: _value.toString());

    final int? newValue = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.label, style: widget.theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter the amount you want to approve:",
              style: widget.theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: widget.theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.theme.colorScheme.primary),
                ),
                hintText: "0",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: widget.theme.textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () {
              final input = int.tryParse(controller.text.trim());
              if (input == null || input <= 0) {
                ToastService.error("Enter a valid positive number to approve");
                return;
              }

              // Ensure we don't go below zero
              final int newPending = (_value - input).clamp(0, _value);

              Navigator.pop(context, newPending);
            },
            child: Text('Approve'),
          ),
        ],
      ),
    );

    if (newValue != null && newValue != _value) {
      // Update Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .update({
          'pendingAmount': newValue,
        });

        // Update UI
        setState(() {
          _value = newValue;
        });

        // Propagate to parent if needed
        widget.onValueUpdated(newValue);
      } catch (e) {
        ToastService.error("Failed to update pending amount: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showApproveDialog(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      color: widget.theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _value.toString(),
                    style: widget.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: widget.theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: widget.theme.colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// Updated Editable Widgets with Theme Support
class _EditableNumberField extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  final Function(int) onUpdate;

  const _EditableNumberField({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, 
                       style: theme.textTheme.bodyMedium?.copyWith(
                         color: theme.colorScheme.onSurfaceVariant,
                         fontWeight: FontWeight.w500,
                       )),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, 
                 color: theme.colorScheme.onSurfaceVariant, 
                 size: 20),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: value.toString());
    showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(label, style: theme.textTheme.titleMedium),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: theme.textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? value;
              Navigator.pop(context, newValue);
            },
            child: Text('Update'),
          ),
        ],
      ),
    ).then((newValue) {
      if (newValue != null && newValue != value) {
        onUpdate(newValue);
      }
    });
  }
}

class _EditableBoolField extends StatelessWidget {
  final String label;
  final bool value;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  final Function(bool) onUpdate;

  const _EditableBoolField({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onUpdate(!value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value 
            ? color.withValues(alpha: 0.1) 
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value 
              ? color.withValues(alpha: 0.3) 
              : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: value ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, 
                       style: theme.textTheme.bodyMedium?.copyWith(
                         color: theme.colorScheme.onSurfaceVariant,
                         fontWeight: FontWeight.w500,
                       )),
                  Text(
                    value ? 'True' : 'False',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value ? Colors.green.shade700 : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              value ? Icons.toggle_on : Icons.toggle_off,
              color: value ? Colors.green : theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

// Safe conversion helpers (unchanged)
String _safeToString(dynamic value, [String defaultValue = '']) {
  return value?.toString() ?? defaultValue;
}

num _safeNum(dynamic value, [num defaultValue = 0]) {
  if (value == null) return defaultValue;
  return value is num ? value : num.tryParse(value.toString()) ?? defaultValue;
}

bool _toBool(dynamic value) {
  if (value == null) return false;
  return value is bool ? value : value.toString().toLowerCase() == 'true';
}
