import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class Requirements extends StatefulWidget {
  const Requirements({super.key});

  @override
  State<Requirements> createState() => _RequirementsState();
}

class _RequirementsState extends State<Requirements> {
  String? selectedUserId;
  DateTime? selectedDate;
  List<Map<String, dynamic>> users = [];
  final TextEditingController previousBalanceController = TextEditingController();
  bool isPosting = false;
  bool isAutoFetching = false;

  @override
  void initState() {
    super.initState();
    fetchUsers();
    cleanOldNotifications();
    cleanupOldRequirements();
    previousBalanceController.addListener(() {
      setState(() {}); // rebuild to update button state
    });
  }

  @override
  void dispose() {
    previousBalanceController.dispose();
    super.dispose();
  }

  Future<void> _autoFetchPreviousBalance() async {
    if (selectedUserId == null || selectedDate == null) return;

    setState(() => isAutoFetching = true);

    try {
      // Calculate previous date (1 day before selected date)
      final prevDate = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day - 1);
      final prevDateString = DateFormat('dd MMM yyyy').format(prevDate); // "02 Aug 2025"

      // Get user document directly using UID as document ID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(selectedUserId)
          .get();

      if (userDoc.exists) {
        final clockoutsMap = userDoc.data()?['clockouts'] as Map<String, dynamic>?;
        
        if (clockoutsMap != null) {
          final prevDayData = clockoutsMap[prevDateString] as Map<String, dynamic>?;
          final inAppBalance = prevDayData?['todaysInAppBalance']?.toString() ?? '0';
          
          previousBalanceController.text = inAppBalance;
        } else {
          previousBalanceController.text = '0';
        }
      } else {
        previousBalanceController.text = '0';
      }
    } catch (e) {
      previousBalanceController.text = '0';
    } finally {
      setState(() => isAutoFetching = false);
    }
  }

  Future<void> fetchUsers() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('users').get();

    final fetchedUsers = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'name': data['userName'] ?? 'Unknown',
        'userRank': data['userRank'] ?? '',
      };
    }).toList();

    setState(() {
      users = fetchedUsers;
    });
  }

  Future<void> cleanOldNotifications() async {
    final firestore = FirebaseFirestore.instance;
    final usersCollection = firestore.collection('users');

    final now = DateTime.now();
    final threshold = now.subtract(const Duration(days: 7));

    final usersSnapshot = await usersCollection.get();

    for (final userDoc in usersSnapshot.docs) {
      final data = userDoc.data();

      if (!data.containsKey('notifications')) continue;
      if (data['notifications'] is! Map) continue;

      final Map<String, dynamic> notifications =
          Map<String, dynamic>.from(data['notifications']);

      final updates = <String, dynamic>{};

      notifications.forEach((key, value) {
        if (value is Map && value.containsKey('time')) {
          final ts = value['time'];
          if (ts is Timestamp) {
            final dt = ts.toDate();
            if (dt.isBefore(threshold)) {
              updates['notifications.$key'] = FieldValue.delete();
            }
          }
        }
      });

      if (updates.isNotEmpty) {
        await userDoc.reference.update(updates);
      }
    }
  }

  Future<void> cleanupOldRequirements() async {
    final firestore = FirebaseFirestore.instance;
    try {
      // Get all users
      final usersSnapshot = await firestore.collection('users').get();
      
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final requirements = userData['requirements'] as Map<String, dynamic>?;
        
        if (requirements != null) {
          final requirementsToDelete = <String>[];
          
          // Check each requirement
          requirements.forEach((reqId, reqData) {
            final dateStr = reqData['date'] as String?;
            if (dateStr != null) {
              final reqDate = _parseDate(dateStr);
              if (reqDate != null) {
                // If requirement is 1 month or older, mark for deletion
                final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
                if (reqDate.isBefore(oneMonthAgo)) {
                  requirementsToDelete.add(reqId);
                }
              }
            }
          });
          
          // Delete old requirements if any found
          if (requirementsToDelete.isNotEmpty) {
            final updates = <String, dynamic>{};
            for (var reqId in requirementsToDelete) {
              updates['requirements.$reqId'] = FieldValue.delete();
            }
            
            await userDoc.reference.update(updates);
            ToastService.info('Cleaned up ${requirementsToDelete.length} old requirements for ${userData['userName'] ?? userDoc.id}');
          }
        }
      }
      
      debugPrint('Cleanup completed successfully');
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  // Helper to parse "dd MMM yyyy" date strings (e.g., "08 Oct 2025")
  DateTime? _parseDate(String dateStr) {
    try {
      return DateFormat('dd MMM yyyy', 'en_US').parse(dateStr);
    } catch (e) {
      debugPrint('Failed to parse date: $dateStr');
      return null;
    }
  }

  Future<void> handleRequire() async {
    if (selectedUserId == null || selectedDate == null) return;

    final firestore = FirebaseFirestore.instance;
    final previousBalance = double.tryParse(previousBalanceController.text) ?? 0;

    final date = selectedDate!;
    final dayOfWeek = DateFormat('EEEE').format(date); // full day name
    final formattedDate = DateFormat('dd MMM yyyy').format(date); // "08 Oct 2025"

    final monday = date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final weekRange =
        'Week ${weekNumber(date)} (${DateFormat('dd MMM yyyy').format(monday)} to ${DateFormat('dd MMM yyyy').format(sunday)})';

    final appBalance = previousBalance;

    final userDocRef = firestore.collection('users').doc(selectedUserId);
    final requirementId = DateTime.now().millisecondsSinceEpoch.toString();
    final requirementEntry = {
      'appBalance': appBalance,
      'date': formattedDate,
      'dayOfWeek': dayOfWeek,
      'weekRange': weekRange,
    };

    final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
    final notificationEntry = {
      'message': 'You have been required to correct $formattedDate.',
      'time': Timestamp.now(),
      'isRead': false,
    };

    try {
      // 1. Append requirement
      await userDocRef.update({
        'requirements.$requirementId': requirementEntry,
        'notifications.$notificationId': notificationEntry,
        'numberOfNotifications': FieldValue.increment(1),
      });

      ToastService.success("Requirement created successfully!");
      previousBalanceController.clear();
    } catch (e) {
      ToastService.error("Failed to create requirement. Please try again.");
      debugPrint('handleRequire error: $e');
    }
  }

  // Helper function to get ISO week number
  int weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysPassed = date.difference(firstDayOfYear).inDays;
    return ((daysPassed + firstDayOfYear.weekday) / 7).ceil();
  }

  bool get isRequireEnabled {
    return selectedUserId != null &&
        selectedDate != null &&
        previousBalanceController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              const Text(
                'Create Requirement',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select user, date and balance to create requirement',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // User dropdown
              SizedBox(
                width: double.infinity,
                child: _buildDropdownField<String>(
                  value: selectedUserId,
                  label: 'Select User',
                  hint: 'Choose rider',
                  icon: Icons.person_outline,
                  items: users.map<DropdownMenuItem<String>>((user) {
                    final rank = user['userRank']?.toString() ?? '';
                    final isSelectable = rank == 'Manager' || rank == 'Rider' || rank == 'Systems, IT';

                    return DropdownMenuItem<String>(
                      value: isSelectable ? user['uid'] as String? : null,
                      enabled: isSelectable,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isSelectable)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                rank,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUserId = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Calendar / Date picker
              _buildTextField(
                controller: TextEditingController(
                  text: selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                      : null,
                ),
                hint: 'Select Date',
                label: 'Select Date',
                icon: Icons.calendar_today_outlined,
                readOnly: true,
                onTap: () async {
                  final picked = await showModalBottomSheet<DateTime>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => _CalendarModal(
                      initialDate: selectedDate ?? DateTime.now(),
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Previous App Balance input
              _buildTextField(
                controller: previousBalanceController,
                label: 'Previous App Balance (A)',
                hint: 'Enter previous balance',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),

              // Auto Fetch Previous Balance Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (selectedUserId != null && selectedDate != null && !isAutoFetching)
                      ? () => _autoFetchPreviousBalance()
                      : null,
                  icon: isAutoFetching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  label: Text(
                    isAutoFetching ? 'Fetching...' : 'Auto Fetch Previous',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Require button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isRequireEnabled
                      ? () async {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              final localTheme = Theme.of(dialogContext);
                              final colorScheme = localTheme.colorScheme;
                              
                              return AlertDialog(
                                icon: Icon(
                                  Icons.add_task,
                                  color: colorScheme.primary,
                                  size: 48,
                                ),
                                title: Text(
                                  'Confirm Requirement',
                                  style: localTheme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: Text(
                                  'Are you sure you want to create this requirement?',
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
                                          'Continue',
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

                          if (confirmed != true) return;

                          setState(() => isPosting = true);

                          try {
                            await handleRequire();
                          } finally {
                            setState(() => isPosting = false);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPosting
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                  ),
                  child: isPosting
                      ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.5,
                        ),
                      )
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_task,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Create Requirement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
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
    );
  }

  // Your existing helper methods (add these)
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      obscureText: obscureText,
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
      initialValue: value,
      isExpanded: true,
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
}

class _CalendarModal extends StatefulWidget {
  final DateTime initialDate;

  const _CalendarModal({required this.initialDate});

  @override
  State<_CalendarModal> createState() => _CalendarModalState();
}

class _CalendarModalState extends State<_CalendarModal> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate;
    _focusedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: colors.outline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close bar
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colors.outline.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Date',
                    style: theme.textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),

            // TableCalendar (light/dark friendly)
            TableCalendar<DateTime>(
              firstDay: DateTime(2000),
              lastDay: DateTime.now(),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              headerStyle: HeaderStyle(
                titleTextStyle: theme.textTheme.titleMedium ??
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: colors.onSurface,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurface,
                ),
                formatButtonVisible: false,
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: (theme.textTheme.labelMedium ??
                        const TextStyle()).copyWith(color: colors.onSurface),
                weekendStyle: (theme.textTheme.labelMedium ??
                        const TextStyle()).copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: (theme.textTheme.labelMedium ??
                        const TextStyle()).copyWith(color: colors.onPrimary),
                todayDecoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: (theme.textTheme.labelMedium ??
                        const TextStyle()).copyWith(color: colors.onSurface),
                weekendTextStyle: (theme.textTheme.labelMedium ??
                        const TextStyle()).copyWith(color: colors.onSurface),
                outsideTextStyle: (theme.textTheme.labelMedium ??
                        const TextStyle()).copyWith(
                  color: colors.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              daysOfWeekHeight: 32,
              rowHeight: 48,
            ),
            
            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(_selectedDay);
                },
                child: Text(
                  'Use ${DateFormat('yyyy-MM-dd').format(_selectedDay)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onPrimary,
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

