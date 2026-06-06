import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;
  late FirebaseMessaging _messaging;
  late FlutterLocalNotificationsPlugin _localNotifications;
  late SharedPreferences _prefs;
  
  StreamSubscription? _personalSubscription;
  StreamSubscription? _generalSubscription;
  
  String? _lastPersonalNotifId;
  String? _lastGeneralNotifId;
  bool _isInitialized = false;
  String? _fcmToken;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Initialize Firebase
      await Firebase.initializeApp();
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      _messaging = FirebaseMessaging.instance;
      
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // Load saved IDs
      _lastPersonalNotifId = _prefs.getString('last_personal_notif_id');
      _lastGeneralNotifId = _prefs.getString('last_general_notif_id');
      
      // Initialize notifications
      await _initializeLocalNotifications();
      
      // Setup Firebase Messaging
      await _setupFirebaseMessaging();
      
      _isInitialized = true;
      
      // print('✅ NotificationService initialized successfully');
      
      // Start listening if user is logged in
      if (_auth.currentUser != null) {
        await _startNotificationListeners();
        await _saveFcmTokenToUser();
      }
      
    } catch (e) {
      // print('❌ Error initializing NotificationService: $e');
      // print('Stack trace: $stack');
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      // Request notification permissions
      if (Platform.isIOS) {
        await _messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      }
      
      // Get FCM token
      _fcmToken = await _messaging.getToken();
      // print('FCM Token: $_fcmToken');
      
      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
      
      // Handle when app is terminated
      FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);
      
    } catch (e) {
      // print('Error setting up Firebase Messaging: $e');
    }
  }

  Future<void> _saveFcmTokenToUser() async {
    try {
      final userId = _auth.currentUser?.uid;
      final fcmToken = _fcmToken;
      
      if (userId != null && fcmToken != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([fcmToken]),
          'lastFcmToken': fcmToken,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // print('FCM token saved to user document');
      }
    } catch (e) {
      // print('Error saving FCM token: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();
      
      // Android initialization
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization
      const DarwinInitializationSettings iosInitializationSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidInitializationSettings,
        iOS: iosInitializationSettings,
      );
      
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );
      
      // Create notification channel for Android 8.0+
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'important_notifications',
          'Important Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
          playSound: true,
        );
        
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
      
      // print('✅ Local notifications initialized');
    } catch (e) {
      // print('❌ Error initializing local notifications: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // print('Foreground message received: ${message.notification?.title}');
    
    // Show local notification
    if (message.notification != null) {
      await _showNotification(
        id: DateTime.now().millisecondsSinceEpoch % 10000,
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? 'You have a new message',
        payload: message.data['type'] ?? 'general',
      );
    }
  }

  Future<void> _handleMessageOpened(RemoteMessage message) async {
    // print('App opened from notification: ${message.data}');
    _handleNotificationTap(message.data['type']);
  }

  Future<void> _handleInitialMessage(RemoteMessage? message) async {
    if (message != null) {
      // print('App launched from terminated state: ${message.data}');
      _handleNotificationTap(message.data['type']);
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    
    // print('Notification tapped with payload: $payload');
    
    // You can use a navigator key or event bus to handle navigation
    // Example: navigate to notifications screen
    // navigatorKey.currentState?.pushNamed('/notifications');
  }

  Future<void> _startNotificationListeners() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    // Cancel existing subscriptions
    _personalSubscription?.cancel();
    _generalSubscription?.cancel();
    
    // Listen to personal notifications
    _personalSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(_handlePersonalSnapshot);
    
    // Listen to general notifications
    _generalSubscription = _firestore
        .collection('notifications')
        .doc('latest')
        .snapshots()
        .listen(_handleGeneralSnapshot);
    
    // print('✅ Notification listeners started');
  }

  Future<void> _handlePersonalSnapshot(DocumentSnapshot snapshot) async {
    try {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final notifications = data['notifications'] as Map<String, dynamic>? ?? {};
      
      if (notifications.isNotEmpty) {
        await _processPersonalNotifications(notifications);
      }
    } catch (e) {
      // print('Error handling personal snapshot: $e');
    }
  }

  Future<void> _processPersonalNotifications(Map<String, dynamic> notifications) async {
    try {
      String? latestUnreadNotifId;
      Timestamp? latestTime;
      
      notifications.forEach((notifId, notifData) {
        final isRead = notifData['isRead'] as bool? ?? true;
        final time = notifData['time'] as Timestamp?;
        
        if (!isRead && time != null) {
          if (latestTime == null || time.millisecondsSinceEpoch > latestTime!.millisecondsSinceEpoch) {
            latestTime = time;
            latestUnreadNotifId = notifId;
          }
        }
      });
      
      if (latestUnreadNotifId != null && latestUnreadNotifId != _lastPersonalNotifId) {
        _lastPersonalNotifId = latestUnreadNotifId;
        await _prefs.setString('last_personal_notif_id', latestUnreadNotifId!);
        
        final notifData = notifications[latestUnreadNotifId];
        await _showNotification(
          id: 1000,
          title: notifData['title']?.toString() ?? 'Personal Notification',
          body: notifData['message']?.toString() ?? 'You have a new notification',
          payload: 'personal:$latestUnreadNotifId',
        );
      }
    } catch (e) {
      // print('Error processing personal notifications: $e');
    }
  }

  Future<void> _handleGeneralSnapshot(DocumentSnapshot snapshot) async {
    try {
      if (!snapshot.exists) return;
      
      await _processGeneralNotification(snapshot);
    } catch (e) {
      // print('Error handling general snapshot: $e');
    }
  }

  Future<void> _processGeneralNotification(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final targetRoles = List<String>.from(data['targetRoles'] ?? []);
      
      // Skip if already shown
      if (doc.id == _lastGeneralNotifId) return;
      
      final userRole = await _getUserRole();
      if (userRole == null) return;
      
      if (targetRoles.contains(userRole)) {
        _lastGeneralNotifId = doc.id;
        await _prefs.setString('last_general_notif_id', doc.id);
        
        await _showNotification(
          id: 2000,
          title: data['title']?.toString() ?? 'General Notification',
          body: data['body']?.toString() ?? 'New update available',
          payload: 'general:${doc.id}',
        );
      }
    } catch (e) {
      // print('Error processing general notification: $e');
    }
  }

  Future<String?> _getUserRole() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['role']?.toString();
    } catch (e) {
      // print('Error getting user role: $e');
      return null;
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'important_notifications',
        'Important Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        colorized: true,
        color: Colors.blue,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
      
      // print('✅ Notification shown: $title');
    } catch (e) {
      // print('❌ Error showing notification: $e');
    }
  }

  // Manual check method
  Future<void> checkNotificationsManually() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Check personal notifications
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final notifications = userDoc.data()?['notifications'] as Map<String, dynamic>? ?? {};
        await _processPersonalNotifications(notifications);
      }
      
      // Check general notifications
      final generalDoc = await _firestore.collection('notifications').doc('latest').get();
      if (generalDoc.exists) {
        await _processGeneralNotification(generalDoc);
      }
      
    } catch (e) {
      // print('Error during manual check: $e');
    }
  }

  void onUserLoggedIn() {
    if (_isInitialized) {
      _startNotificationListeners();
      _saveFcmTokenToUser();
    }
  }

  void onUserLoggedOut() {
    _personalSubscription?.cancel();
    _generalSubscription?.cancel();
    _personalSubscription = null;
    _generalSubscription = null;
  }

  void dispose() {
    _personalSubscription?.cancel();
    _generalSubscription?.cancel();
  }
}