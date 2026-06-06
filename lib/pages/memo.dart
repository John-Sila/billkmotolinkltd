// create_memo.dart - Manual entry only
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateMemo extends StatefulWidget {
  const CreateMemo({super.key});

  @override
  State<CreateMemo> createState() => _CreateMemoState();
}

class _CreateMemoState extends State<CreateMemo> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  late final TextEditingController _expiresAtController = TextEditingController(text: '30 minutes');

  bool _isPosting = false;
  final FocusNode _bodyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bodyFocus.requestFocus();
    });
    // NO AUTO-FILL - all fields empty
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _toController.dispose();
    _fromController.dispose();
    _departmentController.dispose();
    _bodyFocus.dispose();
    _expiresAtController.dispose();
    super.dispose();
  }

  void _postMemo() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final to = _toController.text.trim();
    final from = _fromController.text.trim();
    final department = _departmentController.text.trim();

    if (title.isEmpty || body.isEmpty || to.isEmpty || from.isEmpty) {
      _showSnackBar('Please fill all required fields (*)', Colors.orange);
      return;
    }

    // SHOW THEMED CONFIRMATION DIALOG
    final confirmed = await _showConfirmationDialog(
      title: title,
      to: to,
      from: from,
      department: department.isEmpty ? 'All Departments' : department,
    );

    if (!confirmed) return;

    setState(() => _isPosting = true);
    HapticFeedback.mediumImpact();

    try {
      await FirebaseFirestore.instance
          .collection('memo')
          .doc('latest')
          .set({
        'title': title,
        'body': body,
        'to': to,
        'from': from,
        'department': department,
        'postedAt': Timestamp.now(),
        'readBy': <String>[],
        'expiresAt': Timestamp.fromDate(_selectedExpiresAt ?? DateTime.now().add(const Duration(minutes: 30))),
      });

      // Clear only input fields
      _titleController.clear();
      _bodyController.clear();
      _toController.clear();
      _fromController.clear();
      _departmentController.clear();
      
      _showSnackBar('Memo posted successfully!', Colors.green);
      _bodyFocus.requestFocus();
    } catch (e) {
      _showSnackBar('Failed to post memo: $e', Colors.red);
    } finally {
      setState(() => _isPosting = false);
    }
  }

  // NEW: Themed Confirmation Dialog
  Future<bool> _showConfirmationDialog({
    required String title,
    required String to,
    required String from,
    required String department,
  }) async {
    final theme = Theme.of(context);
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(top: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),

              // Preview Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('To: ', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                        Expanded(child: Text(to, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('From: ', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                        Expanded(child: Text(from, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                      ],
                    ),
                    if (department.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Dept: ', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                          Expanded(child: Text(department, style: theme.textTheme.bodyLarge)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        icon: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                        label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 20),
                        label: const Text('Post Memo', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
  }

  DateTime? _selectedExpiresAt;

  Future<void> _selectExpiresAt(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(minutes: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(picked),
      );
      
      if (time != null) {
        final finalDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );
        
        setState(() {
          _selectedExpiresAt = finalDateTime;
          final diff = finalDateTime.difference(now);
          final minutes = diff.inMinutes;
          _expiresAtController.text = '$minutes minutes';
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final surfaceColor = isDark 
        ? theme.colorScheme.surface.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.9);
    final surfaceElevation = isDark 
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary.withValues(alpha: 0.12), theme.colorScheme.primary.withValues(alpha: 0.06)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 12))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.6)]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.note_alt_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('New Announcement', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                                Text('Send memo to your team', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title Field
                    _buildInputField(
                      controller: _titleController,
                      label: 'Title *',
                      hint: 'Enter memo title',
                      icon: Icons.title_rounded,
                      surfaceColor: surfaceColor,
                      surfaceElevation: surfaceElevation,
                    ),

                    const SizedBox(height: 20),

                    // From + User (side by side)
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _fromController,
                            label: 'From *',
                            hint: 'Your full name',
                            icon: Icons.person_rounded,
                            surfaceColor: surfaceColor,
                            surfaceElevation: surfaceElevation,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Department + To (side by side)
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _departmentController,
                            label: 'Department',
                            hint: 'IT, HR, Operations...',
                            icon: Icons.business_rounded,
                            surfaceColor: surfaceColor,
                            surfaceElevation: surfaceElevation,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInputField(
                            controller: _toController,
                            label: 'To *',
                            hint: 'All Staff, Riders, Managers...',
                            icon: Icons.people_alt_rounded,
                            surfaceColor: surfaceColor,
                            surfaceElevation: surfaceElevation,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // After Department + To Row, before Message Field
                    const SizedBox(height: 20),

                    // ✅ NEW EXPIRES AT FIELD
                    _buildExpiresAtField(
                      controller: _expiresAtController,
                      onTap: () => _selectExpiresAt(context),
                      surfaceColor: surfaceColor,
                      surfaceElevation: surfaceElevation,
                    ),
                    const SizedBox(height: 24),

                    // Message Field
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Icon(Icons.message_rounded, size: 20, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Text('Message *', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        boxShadow: [BoxShadow(color: surfaceElevation, blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: TextFormField(
                        controller: _bodyController,
                        focusNode: _bodyFocus,
                        maxLines: 15,
                        maxLength: 1000,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Write your memo here...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(24),
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isPosting ? 70 : 65,
              child: ElevatedButton(
                onPressed: _isPosting ? null : _postMemo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 12,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isPosting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Posting...', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      )
                    : const Text('Post Memo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
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
    required Color surfaceColor,
    required Color surfaceElevation,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: surfaceElevation, blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: TextFormField(
            controller: controller,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiresAtField({
    required TextEditingController controller,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color surfaceElevation,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.red.withOpacity(0.6)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Expires *', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.red[700])),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: surfaceElevation, blurRadius: 24, offset: const Offset(0, 8))],
              border: Border.all(color: Colors.red.withOpacity(0.2), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 20, color: Colors.red[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? 'Select expiration time' : controller.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: controller.text.isEmpty 
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: theme.colorScheme.onSurface.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

}
