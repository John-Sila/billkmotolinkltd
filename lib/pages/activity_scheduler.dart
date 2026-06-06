import 'dart:math';

import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ActivityScheduler extends StatefulWidget {
  const ActivityScheduler({super.key});

  @override
  State<ActivityScheduler> createState() => _ActivitySchedulerState();
}

class _ActivitySchedulerState extends State<ActivityScheduler> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  late String _randomHintText;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  static const List<String> _titleHints = [
    "e.g. Team Building Workshop",
    "e.g. Product Launch Event", 
    "e.g. Quarterly Review Meeting",
    "e.g. Client Pitch Presentation",
    "e.g. Annual Company Retreat",
    "e.g. Code Sprint Hackathon",
    "e.g. Welfare Workshop",
    "e.g. Sales Strategy Session",
    "e.g. Leadership Summit",
    "e.g. Customer Feedback Review",
  ];

  String _getRandomHint() {
    final random = Random();
    return _titleHints[random.nextInt(_titleHints.length)];
  }

  
  @override
  void initState() {
    super.initState();
    _randomHintText = _getRandomHint();
    // resetAllUserNotifications();
  }

  
  Future<void> resetAllUserNotifications() async {
    ToastService.info("Resetting all user notifications...");
    final firestore = FirebaseFirestore.instance;

    try {
      final usersSnapshot = await firestore.collection('users').get();
      final batch = firestore.batch();

      for (var userDoc in usersSnapshot.docs) {
        final userRef = userDoc.reference;
        batch.update(userRef, {
          'notifications': {},
          'numberOfNotifications': 0,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error resetting notifications: $e');
    }
  }
  
  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CalendarModal(
        initialDate: _selectedDate ?? DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      // This forces the Analog Dial and hides the toggle button
      initialEntryMode: TimePickerEntryMode.dialOnly, 
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              // Optional: Add styling here
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }
  
  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      if (!mounted) return;

      ToastService.error("Please fill in all fields and select date & time");
      return;
    }

    // --------------------------------------------------------
    // CONFIRMATION DIALOG
    // --------------------------------------------------------
    final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text("Confirm Scheduling"),
            content: const Text(
              "Are you sure you want to schedule this activity?",
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm"),
              ),
            ],
          );
        },
      );

    if (confirmed != true) return;

    // --------------------------------------------------------
    // START SUBMISSION
    // --------------------------------------------------------
    if (!mounted) return;
    setState(() => _isSubmitting = true);

    final eventTitle = _titleController.text.trim();
    final eventDescription = _descriptionController.text.trim();

    final eventDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      // --------------------------------------------------------
      // 1. Create the event document
      // --------------------------------------------------------
      final eventsRef = FirebaseFirestore.instance.collection('events');

      await eventsRef.add({
        'title': eventTitle,
        'description': eventDescription,
        'event_time': Timestamp.fromDate(eventDateTime),
        'created_at': Timestamp.now(),
      });

      // --------------------------------------------------------
      // 2. Push notifications to all users
      // --------------------------------------------------------
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      final now = Timestamp.now();
      final notificationId =
          DateTime.now().millisecondsSinceEpoch.toString();

      final batch = FirebaseFirestore.instance.batch();

      for (var userDoc in usersSnapshot.docs) {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id);

        batch.update(userRef, {
          'notifications.$notificationId': {
            'isRead': false,
            'message': 'We have an oncoming event: $eventTitle',
            'time': now,
          },
          'numberOfNotifications': FieldValue.increment(1),
        });
      }

      await batch.commit();

      // --------------------------------------------------------
      // 3. UI Feedback
      // --------------------------------------------------------
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.schedule_send, color: Colors.white),
              const SizedBox(width: 12),
              Text("Event scheduled successfully"),
            ],
          ),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // --------------------------------------------------------
      // 4. Reset form
      // --------------------------------------------------------
      _titleController.clear();
      _descriptionController.clear();

      setState(() {
        _selectedDate = null;
        _selectedTime = null;
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('Error scheduling event: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Failed: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.schedule, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            const Text(
              "Plan Team Activity",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.withValues(alpha: 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    theme.colorScheme.surface.withValues(alpha: 0.3),
                    theme.colorScheme.surface,
                  ]
                : [
                    Colors.teal.withValues(alpha: 0.05),
                    theme.colorScheme.surface,
                  ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header illustration
                        Container(
                          margin: const EdgeInsets.only(bottom: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.teal.withValues(alpha: 0.1),
                                Colors.orange.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.group_work,
                                size: 64,
                                color: Colors.teal,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Schedule Team Activity",
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                "Plan engaging activities for your team",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Title Field
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor.withValues(alpha: isDark ? 0.3 : 0.1),
                                blurRadius: isDark ? 12 : 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Activity Title",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  hintText: _randomHintText,
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.teal,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                style: theme.textTheme.titleMedium,
                              ),
                            
                            
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Description Field
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor.withValues(alpha: isDark ? 0.3 : 0.1),
                                blurRadius: isDark ? 12 : 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Description",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _descriptionController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: "What will the team be doing?",
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.teal,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Date Picker
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor
                                      .withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.1),
                                  blurRadius: Theme.of(context).brightness == Brightness.dark ? 12 : 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.calendar_month,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Select Date",
                                        style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                                          color: colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _selectedDate == null
                                            ? "Choose a date"
                                            : DateFormat('d MMM y').format(_selectedDate!),
                                        style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),
                        ),
                                                
                        const SizedBox(height: 16),

                        // Time Picker
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withValues(alpha: isDark ? 0.3 : 0.1),
                                  blurRadius: isDark ? 12 : 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.access_time_filled,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Select Time",
                                        style: (theme.textTheme.bodyMedium ??
                                                const TextStyle()).copyWith(
                                          color: colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _selectedTime == null
                                            ? "Choose a time"
                                            : _selectedTime!.format(context),
                                        style: (theme.textTheme.titleMedium ??
                                                const TextStyle()).copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        Container(
                            margin: const EdgeInsets.only(top: 32),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: Colors.teal.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),

                              onPressed: _isSubmitting ? null : _submit,

                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSubmitting)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.6,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.send, size: 20, color: Colors.teal),
                                    ),

                                  const SizedBox(width: 12),

                                  Text(
                                    _isSubmitting ? "Posting..." : "Schedule Team Activity",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                      
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 180)),
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



