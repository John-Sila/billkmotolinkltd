import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AddToCalendar extends StatefulWidget {
  const AddToCalendar({super.key});

  @override
  State<AddToCalendar> createState() => _AddToCalendarState();
}

class _AddToCalendarState extends State<AddToCalendar> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()), // ✅ Current time
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        DateTime.now().add(const Duration(hours: 1)),
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endTime = picked);
  }


  void _addToCalendar() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      Fluttertoast.showToast(
        msg: "Error: Please all fields!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Start Time!')),
      );
      return;
    }

    if (_endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select End Time!')),
      );
      return;
    }

    if (_startTime!.isAfter(_endTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time!')),
      );
      return;
    }

    final startDate = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _startTime?.hour ?? 9, _startTime?.minute ?? 0,
    );
    final endDate = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _endTime?.hour ?? 10, _endTime?.minute ?? 0,
    );


    await FirebaseFirestore.instance.collection('companyEvents').add({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'location': _locationController.text,
      'startDate': startDate,
      'endDate': endDate,
      'creatorUid': FirebaseAuth.instance.currentUser!.uid,
      'creatorEmail': FirebaseAuth.instance.currentUser!.email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final event = Event(
      title: _titleController.text,
      description: _descriptionController.text,
      location: _locationController.text,
      startDate: startDate,
      endDate: endDate,
    );
    Add2Calendar.addEvent2Cal(event);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event added to company calendar!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor.withValues(alpha: 0.9),
                        theme.primaryColor.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: isDark ? 0.4 : 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Schedule Company Event',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add important events to your calendar',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Title Field
                _buildInputField(
                  controller: _titleController,
                  label: 'Event Title *',
                  hint: 'Team Meeting',
                  icon: Icons.title,
                  theme: theme,
                  isDark: isDark,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // Description
                _buildInputField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Agenda and details...',
                  icon: Icons.description,
                  theme: theme,
                  isDark: isDark,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                // Location
                _buildInputField(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'Conference Room A',
                  icon: Icons.location_on,
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Date Picker
                _buildDateTimeField(
                  label: 'Date',
                  value: _selectedDate,
                  onTap: _selectDate,
                  icon: Icons.calendar_today,
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Time Picker Row
                Row(
                  children: [
                    Expanded(child: _buildDateTimeField(
                      label: 'Start Time',
                      value: _startTime,
                      onTap: _selectStartTime,
                      icon: Icons.access_time,
                      theme: theme,
                      isDark: isDark,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDateTimeField(
                      label: 'End Time',
                      value: _endTime,
                      onTap: _selectEndTime,
                      icon: Icons.access_time_filled,
                      theme: theme,
                      isDark: isDark,
                    )),
                  ],
                ),
                const SizedBox(height: 32),

                // Add Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _addToCalendar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: theme.primaryColor.withValues(alpha: 0.4),
                    ),
                    child: const Text(
                      'Add to Calendar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: theme.primaryColor),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required dynamic value,
    required VoidCallback onTap,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: theme.primaryColor),
            suffixIcon: Icon(Icons.arrow_drop_down, 
              color: isDark ? Colors.white70 : Colors.grey),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.primaryColor, width: 2),
            ),
          ),
          controller: TextEditingController(
            text: value == null 
              ? 'Select ${label.toLowerCase()}'
              : (value is DateTime 
                ? '${value.day}/${value.month}/${value.year}'
                : (value as TimeOfDay).format(context)),
          ),
        ),
      ),
    );
  }



}
