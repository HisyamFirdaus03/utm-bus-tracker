import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    // Runtime permission prompts (Android 13+ and iOS).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> showEtaAlert({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'bus_eta',
      'Bus arrival alerts',
      channelDescription:
          'Notifications when a watched bus is near your stop',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    final notifId = DateTime.now().millisecondsSinceEpoch.remainder(0x7FFFFFFF);
    await _plugin.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: android, iOS: ios),
    );
  }
}
