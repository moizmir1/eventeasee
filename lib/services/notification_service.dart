import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotificationChannel() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // --- FOREGROUND ALERT SETTINGS ALIGNED ---
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> triggerInstantAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    // Android Notification Details explicitly configured for foreground popping
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_easee_chat_channel',
      'Event Easee Core Alerts',
      channelDescription: 'Real-time pipeline notifications updates for Event Easee',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      // Windows / Android defaults forcing the heads-up notification behavior even if app is foreground
      setAsGroupSummary: true,
    );

    const NotificationDetails platformChannelDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelDetails,
    );
  }
}