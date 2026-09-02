import 'package:flutter/material.dart'; // Ensures that the Color class is available
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Uses the built-in default app icon for the notification header to avoid startup crashes
    final AndroidInitializationSettings androidSettings =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // Initializes the local plugin with named settings parameter
    await _notificationsPlugin.initialize(settings: initSettings);

    // Request notification permissions on Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  Future<void> showWarning({required int id, required String title, required String body}) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mower_alerts',
      'Robot Alerts',
      channelDescription: 'Alerts about battery, RTK, and hardware',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF00FF00),
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // Shows the notification with correct named parameters
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}

final notificationService = NotificationService();