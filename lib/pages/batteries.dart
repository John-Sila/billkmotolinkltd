import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Batteries extends StatefulWidget {
  final String uid;

  const Batteries({super.key, required this.uid});

  @override
  State<Batteries> createState() => _BatteriesState();
}

class _BatteriesState extends State<Batteries> {
  String? currentUserName;
  String? userRank;
  Map<String, dynamic> batteries = {};
  final expanded = <String>{};
  bool isLoading = true;
  Set<String> busy = {};


  @override
  void initState() {
    super.initState();
    _loadData();
    // deleteOldTracesForAllBatteries();
  }

  Future<void> _loadData() async {
    await _fetchUserName();
    await _fetchBatteries();
  }

  Future<void> _fetchUserName() async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    setState(() {
      currentUserName = snap.data()?['userName'] ?? '';
      userRank = snap.data()?['userRank'] ?? '';
    });
  }

  Future<void> deleteOldTracesForAllBatteries({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batteriesSnapshot = await firestore.collection('batteries').get();

    for (final doc in batteriesSnapshot.docs) {
      await deleteOldTracesForBattery(
        batteryId: doc.id,
        maxAge: maxAge,
      );
    }
  }

  Future<void> deleteOldTracesForBattery({
    required String batteryId,
    Duration maxAge = const Duration(days: 7),
  }) async {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('batteries').doc(batteryId);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final traces = data['traces'] as Map<String, dynamic>?;

      if (traces == null || traces.isEmpty) return;

      final now = DateTime.now();
      final cutoff = now.subtract(maxAge);

      final Map<String, dynamic> updates = {};

      traces.forEach((traceKey, traceValue) {
        if (traceValue is Map<String, dynamic>) {
          final Timestamp? ts = traceValue['dateEdited'] as Timestamp?;
          if (ts != null) {
            final dateEdited = ts.toDate();
            if (dateEdited.isBefore(cutoff)) {
              // mark this trace for deletion
              updates['traces.$traceKey'] = FieldValue.delete();
            }
          }
        }
      });

      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    } catch (e) {
      // handle/log error as needed
    }
  }

  Future<void> _fetchBatteries() async {
    setState(() => isLoading = true);

    final snap = await FirebaseFirestore.instance.collection('batteries').get();
    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();

    final sortedEntries = snap.docs.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a['batteryName']?.split('-').last ?? '0') ?? 0;
        final bNum = int.tryParse(b['batteryName']?.split('-').last ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });

    final Map<String, dynamic> tempBatteries = {};

    for (var doc in sortedEntries) {
      final data = doc.data();
      tempBatteries[doc.id] = data;

      final isBooked = data['isBooked'] ?? false;
      final bookTime = data['bookTime'];

      if (isBooked && bookTime != null) {
        DateTime bookDateTime;
        if (bookTime is Timestamp) {
          bookDateTime = bookTime.toDate();
        } else if (bookTime is DateTime) {
          bookDateTime = bookTime;
        } else {
          continue;
        }

        if (now.difference(bookDateTime).inMinutes >= 60) {
          // mark as unbooked
          batch.update(doc.reference, {'isBooked': false});
          tempBatteries[doc.id]['isBooked'] = false;
        }
      }
    }

    await batch.commit();

    setState(() {
      batteries = tempBatteries;
      isLoading = false;
    });
  }

  String formatTimeAgo(Timestamp? ts) {
    if (ts == null) return "N/A";

    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return "Just now";
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    final buffer = StringBuffer();

    if (hours > 0) {buffer.write("${hours}h ${minutes}m");}
    else if (minutes > 0) {buffer.write("${minutes}m");}
    else if (seconds > 0) {buffer.write("${seconds}s");}

    return "${buffer.toString().trim()} ago";
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (currentUserName == null || isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.teal,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading batteries...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (batteries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_unknown_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No batteries available',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    final sortedBatteries = batteries.entries.toList()
      ..sort((a, b) {
        final nameA = a.value['batteryName'] ?? '';
        final nameB = b.value['batteryName'] ?? '';
        final regex = RegExp(r'\d+');
        final numA = int.tryParse(regex.firstMatch(nameA)?.group(0) ?? '0') ?? 0;
        final numB = int.tryParse(regex.firstMatch(nameB)?.group(0) ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sortedBatteries.length,
      itemBuilder: (context, index) {
        final entry = sortedBatteries[index];
        final id = entry.key;
        final data = entry.value;

        final batteryName = data['batteryName'] ?? 'Unknown';
        final assignedRider = data['assignedRider'] ?? 'None';
        final isBooked = data['isBooked'] ?? false;
        final bookedBy = data['bookedBy'] ?? '';

        // Status derivation
        final bool isAssignedToMe = assignedRider == currentUserName;
        final bool isAssignedToOther = assignedRider != 'None' && !isAssignedToMe;
        final bool isAvailable = !isBooked && assignedRider == 'None';
        final bool bookedByMe = isBooked && bookedBy == currentUserName;

        // Status palette
        final Color statusColor;
        final Color statusBg;
        final String statusLabel;
        final IconData statusIcon;

        if (isBooked) {
          statusColor = const Color(0xFF3B82F6);
          statusBg = const Color(0xFFEFF6FF);
          statusLabel = bookedByMe ? 'Booked by me' : 'Booked by $bookedBy';
          statusIcon = Icons.lock_clock_rounded;
        } else if (isAssignedToMe) {
          statusColor = const Color(0xFF10B981);
          statusBg = const Color(0xFFECFDF5);
          statusLabel = 'Assigned to me';
          statusIcon = Icons.verified_rounded;
        } else if (isAssignedToOther) {
          statusColor = const Color(0xFFEF4444);
          statusBg = const Color(0xFFFEF2F2);
          statusLabel = 'Assigned to $assignedRider';
          statusIcon = Icons.person_off_rounded;
        } else {
          statusColor = const Color(0xFF14B8A6);
          statusBg = isDark ? const Color(0xFF0F2924) : const Color(0xFFF0FDFA);
          statusLabel = 'Available';
          statusIcon = Icons.battery_charging_full_rounded;
        }

        if (isDark) {
          // soften backgrounds in dark mode
        }

        final isOpen = expanded.contains(id);
        final isBusy = busy.contains(id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOpen
                    ? statusColor.withValues(alpha: 0.5)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.07)),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isOpen
                      ? statusColor.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: isOpen ? 20 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: isBusy
                      ? null
                      : () => setState(() {
                            isOpen ? expanded.remove(id) : expanded.add(id);
                          }),
                  splashColor: statusColor.withValues(alpha: 0.08),
                  highlightColor: statusColor.withValues(alpha: 0.04),
                  child: Column(
                    children: [
                      // ── Header row ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Row(
                          children: [
                            // Status dot + icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(statusIcon, color: statusColor, size: 22),
                            ),
                            const SizedBox(width: 12),

                            // Name + status label
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    batteryName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Actions
                            if (isBusy)
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: statusColor,
                                ),
                              )
                            else ...[
                              // Admin drop
                              if ((userRank == 'Manager' ||
                                      userRank == 'CEO' ||
                                      userRank == 'Systems, IT') &&
                                  assignedRider != 'None')
                                _actionIcon(
                                  icon: Icons.person_remove_rounded,
                                  color: Colors.deepOrange,
                                  tooltip: 'Admin Drop',
                                  onTap: () => _showAdminDropBatteryDialog(context, id, batteryName),
                                ),

                              // Book
                              if (isAvailable)
                                _actionIcon(
                                  icon: Icons.add_circle_rounded,
                                  color: Colors.teal,
                                  tooltip: 'Book battery',
                                  onTap: () => _handleBook(context, id, batteryName),
                                ),

                              // Unbook
                              if (bookedByMe)
                                _actionIcon(
                                  icon: Icons.cancel_rounded,
                                  color: Colors.red,
                                  tooltip: 'Unbook',
                                  onTap: () => _handleUnbook(context, id, batteryName),
                                ),

                              // Expand chevron
                              AnimatedRotation(
                                turns: isOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 250),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 22,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ── Expanded details ─────────────────────────────
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _chip(
                                    icon: Icons.location_on_rounded,
                                    label: data['batteryLocation'] ?? 'N/A',
                                    color: Colors.teal,
                                    isDark: isDark,
                                  ),
                                  _chip(
                                    icon: Icons.pedal_bike_rounded,
                                    label: data['assignedBike'] ?? 'N/A',
                                    color: Colors.indigo,
                                    isDark: isDark,
                                  ),
                                  _chip(
                                    icon: Icons.qr_code_rounded,
                                    label: data['qr_code'] != null
                                        ? '···${data['qr_code'].toString().substring(data['qr_code'].toString().length - 5)}'
                                        : 'N/A',
                                    color: Colors.purple,
                                    isDark: isDark,
                                  ),
                                  _chip(
                                    icon: Icons.access_time_rounded,
                                    label: formatTimeAgo(data['offTime']),
                                    color: Colors.orange,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        crossFadeState:
                            isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? color.withValues(alpha: 0.9) : color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBook(BuildContext context, String id, String batteryName) async {
    final localTheme = Theme.of(context);
    final colorScheme = localTheme.colorScheme;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.add_box,
          color: colorScheme.primary,
          size: 48,
        ),
        title: Text(
          'Confirm Booking',
          style: localTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Book $batteryName? This will freeze it for 1 hour.',
          style: localTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
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
              backgroundColor: colorScheme.primary,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
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
                  'Book',
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
      ),
    );
    
    if (!(confirm ?? false)) return;

    setState(() => busy.add(id));
    final now = Timestamp.now();
    await FirebaseFirestore.instance.collection('batteries').doc(id).update({
      'isBooked': true,
      'bookedBy': currentUserName,
      'bookTime': now,
    });
    setState(() {
      batteries[id]?['isBooked'] = true;
      batteries[id]?['bookedBy'] = currentUserName;
      batteries[id]?['bookTime'] = now;
      busy.remove(id);
    });
    Fluttertoast.showToast(msg: '$batteryName successfully booked.');
  }

  Future<void> _handleUnbook(BuildContext context, String id, String batteryName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Drop'),
        content: Text('Unbook $batteryName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unbook'),
          ),
        ],
      ),
    );
    if (!(confirm ?? false)) return;

    setState(() => busy.add(id));
    final now = Timestamp.now();
    await FirebaseFirestore.instance.collection('batteries').doc(id).update({
      'isBooked': false,
      'bookedBy': 'None',
      'bookTime': now,
    });
    setState(() {
      batteries[id]?['isBooked'] = false;
      batteries[id]?['bookedBy'] = 'None';
      batteries[id]?['bookTime'] = now;
      busy.remove(id);
    });
    Fluttertoast.showToast(msg: '$batteryName successfully dropped.');
    _fetchBatteries();
  }

  void _showAdminDropBatteryDialog(BuildContext context, String id, String batteryName) {
    final localTheme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.battery_full,
            color: localTheme.colorScheme.error,
            size: 48,
          ),
          title: Text(
            'Admin Drop Battery',
            style: localTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to completely unassign and return',
                style: localTheme.textTheme.bodyMedium?.copyWith(
                  color: localTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                batteryName,
                style: localTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: localTheme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'to the Warehouse?',
                style: localTheme.textTheme.bodyMedium?.copyWith(
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
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: localTheme.colorScheme.error,
                backgroundColor: localTheme.colorScheme.errorContainer.withOpacity(0.1),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                setState(() => busy.add(id));

                try {
                  final now = Timestamp.now();
                  
                  await FirebaseFirestore.instance
                      .collection('batteries')
                      .doc(id)
                      .update({
                    'assignedRider': "None",
                    'assignedBike': "None",
                    'confirmedStatus': false,
                    'storeAssignedRider': "None",
                    'batteryLocation': "Warehouse",
                    'offTime': now,
                    'isBooked': false,
                    'bookedBy': "None",
                    'bookTime': now,
                  });

                  setState(() {
                    batteries[id]?['assignedRider'] = "None";
                    batteries[id]?['assignedBike'] = "None";
                    batteries[id]?['confirmedStatus'] = false;
                    batteries[id]?['storeAssignedRider'] = "None";
                    batteries[id]?['batteryLocation'] = "Warehouse";
                    batteries[id]?['offTime'] = now;
                    batteries[id]?['isBooked'] = false;
                    batteries[id]?['bookedBy'] = "None";
                    batteries[id]?['bookTime'] = now;
                    busy.remove(id);
                  });

                  Fluttertoast.showToast(msg: "$batteryName successfully returned to Warehouse.");
                  
                  _fetchBatteries();

                } catch (e) {
                  setState(() => busy.remove(id));
                  Fluttertoast.showToast(msg: "Error dropping battery: $e");
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
                    'Confirm Drop',
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


}
