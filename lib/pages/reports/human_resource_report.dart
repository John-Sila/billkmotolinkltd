import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HumanResourceReports extends StatefulWidget {
  const HumanResourceReports({super.key});

  @override
  State<HumanResourceReports> createState() => _HumanResourceReportsState();
}

class _HumanResourceReportsState extends State<HumanResourceReports> {
  Map<String, dynamic>? _budget;
  String? _userRank;
  bool _isLoading = true;
  String? _error;
  bool _isApproving = false;
  bool _isDisbursing = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Fetch user and budget docs
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final budgetDoc = await FirebaseFirestore.instance
          .collection('expenses')
          .doc('budgets')
          .get();

      final userData = userDoc.data();
      final budgetData = budgetDoc.data();

      String? computedError;
      Map<String, dynamic>? computedBudget;

      // Handle missing user data
      if (userData == null) {
        computedError = 'User data not found. Please contact support.';
      } else if (!budgetDoc.exists || budgetData == null) {
        // Handle missing expenses/budgets document
        computedError =
            'No budget has been posted yet. Please check back later or contact the Human Resource team.';
      } else {
        computedBudget = budgetData;
      }

      if (!mounted) return;

      setState(() {
        _userRank = userData?['userRank'] ?? '';
        _budget = computedBudget;
        _error = computedError;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveBudget() async {
    if (_budget == null) return;
    if (mounted) setState(() => _isApproving = true);

    try {
      // 1. Update budget status
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc('budgets')
          .update({'status': 'Approved'});
      
      setState(() {
        _budget!['status'] = 'Approved';
      });

      // 2. Find all relevant ranks and notify them
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userRank', whereIn: ['CEO', 'Systems, IT', 'Human Resource'])
          .get();

      // 3. Add notification to each CEO's notifications MAP
      final now = FieldValue.serverTimestamp();
      final batch = FirebaseFirestore.instance.batch();

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
        
        // Update the notifications MAP directly in users/UID document
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(userId),
          {
            'notifications.$notificationId.isRead': false,
            'notifications.$notificationId.message': 'Budget has been approved and awaits disbursement.',
            'notifications.$notificationId.time': now,
            'numberOfNotifications': FieldValue.increment(1),
          },
        );
      }

      await batch.commit();

      ToastService.success("Budget approved successfully!");

    } catch (e) {
      debugPrint('Error approving budget: $e');
      // Handle error (show snackbar, etc.)
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _disburseBudget() async {
    if (_budget == null) return;
    if (mounted) setState(() => _isDisbursing = true);

    try {
      // Check company income first
      final incomeDoc = await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .get();

      if (!incomeDoc.exists) {
        _showInsufficientFundsDialog('Company income data not found');
        return;
      }

      final companyIncome = incomeDoc.data()?['companyIncome'] as num? ?? 0;
      final totalAmount = _budget!['totalAmount'] as num? ?? 0;

      if (companyIncome < totalAmount) {
        _showInsufficientFundsDialog(
          'Insufficient funds!\n'
          'Required: KSh ${NumberFormat('#,###').format(totalAmount)}\n'
          'Available: KSh ${NumberFormat('#,###').format(companyIncome)}',
        );
        return;
      }

      // Funds check passed - proceed with disbursement using transaction
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Re-fetch both docs to ensure data consistency
        final incomeFreshRef =
            FirebaseFirestore.instance.collection('general').doc('general_variables');
        final budgetFreshRef =
            FirebaseFirestore.instance.collection('expenses').doc('budgets');

        final incomeFresh = await transaction.get(incomeFreshRef);
        final budgetFresh = await transaction.get(budgetFreshRef);

        final freshIncome = incomeFresh.data()?['companyIncome'] as num? ?? 0;
        final freshTotal = budgetFresh.data()?['totalAmount'] as num? ?? 0;

        // Double-check in transaction
        if (freshIncome < freshTotal) {
          throw Exception('Insufficient funds during transaction');
        }

        // Update both atomically
        transaction.update(budgetFreshRef, {'status': 'Disbursed'});
        transaction.update(incomeFreshRef, {
          'companyIncome': freshIncome - freshTotal,
        });
      });

      // Update local state
      setState(() {
        _budget!['status'] = 'Disbursed';
      });

      // AFTER SUCCESSFUL DISBURSEMENT: notify Managers + Human Resource
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userRank', whereIn: ['Manager', 'Human Resource', 'Systems, IT'])
          .get();

      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

        batch.update(
          FirebaseFirestore.instance.collection('users').doc(userId),
          {
            'notifications.$notificationId.isRead': false,
            'notifications.$notificationId.message':
                'Income for budget has been disbursed.',
            'notifications.$notificationId.time': now,
            'numberOfNotifications': FieldValue.increment(1),
          },
        );
      }

      await batch.commit();

      ToastService.success("Budget disbursed successfully!");
    } catch (e) {
      if (e.toString().contains('Insufficient funds')) {
        _showInsufficientFundsDialog(e.toString());
      } else {
        _showInsufficientFundsDialog('Disbursement failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isDisbursing = false);
    }
  }

  void _showInsufficientFundsDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[50]!, Colors.red[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red[700],
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Insufficient Funds',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Got it'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If there was an error or no budget
    if (_error != null || _budget == null) {
        return Scaffold(
          appBar: AppBar(
          elevation: 0,
          title: Text(
            'Human Resource Reports',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _error ??
                      'No budget is available at the moment. Please check back later.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, 
                size: 64, 
                color: theme.colorScheme.error.withValues(alpha: 0.6)
              ),
              const SizedBox(height: 16),
              Text(_error!, 
                style: TextStyle(
                  fontSize: 16, 
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final heading = _budget!['heading'] ?? 'No heading';
    final status = _budget!['status'] ?? 'unknown';
    final postedAt = (_budget!['postedAt'] as Timestamp).toDate();
    final totalAmount = _budget!['totalAmount'] ?? 0.0;
    final items = (_budget!['items'] ?? {}) as Map<String, dynamic>;

    final statusColor = _getStatusColor(context, status);
    final statusText = _getStatusText(status);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Human Resource Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              heading,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('MMM dd, yyyy • HH:mm').format(postedAt),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Total Amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.tertiaryContainer.withValues(alpha: 0.8),
                          theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'KSh ${NumberFormat('#,###.00').format(totalAmount)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Items Table
            Text(
              'Budget Items',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header Row
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Item',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Amount',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Items
                  ...items.entries.map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: theme.dividerColor,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                e.key,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'KSh ${NumberFormat('#,###').format(e.value)}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            if (status == 'Pending' &&
                (_userRank == 'Manager' || _userRank == 'Systems, IT'))
              _buildActionButton(
                context,
                'Approve Budget',
                isLoading: _isApproving,
                Icons.check_circle_outline,
                _approveBudget,
              ),
            if (status == 'Approved' && (_userRank == 'CEO' || _userRank == 'Systems, IT'))
              _buildActionButton(
                context,
                'Disburse Budget',
                isLoading: _isDisbursing,
                Icons.account_balance_wallet_outlined,
                _disburseBudget,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
    {bool isLoading = false}
  ) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimary),
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status.toLowerCase()) {
      case 'approved':
        return theme.colorScheme.tertiary;
      case 'disbursed':
        return theme.colorScheme.secondary;
      case 'pending':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.outline;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'APPROVED';
      case 'disbursed':
        return 'DISBURSED';
      case 'pending':
        return 'PENDING';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'disbursed':
        return Icons.account_balance_wallet;
      case 'pending':
        return Icons.hourglass_empty;
      default:
        return Icons.help_outline;
    }
  }
}
