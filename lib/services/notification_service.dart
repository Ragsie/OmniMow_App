import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

   final AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher'); 

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // Use the required settings parameter
    await _notificationsPlugin.initialize(settings: initSettings);

    // Request permission on Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  Future<void> showWarning({required int id, required String title, required String body}) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mower_alerts',
      'Robot Alerts',
      channelDescription: 'Alerts for battery, RTK, and hardware',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF00FF00),
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // Show the notification with named parameters
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}

final notificationService = NotificationService();