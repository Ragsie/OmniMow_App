import 'package:flutter/material.dart'; // Sikrer at Color-klassen er tilgængelig
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Bruger det indbyggede standard-appikon til notifikations-hovedet for at undgå opstartsfejl
    final AndroidInitializationSettings androidSettings =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // Initialiserer det lokale plugin med navngiven settings-parameter
    await _notificationsPlugin.initialize(settings: initSettings);

    // Anmod om tilladelse til notifikationer på Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  Future<void> showWarning({required int id, required String title, required String body}) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mower_alerts',
      'Mower Alerts',
      channelDescription: 'Alerts for battery, RTK, and hardware issues',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF00FF00),
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // Viser notifikationen med korrekte navngivne parametre
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}

final notificationService = NotificationService();