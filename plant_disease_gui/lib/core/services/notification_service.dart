import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
        },
      );

      _isInitialized = true;
      print("NotificationService: Inicializado com sucesso.");
    } catch (e) {
      _isInitialized = false;
      print("NotificationService: Erro ao inicializar: $e");
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      final bool? granted = await androidImplementation
          ?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();

      final bool? granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'plant_health_alerts',
    String channelName = 'Alertas de Saúde',
    Importance importance = Importance.max,
    Priority priority = Priority.high,
    bool showProgress = false,
    int maxProgress = 0,
    int progress = 0,
    bool onlyAlertOnce = false,
    bool fullScreenIntent = false,
    AndroidNotificationCategory? category,
  }) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      print(
        "NotificationService: Notificações não suportadas nesta plataforma.",
      );
      return;
    }

    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          channelId,
          channelName,
          importance: importance,
          priority: priority,
          showWhen: true,
          onlyAlertOnce: onlyAlertOnce,
          enableVibration: true,
          channelShowBadge: true,
          showProgress: showProgress,
          maxProgress: maxProgress,
          progress: progress,
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
          fullScreenIntent: fullScreenIntent,
          category:
              category ??
              (fullScreenIntent
                  ? AndroidNotificationCategory.alarm
                  : AndroidNotificationCategory.status),
          audioAttributesUsage:
              fullScreenIntent
                  ? AudioAttributesUsage.alarm
                  : AudioAttributesUsage.notification,
          visibility: NotificationVisibility.public,
          ticker: title,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }
}
