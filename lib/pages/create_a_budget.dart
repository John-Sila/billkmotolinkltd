import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateBudget extends StatefulWidget {
  const CreateBudget({super.key});

  @override
  State<CreateBudget> createState() => _CreateBudgetState();
}

class _CreateBudgetState extends State<CreateBudget> {
  final TextEditingController _titleController = TextEditingController();
  final List<Map<String, TextEditingController>> _items = [];
  String? _budgetErrorText;
  String? _previousSuccessText;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _addRow(); // start with one row by default
    _checkBudgetStatus();
  }

  Future<void> _checkBudgetStatus() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('expenses').doc('budgets');
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        _budgetErrorText = null;
        setState(() {});
        return;
      }

      final data = docSnap.data();
      final status = data?['status'] ?? '';

      // Replace this condition with your actual business rule
      if (status == 'Pending') {
        _budgetErrorText = 'Previous budget is still pending.';
      }
       else if (status == 'Approved') {
        _budgetErrorText = 'Previous budget still hasn\'t been disbursed!';
      }
       else if (status == 'Disbursed') {
        _previousSuccessText = 'The previous budget was successfully disbursed.';
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error checking budget status: $e');
      _budgetErrorText = null;
      setState(() {});
    } finally {
      _isLoadingStatus = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final row in _items) {
      row['name']?.dispose();
      row['amount']?.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _items.add({
        'name': TextEditingController(),
        'amount': TextEditingController(),
      });
    });
  }

  void _removeRow() {
    if (_items.isNotEmpty) {
      setState(() {
        final removed = _items.removeLast();
        removed['name']?.dispose();
        removed['amount']?.dispose();
      });
    }
  }

  Future<void> postBudget() async {
    final title = _titleController.text.trim();

    // 1. Validate title
    if (title.isEmpty) {
      ToastService.warning("Please enter a budget title.");
      return;
    }

    // 2. Validate items
    for (final row in _items) {
      if (row['name']!.text.trim().isEmpty || row['amount']!.text.trim().isEmpty) {
        ToastService.warning("Please fill out all item fields.");
        return;
      }
    }

    // 3. Confirm before posting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Posting'),
        content: const Text('Do you want to post this budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 4. Prepare items map
    final Map<String, double> itemsMap = {};
    double total = 0;
    for (final row in _items) {
      final name = row['name']!.text.trim();
      final amount = double.parse(row['amount']!.text.trim());
      itemsMap[name] = amount;
      total += amount;
    }

    final payload = {
      'heading': title,
      'postedAt': Timestamp.now(),
      'status': 'Pending',
      'items': itemsMap,
      'totalAmount': total,
    };

    try {
      final docRef = FirebaseFirestore.instance.collection('expenses').doc('budgets');
      await docRef.set(payload);
      ToastService.success("Budget posted successfully!");

      _titleController.clear();
      for (final row in _items) {
        row['name']!.clear();
        row['amount']!.clear();
      }
      await _postClockInNotification();
    } catch (e) {
      ToastService.error("Error posting budget: $e");
    }
  }

  Future<void> _postClockInNotification() async {
    try {
      final now = Timestamp.now();
      final notifRef = FirebaseFirestore.instance.collection('notifications').doc('latest');

      await notifRef.set({
        'body': "There is a new budget posted.",
        'targetRoles': ["Manager", "CEO", "Systems, IT"],
        'timestamp': now,
        'title': "Clockins",
      });
    } catch (e) {
      debugPrint("Error posting clock-in notification: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'New Budget',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Give your budget a title and add line items with amounts.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Budget title
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Budget Title',
                  hintText: 'e.g. Contemporary Operations Budget',
                  prefixIcon: Icon(Icons.edit_outlined, color: Colors.blue[600]),
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                ),
              ),
              const SizedBox(height: 24),

              // Items header + add/remove buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Budget Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue[50],
                        ),
                        onPressed: _addRow,
                        icon: Icon(Icons.add, color: Colors.blue[700]),
                        tooltip: 'Add item',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _items.isNotEmpty ? _removeRow : null,
                        icon: Icon(Icons.remove, color: Colors.red[600]),
                        tooltip: 'Remove last item',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dynamic rows
              if (_items.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[500]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No items added yet. Tap + to add your first budget item.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: List.generate(_items.length, (index) {
                    final nameController = _items[index]['name']!;
                    final amountController = _items[index]['amount']!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Item Name',
                                hintText: 'e.g. Fuel, Salaries',
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: Colors.blue[600]!, width: 2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                hintText: '0.00',
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: Colors.blue[600]!, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

              const SizedBox(height: 28),



              if (_budgetErrorText != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _budgetErrorText!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_budgetErrorText != null) const SizedBox(height: 24),



              if (_previousSuccessText != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _previousSuccessText!,
                    style: const TextStyle(color: Colors.green),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_previousSuccessText != null) const SizedBox(height: 24),






              // Post button
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_budgetErrorText != null || _isLoadingStatus) ? null : postBudget,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    'Post Budget',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),


                









              ),
            ],
          ),
        ),
      ),
    );
  }
}
