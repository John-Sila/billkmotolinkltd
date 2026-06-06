import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreatePoll extends StatefulWidget {
  const CreatePoll({super.key});

  @override
  State<CreatePoll> createState() => _CreatePollState();
}

class _CreatePollState extends State<CreatePoll> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];

  DateTime? _selectedDate;
  bool _isSubmitting = false;

  final Map<String, bool> _ranks = {
    'All': false,
    'Managers': false,
    'Executive': false,
    'IT Department': false,
    'Riders': false,
    'Human Resource': false,
  };

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _toggleAll(bool value) {
    setState(() {
      _ranks.updateAll((key, _) => value);
    });
  }

  void _toggleSingleRank(String rank, bool value) {
    setState(() {
      _ranks[rank] = value;

      if (!value) {
        _ranks['All'] = false;
      }

      final nonAll = _ranks.entries
          .where((e) => e.key != 'All')
          .every((e) => e.value == true);

      if (nonAll) {
        _ranks['All'] = true;
      }
    });
  }

  void _addOption() {
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length > 1) {
      setState(() => _options.removeAt(index));
    }
  }

// Rank mapping for Firestore
  final Map<String, String> _rankMapping = {
    'Managers': 'Manager',
    'Executive': 'CEO',
    'IT Department': 'Systems, IT',
    'Riders': 'Rider',
    'Human Resource': 'Human Resource',
  };

  void _submitPoll() async {
    // Validation (same as before)
    if (_titleController.text.trim().isEmpty) {
      ToastService.warning("Please enter a title for the poll.");
      return;
    }

    if (_options.where((c) => c.text.trim().isNotEmpty).length < 2) {
      ToastService.warning("Please provide at least 2 options for the poll.");
      return;
    }

    if (_selectedDate == null) {
      ToastService.warning("Please select a deadline for the poll.");
      return;
    }

    final eligibleRanks = _ranks.entries
        .where((e) => e.key != 'All' && e.value)
        .map((e) => _rankMapping[e.key] ?? e.key)
        .toList();

    if (eligibleRanks.isEmpty) {
      ToastService.warning("Please select at least one eligible voter rank.");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.how_to_vote_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Create Poll?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title: ${_titleController.text.trim()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Will notify ${eligibleRanks.length} rank(s):'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: eligibleRanks.map((rank) => Chip(
                label: Text(rank, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Deadline: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Create Poll'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isSubmitting = true);

    try {
      final pollId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = FieldValue.serverTimestamp();

      // ✅ OPTIONS NOW AS MAP with countOfVotes
      final optionsMap = <String, Map<String, dynamic>>{};
      for (var controller in _options) {
        final optionText = controller.text.trim();
        if (optionText.isNotEmpty) {
          optionsMap[optionText] = {
            'text': optionText,
            'countOfVotes': 0,
          };
        }
      }

      await FirebaseFirestore.instance
          .collection('polls')
          .doc(pollId)
          .set({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'deadline': Timestamp.fromDate(_selectedDate!),
        'options': optionsMap,  // ✅ Map instead of List
        'eligibleVoters': eligibleRanks,
        'postedAt': now,
        'votedUserNames': [],
        'votedUIDs': [],
      });

      // Notify eligible voters (same as before)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userRank', whereIn: eligibleRanks.take(10).toList())
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

        batch.update(
          FirebaseFirestore.instance.collection('users').doc(userId),
          {
            'notifications.$notificationId.isRead': false,
            'notifications.$notificationId.message':
                'A new poll created: ${_titleController.text.trim()}. Kindly participate.',
            'notifications.$notificationId.time': now,
            'numberOfNotifications': FieldValue.increment(1),
          },
        );
      }

      await batch.commit();

      if (!mounted) return;

      _titleController.clear();
      _descriptionController.clear();

      ToastService.success("Poll created successfully!");

    } catch (e) {
      if (!mounted) return;
      ToastService.error("Error creating poll: $e");
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: theme.colorScheme.surface,
            shadowColor: theme.shadowColor.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(
                    context,
                    icon: Icons.how_to_vote_rounded,
                    label: 'Poll details',
                  ),
                  const SizedBox(height: 16),
                  _labeledField(
                    context,
                    label: 'Title',
                    child: TextField(
                      controller: _titleController,
                      decoration: _inputDecoration(
                        context,
                        hint: 'Enter poll title',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _labeledField(
                    context,
                    label: 'Description',
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        context,
                        hint: 'Enter poll description',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _sectionHeader(
                    context,
                    icon: Icons.event_rounded,
                    label: 'Deadline',
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        color: isDark
                            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _selectedDate == null
                                ? 'Select deadline'
                                : DateFormat('dd MMM yyyy').format(_selectedDate!),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _selectedDate == null
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _sectionHeader(
                    context,
                    icon: Icons.list_alt_rounded,
                    label: 'Options',
                    trailing: IconButton(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_circle_rounded),
                      color: Colors.green,
                      tooltip: 'Add option',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: List.generate(_options.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _options[index],
                                decoration: _inputDecoration(
                                  context,
                                  hint: 'Option ${index + 1}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _removeOption(index),
                              icon: const Icon(Icons.remove_circle_rounded),
                              color: Colors.redAccent,
                              tooltip: 'Remove option',
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  _sectionHeader(
                    context,
                    icon: Icons.people_alt_rounded,
                    label: 'Eligible voter ranks',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: _ranks.entries.map((entry) {
                        final isAll = entry.key == 'All';
                        return CheckboxListTile(
                          dense: true,
                          value: entry.value,
                          onChanged: (value) {
                            if (isAll) {
                              _toggleAll(value ?? false);
                            } else {
                              _toggleSingleRank(entry.key, value ?? false);
                            }
                          },
                          title: Text(
                            entry.key,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  isAll ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: theme.colorScheme.primary,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitPoll,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSubmitting ? 'Posting...' : 'Create Poll',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _labeledField(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(BuildContext context, {required String hint}) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 
        theme.brightness == Brightness.dark ? 0.25 : 0.7,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
      ),
    );
  }
}
