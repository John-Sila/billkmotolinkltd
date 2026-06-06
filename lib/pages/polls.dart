import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class Polls extends StatefulWidget {
  const Polls({super.key});

  @override
  State<Polls> createState() => _PollsState();
}

class _PollsState extends State<Polls> {
  final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
  String? currentUserRank;
  String? currentUserName;
  List<Map<String, dynamic>> activePolls = [];
  bool isLoading = true;
  final Map<String, bool> _pollLoadingStates = {}; // Track loading per poll ID
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await deleteExpiredPolls();  // ✅ Deletes first
    await _loadUserData();       // ✅ Then loads fresh data
  }

  Future<void> deleteExpiredPolls() async {
    try {
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      
      final expiredSnapshot = await FirebaseFirestore.instance
          .collection('polls')
          .where('deadline', isLessThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
          .get();

      if (expiredSnapshot.docs.isEmpty) {
        debugPrint('✅ No expired polls to delete');
        return;
      }

      int deletedCount = 0;
      List<DocumentReference> docsToDelete = [];

      // Collect all docs first
      for (var doc in expiredSnapshot.docs) {
        docsToDelete.add(doc.reference);
        deletedCount++;
      }

      // Delete in batches of 500
      for (int i = 0; i < docsToDelete.length; i += 500) {
        final batch = FirebaseFirestore.instance.batch();
        final end = (i + 500 > docsToDelete.length) ? docsToDelete.length : i + 500;
        
        for (int j = i; j < end; j++) {
          batch.delete(docsToDelete[j]);
        }
        
        await batch.commit();
        debugPrint('🗑️ Deleted batch ${i ~/ 500 + 1} (${end - i} docs)');
      }

      debugPrint('✅ Total deleted: $deletedCount expired polls');
      
    } catch (e) {
      debugPrint('❌ Error deleting expired polls: $e');
    }
  }

  Future<void> _loadUserData() async {
    if (currentUid == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid!)
          .get();

      if (userDoc.exists) {
        setState(() {
          currentUserRank = userDoc.data()?['userRank'] as String?;
          currentUserName = userDoc.data()?['userName'] as String?;
        });
      }

      await _fetchPolls();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchPolls() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('polls')
          .orderBy('postedAt', descending: true)
          .get();

      final polls = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        polls.add({
          ...data,
          'id': doc.id,
          'deadlineDate': (data['deadline'] as Timestamp).toDate(),
        });
      }

      setState(() => activePolls = polls);
    } catch (e) {
      debugPrint('Error fetching polls: $e');
    }
  }

  Future<void> _vote(String pollId, String option, String pollTitle) async {
    
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.how_to_vote, color: Colors.teal),
            ),
            const SizedBox(width: 16),
            Text('Confirm Vote', style: theme.textTheme.titleLarge),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vote for "$option"', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(pollTitle, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Vote'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || currentUid == null || currentUserRank == null) return;
    setState(() => _pollLoadingStates[pollId] = true);

    try {
      await FirebaseFirestore.instance.collection('polls').doc(pollId).update({
        'votedUserNames': FieldValue.arrayUnion([currentUserName!]),
        'votedUIDs': FieldValue.arrayUnion([currentUid!]),
        'options.$option.countOfVotes': FieldValue.increment(1),
      });

      ToastService.success("Your vote has been cast successfully!");

      await _fetchPolls();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to vote: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pollLoadingStates[pollId] = false);
      }
    }
  }

  bool _canVote(Map<String, dynamic> poll) {
    if (currentUid == null || currentUserRank == null) return false;
    
    final eligibleVoters = List<String>.from(poll['eligibleVoters'] ?? []);
    final votedUIDs = List<String>.from(poll['votedUIDs'] ?? []);
    final deadline = poll['deadlineDate'] as DateTime;

    return eligibleVoters.contains(currentUserRank!) &&
        !votedUIDs.contains(currentUid!) &&
        deadline.isAfter(DateTime.now());
  }

  bool _isEligible(Map<String, dynamic> poll) {
    if (currentUserRank == null) return false;
    final eligibleVoters = List<String>.from(poll['eligibleVoters'] ?? []);
    return eligibleVoters.contains(currentUserRank!);
  }

  bool _isManagerOrCEO() {
    return currentUserRank == 'Manager' || currentUserRank == 'CEO'|| currentUserRank == 'Systems, IT';
  }

  Color _getCardColor(bool canVote, bool isEligible, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    if (canVote) {
      return Colors.teal.withValues(alpha: isDark ? 0.2 : 0.1);
    } else if (isEligible) {
      return Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1);
    }
    return theme.colorScheme.surface;
  }

  Color _getTextSecondaryColor(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return isDark ? Colors.white70 : Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.poll, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            const Text('Cast your opinion', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onPrimary),
            onPressed: () async {
              await deleteExpiredPolls(); // Clean first
              await _fetchPolls();        // Then refresh
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: activePolls.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.poll_outlined, 
                      size: 80, 
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No active polls',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Polls will appear here when created',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
            :RefreshIndicator(
              onRefresh: _fetchPolls,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: activePolls.length,
                itemBuilder: (context, index) {
                  final poll = activePolls[index];
                  final canVote = _canVote(poll);
                  final isEligible = _isEligible(poll);
                  final votedUIDs = List<String>.from(poll['votedUIDs'] ?? []);
                  final votedUserNames = List<String>.from(poll['votedUserNames'] ?? []);

                  return Stack(
                    children: [
                      // Main Card
                      Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        elevation: isDark ? 2 : 6,
                        shadowColor: theme.shadowColor.withValues(alpha: 0.2),
                        color: _getCardColor(canVote, isEligible, theme),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: canVote 
                              ? BorderSide(color: Colors.teal.withValues(alpha: 0.4))
                              : BorderSide.none,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title with icon
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.how_to_vote, color: Colors.teal, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        poll['title'],
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Description
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    poll['description'],
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: _getTextSecondaryColor(theme),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Options header
                                Row(
                                  children: [
                                    Icon(Icons.list_alt, color: theme.colorScheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Options', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Options list
                                ...poll['options'].entries.map<Widget>((optionEntry) {
                                  final optionKey = optionEntry.key;  // "Option text"
                                  final optionData = optionEntry.value as Map<String, dynamic>;
                                  final optionText = optionData['text'] as String;
                                  final voteCount = optionData['countOfVotes'] as int? ?? 0;
                                  final hasVoted = votedUIDs.contains(currentUid ?? '');

                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                        color: hasVoted && (currentUserRank != null && optionKey == currentUserRank!)
                                            ? Colors.teal.withValues(alpha: 0.15)
                                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),

                                        border: hasVoted && (currentUserRank != null && optionKey == currentUserRank!)
                                            ? Border.all(color: Colors.teal, width: 2)
                                            : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),

                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.shadowColor.withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        if (canVote && !(_pollLoadingStates[poll['id']] ?? false))
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Radio<bool>(
                                              value: true,
                                              groupValue: null,
                                              activeColor: Colors.teal,
                                              onChanged: (_) => _vote(
                                                poll['id'],
                                                optionText,  // Pass option text (key)
                                                poll['title'],
                                              ),
                                            ),
                                          ),
                                        if (!canVote || (_pollLoadingStates[poll['id']] ?? false))
                                          SizedBox(width: 24, height: 24), // Spacer
                                          Expanded(
                                            child: Text(
                                              optionText,
                                              style: hasVoted && (currentUserRank != null && optionKey == currentUserRank!)
                                                ? theme.textTheme.bodyLarge?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal,
                                                  )
                                                : theme.textTheme.bodyLarge,

                                            ),
                                          ),
                                        // ✅ VOTE COUNT for Manager/CEO
                                        if (_isManagerOrCEO())
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.how_to_vote, size: 14, color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$voteCount',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),





                                const SizedBox(height: 20),
                                // Deadline badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _canVote(poll)
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: _canVote(poll) ? Colors.green : Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _canVote(poll) ? Icons.access_time_filled : Icons.schedule,
                                        size: 16,
                                        color: _canVote(poll) ? Colors.green : Colors.red,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Deadline: ${DateFormat('dd MMM yyyy').format(poll['deadlineDate'])}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _canVote(poll) ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Manager/CEO: Show voters
                                if (_isManagerOrCEO() &&
                                    (poll['votedUserNames'] as List?)?.isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.people_alt, color: Colors.blue, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Voted (${(poll['votedUserNames'] as List).length})',
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: (poll['votedUserNames'] as List)
                                                  .map<Widget>((name) => Container(
                                                        margin: const EdgeInsets.only(right: 8),
                                                        child: Chip(
                                                          label: Text(
                                                            name.toString(),
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(20),
                                                          ),
                                                        ),
                                                      ))
                                                  .toList(),
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
                      ),
                      // TOP-RIGHT LOADING INDICATOR
                      if (_pollLoadingStates[poll['id']] == true)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),





    );
  }
}
