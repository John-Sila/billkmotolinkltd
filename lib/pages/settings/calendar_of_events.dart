import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CalendarOfEvents extends StatefulWidget {
  const CalendarOfEvents({super.key});

  @override
  State<CalendarOfEvents> createState() => _CalendarOfEventsState();
}

class _CalendarOfEventsState extends State<CalendarOfEvents> {
  String? currentUserRank;

  @override
  void initState() {
    super.initState();
    _fetchUserRank();
  }

  Future<void> _fetchUserRank() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        currentUserRank = doc.data()?['userRank'];
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Premium Header with Stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.9),
                    theme.primaryColor.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
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
                    Icons.calendar_month_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Company Events',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stay organized with team events',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ✅ Live Events Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('companyEvents')
                    .orderBy('startDate', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: theme.primaryColor),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 80,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No events yet',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to add a company event!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final eventDoc = snapshot.data!.docs[index];
                      final event = eventDoc.data() as Map<String, dynamic>;
                      return EventCard(
                        event: event,
                        eventId: eventDoc.id,
                        isDark: isDark,
                        theme: theme,
                        isManagerOrCEO: currentUserRank == "CEO" || currentUserRank == "Manager" || currentUserRank == "Systems, IT",
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String eventId;
  final bool isDark;
  final ThemeData theme;
  final bool isManagerOrCEO;

  const EventCard({
    super.key,
    required this.event,
    required this.eventId,
    required this.isDark,
    required this.theme,
    required this.isManagerOrCEO,
  });

  @override
  Widget build(BuildContext context) {
    final startDate = (event['startDate'] as Timestamp).toDate();
    final endDate = (event['endDate'] as Timestamp).toDate();
    final now = DateTime.now();
    final isToday = startDate.day == now.day && 
                   startDate.month == now.month && 
                   startDate.year == now.year;
    final isUpcoming = startDate.isAfter(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 8,
        shadowColor: theme.primaryColor.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: isDark ? Colors.grey[850] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isToday 
                          ? [Colors.orange.shade400, Colors.orange.shade600]
                          : isUpcoming 
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : [Colors.grey.shade400, Colors.grey.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isToday ? Icons.today : Icons.event,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'],
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_formatTime(startDate)} - ${_formatTime(endDate)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                
                
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteDialog(context, eventId);
                      } else if (value == 'add_personal') {
                        _addToPersonalCalendar(context, event);
                      }
                    },
                    itemBuilder: (context) {
                      // ✅ Build list conditionally - NO FutureBuilder needed
                      final List<PopupMenuItem<String>> menuItems = [
                        const PopupMenuItem(
                          value: 'add_personal',
                          child: ListTile(
                            leading: Icon(Icons.calendar_today),
                            title: Text('Add to My Calendar'),
                          ),
                        ),
                      ];

                      // ✅ Get current user rank (store in parent widget or use Stream)
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        // Check user rank from local state or quick Firestore doc
                        // Replace with your user rank logic
                        
                        if (isManagerOrCEO) {
                          menuItems.add(
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text('Delete Event', style: TextStyle(color: Colors.red)),
                              ),
                            ),
                          );
                        }
                      }

                      return menuItems; // ✅ Returns List<PopupMenuEntry<String>> ✅
                    },
                  ),
                        
                
                
                
                ],
              ),
              const SizedBox(height: 16),

              // Date & Location
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(startDate),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (event['location']?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event['location'],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (event['description']?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  event['description'],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),

              // Creator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'by ${event['creatorEmail'] ?? 'Unknown'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Today';
    }
    return '${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getMonth(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  void _showDeleteDialog(BuildContext context, String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this company event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('companyEvents')
                  .doc(eventId)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addToPersonalCalendar(BuildContext context, Map<String, dynamic> event) {
    // Add to personal calendar logic here using add_2_calendar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to personal calendar!')),
    );
  }
}
