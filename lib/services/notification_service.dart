import 'package:flutter/material.dart'; // Ensures that the Color class is available
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Owns initialization and delivery of local mower alert notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initializes the notification plugin once and requests permission on
  /// Android 13+ and iOS.
  Future<void> init() async {
    if (_isInitialized) return;

    // Uses the built-in default app icon for the notification header to avoid startup crashes
    final AndroidInitializationSettings androidSettings =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS asks the user for alert, badge and sound permission on initialization
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    // Initializes the local plugin with named settings parameter
    await _notificationsPlugin.initialize(settings: initSettings);

    // Request notification permissions on Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  /// Shows a high-priority notification for a mower warning.
  Future<void> showWarning({
    required int id,
    required String title,
    required String body,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'mower_alerts',
          'Robot Alerts',
          channelDescription: 'Alerts about battery, camera calibration, and hardware',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF00FF00),
        );

    // Shows the alert as a banner with sound even while the app is in the foreground
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

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
