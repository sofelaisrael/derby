import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/bin_schedule.dart';

/// Handles local notifications for bin collection reminders.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification service.
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Request notification permissions.
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a reminder for a collection.
  Future<void> scheduleCollectionReminder({
    required BinCollection collection,
    required int hoursBefore,
  }) async {
    if (!_initialized) await init();

    final scheduledDate = collection.date.subtract(
      Duration(hours: hoursBefore),
    );

    // Don't schedule in the past
    if (scheduledDate.isBefore(DateTime.now())) return;

    final wasteNames = collection.wasteStreams
        .map((w) => w.displayName)
        .join(', ');

    final body = hoursBefore >= 24
        ? 'Tomorrow: $wasteNames collection'
        : 'Collection in $hoursBefore hours: $wasteNames';

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      collection.date.hashCode,
      'Bin Collection Reminder',
      body,
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bin_reminders',
          'Bin Collection Reminders',
          channelDescription: 'Reminders for upcoming bin collections',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule reminders for all upcoming collections.
  Future<void> scheduleAllReminders(List<BinCollection> collections) async {
    // Cancel existing reminders first
    await cancelAllReminders();

    for (final collection in collections) {
      // Schedule 24-hour reminder
      await scheduleCollectionReminder(
        collection: collection,
        hoursBefore: 24,
      );

      // Schedule 2-hour reminder
      await scheduleCollectionReminder(
        collection: collection,
        hoursBefore: 2,
      );
    }
  }

  /// Cancel all scheduled reminders.
  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  /// Show an immediate notification (for testing).
  Future<void> showTestNotification() async {
    if (!_initialized) await init();

    await _plugin.show(
      0,
      'Derby Bins',
      'Notifications are working!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bin_reminders',
          'Bin Collection Reminders',
          channelDescription: 'Reminders for upcoming bin collections',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
