import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AppNotifications extends StatefulWidget {
  const AppNotifications({super.key});

  @override
  State<AppNotifications> createState() => _AppNotificationsState();
}

class _AppNotificationsState extends State<AppNotifications> {
  late Future<List<AppNotificationModel>> futureNotifications;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    futureNotifications = fetchNotifications(uid);
  }

  Future<void> resetNotificationCounter(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'numberOfNotifications': 0});
  }

  Future<List<AppNotificationModel>> fetchNotifications(String uid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = userDoc.data();
    if (data == null) return [];

    final notifications = data['notifications'] as Map<String, dynamic>?;
    if (notifications == null || notifications.isEmpty) return [];

    final List<AppNotificationModel> result = [];

    notifications.forEach((key, value) {
      final message = value['message'] ?? '';
      final ts = value['time'] as Timestamp?;
      final isRead = value['isRead'] ?? false;

      if (ts != null) {
        result.add(AppNotificationModel(
          id: key,
          message: message,
          time: ts.toDate(),
          isRead: isRead,
        ));
      }
    });

    result.sort((a, b) => b.time.compareTo(a.time));
    return result;
  }

  String formatTimestamp(DateTime dt) {
    if (dt.isToday) {
      return DateFormat('HH:mm').format(dt);
    } else if (dt.isYesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(dt)}';
    }
    final day = DateFormat('MMM d, yyyy').format(dt);
    final time = DateFormat('HH:mm').format(dt);
    return "$day at $time";
  }

  Future<void> markAllAsRead(String uid, List<AppNotificationModel> list) async {
    final updates = <String, dynamic>{};
    for (var item in list) {
      updates["notifications.${item.id}.isRead"] = true;
    }
    if (updates.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update(updates);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            onPressed: () async {
              final notifications = await futureNotifications;
              await markAllAsRead(uid, notifications);
              setState(() {
                futureNotifications = fetchNotifications(uid);
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotificationModel>>(
        future: futureNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          // Reset counter on first load
          WidgetsBinding.instance.addPostFrameCallback((_) {
            resetNotificationCounter(uid);
            markAllAsRead(uid, notifications);
          });

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see updates here when something happens',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotificationModel notification) {
    final isUnread = !notification.isRead;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: isUnread ? 8 : 2,
        shadowColor: isUnread ? Colors.blue[100] : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isUnread
              ? BorderSide(color: Colors.blue[100]!, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isUnread
              ? () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'notifications.${notification.id}.isRead': true});
                  setState(() {
                    futureNotifications = fetchNotifications(uid);
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification dot/icon
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isUnread ? Colors.blue[600] : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              formatTimestamp(notification.time),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Colors.grey[700],
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



}

extension DateTimeX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
}

class AppNotificationModel {
  final String id;
  final String message;
  final DateTime time;
  final bool isRead;

  AppNotificationModel({
    required this.id,
    required this.message,
    required this.time,
    required this.isRead,
  });
}
