import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/services/bin_scheme.dart';
import 'package:derby_bins/services/reminder_store.dart';
import 'package:derby_bins/services/schedule_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

const _channelId = 'bin_reminders_v2';
const _channelName = 'Bin reminders';
const _channelDesc = 'Reminders for upcoming bin collections';

/// Fixed reminder times. Each entry is (hour, minute, day offset from the
/// collection date): slot 0 is 12:00 the day before, slot 1 is 20:00 the
/// day before, slot 2 is 7:00 on the collection day itself.
const reminderSlots = [(12, 0, -1), (20, 0, -1), (7, 0, 0)];
const _windowHours = [4, 4, 2];

/// Headless callback â€” registered in main.dart via
/// BackgroundFetch.registerHeadlessTask.
void backgroundFetchHeadlessTask(HeadlessEvent event) async {
  final taskId = event.taskId;
  final isTimeout = event.timeout;
  if (isTimeout) {
    BackgroundFetch.finish(taskId);
    return;
  }
  try {
    await NotificationService.backgroundFetchCheck();
  } finally {
    BackgroundFetch.finish(taskId);
  }
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _fetchConfigured = false;

  static const _batteryChannel = MethodChannel('derbybins/battery');

  /// Slot-scheme version. Bumped when reminder ids/times change so
  /// initialize() can cancel stale alarms scheduled under an older scheme.
  static const _slotSchemeVersion = 2;

  /// IDs that have already been delivered by the background-fetch path
  /// so they aren't re-shown every 15 minutes. Persisted to survive
  /// process restarts on Android.
  static Set<int> _delivered = {};
  static bool _deliveredLoaded = false;
  static bool _lastExact = false; // whether the last schedule used exact alarms
  static bool _rescheduling = false; // reentrancy guard

  static final onNotifications = BehaviorSubject<String?>();

  static Future<NotificationDetails> _notificationDetails() async {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  static String _timezoneNameFromOffset(Duration offset) {
    final seconds = offset.inSeconds;
    if (seconds >= -3600 && seconds <= 3600) return 'Europe/London';
    const map = <int, String>{
      -43200: 'Pacific/Funafuti',
      -39600: 'Pacific/Pago_Pago',
      -36000: 'Pacific/Honolulu',
      -34200: 'Pacific/Marquesas',
      -32400: 'America/Anchorage',
      -28800: 'America/Los_Angeles',
      -25200: 'America/Denver',
      -21600: 'America/Chicago',
      -18000: 'America/New_York',
      -14400: 'America/Halifax',
      -12600: 'America/St_Johns',
      -10800: 'America/Argentina/Buenos_Aires',
      -7200: 'Atlantic/South_Georgia',
      -3600: 'Atlantic/Azores',
      7200: 'Europe/Berlin',
      10800: 'Europe/Moscow',
      14400: 'Asia/Dubai',
      16200: 'Asia/Kabul',
      18000: 'Asia/Karachi',
      19800: 'Asia/Kolkata',
      20700: 'Asia/Kathmandu',
      21600: 'Asia/Dhaka',
      23400: 'Asia/Yangon',
      25200: 'Asia/Bangkok',
      28800: 'Asia/Shanghai',
      31500: 'Australia/Eucla',
      32400: 'Asia/Tokyo',
      34200: 'Australia/Adelaide',
      36000: 'Australia/Sydney',
      37800: 'Australia/Lord_Howe',
      39600: 'Pacific/Guadalcanal',
      43200: 'Pacific/Auckland',
      45900: 'Pacific/Chatham',
      46800: 'Pacific/Tongatapu',
      50400: 'Pacific/Kiritimati',
    };
    return map[seconds] ?? 'Europe/London';
  }

  static Future<void> init({bool initScheduled = false}) async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final localOffset = DateTime.now().timeZoneOffset;
    final tzName = _timezoneNameFromOffset(localOffset);
    tz.setLocalLocation(tz.getLocation(tzName));

    const androidSettings =
        AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        onNotifications.add(details?.notificationResponse?.payload);
      }
    } catch (_) {
      // Same "Missing type parameter" edge case â€” safe to skip.
    }

    var initOk = false;
    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          onNotifications.add(response.payload);
        },
      );
      initOk = true;
    } catch (_) {
      // flutter_local_notifications v18 can crash with "Missing type
      // parameter" on Android when stale notifications from a previous
      // version exist. The app works without scheduled notifications.
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
    }

    _initialized = initOk;
    debugPrint('[Notif] init: initialized=$initOk tz=${tz.local.name} '
        'deviceOffset=${DateTime.now().timeZoneOffset}');

    if (initOk) {
      try {
        final pending = await android?.pendingNotificationRequests();
        debugPrint('[Notif] pending scheduled: ${pending?.length ?? 0}');
        for (final p in pending ?? []) {
          debugPrint('  #${p.id} "${p.title}" '
              'â†’ ${p.scheduledDate?.toIso8601String() ?? 'unknown'}');
        }
      } catch (e) {
        debugPrint('[Notif] pending query error: $e');
      }
    }

    if (initOk) {
      try {
        final storedVersion = await ReminderStore.getSlotSchemeVersion();
        if (storedVersion < _slotSchemeVersion) {
          debugPrint('[Notif] slot-scheme migration $storedVersion â†’ '
              '$_slotSchemeVersion: cancelling stale alarms');
          await cancelAll();
          await ReminderStore.setSlotSchemeVersion(_slotSchemeVersion);

          // Rebuild the schedule from the cached area so offline/headless
          // launches don't stay "enabled" with zero alarms after migration.
          if (await ReminderStore.isEnabled()) {
            final cachedArea = await ReminderStore.getCachedArea();
            final cachedSlug = await ReminderStore.getCachedCouncilSlug();
            if (cachedArea != null && cachedSlug != null) {
              await scheduleReminders(cachedArea, cachedSlug);
            }
          }
        }
      } catch (e) {
        debugPrint('[Notif] slot-scheme migration error: $e');
      }
    }
  }

  /// Prompts for notification permission only (no system page for exact
  /// alarms â€” that is escalated later from Settings). Returns whether
  /// notifications are granted.
  ///
  /// Must only be called after showing an informational pre-permission dialog
  /// (Guidelines 4.5.4 & 5.1.1 â€” Apple Sites and Services). Callers must show a
  /// neutral Continue dialog explaining local reminders, then always hand off to the system
  /// prompt - never mimic Allow/Don't Allow or skip the system dialog.
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Notifications prompt only. Exact-alarm access is escalated later in
        // Settings via the explainer dialog + openExactAlarmSettings(); until
        // then reminders schedule with inexact alarms.
        final granted = await android.requestNotificationsPermission();
        debugPrint('[Notif] requestPermissions: notificationsGranted=$granted');
        return granted ?? false;
      }
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Whether the user has already granted notification permission, without
  /// showing any prompt. Android <= 12 is enabled by default; Android 13+
  /// reflects the POST_NOTIFICATIONS toggle. iOS provisional auth counts as
  /// granted.
  static Future<bool> notificationsPermissionGranted() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      try {
        return await android.areNotificationsEnabled() ?? false;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      try {
        final opts = await ios?.checkPermissions();
        return (opts?.isEnabled ?? false) ||
            (opts?.isProvisionalEnabled ?? false);
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Deep-link to this app's settings page so the user can re-enable
  /// notifications after denying the OS prompt.
  /// Android opens the app details page; iOS opens the app's Settings page.
  static Future<bool> openAppSettings() async {
    try {
      if (Platform.isAndroid) {
        return await launchUrl(
          Uri.parse('package:uk.co.derbybins.derby_bins'),
          mode: LaunchMode.externalApplication,
        );
      }
      if (Platform.isIOS) {
        return await launchUrl(Uri.parse('app-settings:'));
      }
    } catch (_) {}
    return false;
  }

  /// Start the periodic background-fetch task (~15 min intervals).
  /// Uses `forceAlarmManager: true` for reliable firing even when
  /// the app is killed.
  static Future<void> configureBackgroundFetch() async {
    if (_fetchConfigured) return;
    try {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          stopOnTerminate: false,
          enableHeadless: true,
          forceAlarmManager: true,
          startOnBoot: true,
        ),
        _onFetch,
        _onFetchTimeout,
      );
      _fetchConfigured = true;
      debugPrint('[Notif] BackgroundFetch configured (15min, headless, '
          'forceAlarmManager)');
    } catch (e) {
      debugPrint('[Notif] BackgroundFetch.configure error: $e');
    }
  }

  static Future<void> _onFetch(String taskId) async {
    await backgroundFetchCheck();
    BackgroundFetch.finish(taskId);
  }

  static Future<void> _onFetchTimeout(String taskId) async {
    BackgroundFetch.finish(taskId);
  }

  /// Called every ~15 minutes by background-fetch.
  /// Checks if any pending reminders should fire right now and shows
  /// them via [_plugin.show].
  static Future<void> backgroundFetchCheck() async {
    try {
      await init();
      final enabled = await ReminderStore.isEnabled();
      debugPrint('[Notif] bgFetchCheck: enabled=$enabled now=${DateTime.now()}');
      if (!enabled) return;

      if (!_deliveredLoaded) {
        _delivered = await ReminderStore.getDeliveredIds();
        _deliveredLoaded = true;
      }

      final now = DateTime.now();

      final area = await ReminderStore.getCachedArea();
      if (area == null) return;
      final councilSlug = await ReminderStore.getCachedCouncilSlug();
      if (councilSlug == null) return;

      final collectionDays = getNextCollectionDays(area, 8, now);

      for (final day in collectionDays) {
        final allBinLabels = day.collections
            .map((c) => CouncilScheme.resolve(councilSlug, c.stream).label)
            .toList();
        for (var slot = 0; slot < reminderSlots.length; slot++) {
          final (hour, minute, offset) = reminderSlots[slot];
          final reminderDate = day.date.add(Duration(days: offset));
          final windowStart = DateTime(
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            hour,
            minute,
          );
          final windowEnd = windowStart.add(Duration(hours: _windowHours[slot]));
          final id = _uniqueReminderId(reminderDate, slot: slot);

          if (now.isAfter(windowStart) && now.isBefore(windowEnd)) {
            if (_delivered.contains(id)) continue;
            _delivered.add(id);
            await ReminderStore.setDeliveredIds(_delivered);

            final rel = offset == 0 ? 'today' : 'tomorrow';
            final content = _slotContent(allBinLabels, rel, slot);

            debugPrint('[Notif]   deliver #$id "${content.title}" '
                'window=$windowStart..$windowEnd');

            await _plugin.show(
              id,
              content.title,
              content.body,
              await _notificationDetails(),
              payload: 'reminder_$councilSlug',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] backgroundFetchCheck error: $e');
    }
  }

  /// Whether this app is exempt from battery optimization. OEM battery
  /// managers (Samsung, Xiaomi, etc.) otherwise defer or drop this app's
  /// alarms when it's swiped away from recents.
  static Future<bool?> isIgnoringBatteryOptimizations() async {
    try {
      return await _batteryChannel.invokeMethod<bool>(
          'isIgnoringBatteryOptimizations');
    } catch (_) {
      return null;
    }
  }

  /// Opens the system "battery optimization" app list so the user can set
  /// Derby Bins to "Don't optimize".
  static Future<bool> openBatterySettings() async {
    try {
      return await _batteryChannel.invokeMethod<bool>('openBatterySettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel(int id) async {
    _delivered.remove(id);
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    _delivered.clear();
    _deliveredLoaded = false;
    await ReminderStore.setDeliveredIds({});
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // flutter_local_notifications v18 can crash with "Missing type
      // parameter" when stale scheduled notifications from an older
      // version exist. Nothing to cancel, so we move on.
    }
  }

  /// Unique per (reminder date, slot) so multiple one-shot alarms don't
  /// share a PendingIntent â€” AlarmManager cancels any existing alarm whose
  /// PendingIntent matches. Ids are deterministic per collection day +
  /// slot, so a multi-bin day reuses one id per slot instead of duplicating.
  /// dayKey is DST-safe (calendar fields, not epoch days); ids are small
  /// positive ints well under 2^29 for dates around 2026-2030, so they can
  /// never collide with legacy binLabel-hashed ids from the old scheme.
  static int _uniqueReminderId(DateTime reminderDate, {required int slot}) {
    assert(slot >= 0 && slot < 3, 'slot must be 0..2');
    final dayKey =
        reminderDate.year * 10000 + reminderDate.month * 100 + reminderDate.day;
    return dayKey * 4 + slot;
  }

  /// Title/body for a reminder slot. `rel` is the relative collection
  /// label ("tomorrow" for the day-before slots, "today" for the
  /// day-of slot). All bin labels for the day are passed so multi-bin
  /// days share one combined message.
  static ({String title, String body}) _slotContent(
    List<String> allBinLabels,
    String rel,
    int slot,
  ) {
    final multipleBins = allBinLabels.length > 1;
    final binLabel = allBinLabels.first;
    final binNames = allBinLabels
        .map((label) => label.replaceAll(' bin', ''))
        .join(' and ');

    if (slot == 0) {
      // Lunchtime the day before â€” heads-up.
      final title = multipleBins ? 'Bin day $rel' : '$binLabel $rel';
      final body = multipleBins
          ? 'Put your $binNames bins out before 7am $rel.'
          : 'Put your $binLabel out before 7am $rel.';
      return (title: title, body: body);
    }

    if (slot == 1) {
      // Evening the day before â€” final nudge.
      final title = multipleBins ? 'Bins $rel' : '$binLabel $rel';
      final body = multipleBins
          ? 'Put your $binNames bins out before 7am $rel.'
          : 'Put your $binLabel out before 7am $rel.';
      return (title: title, body: body);
    }

    // Slot 2 â€” morning-of, collection day itself.
    final title = multipleBins ? 'Bin day today' : '$binLabel today';
    final body = multipleBins
        ? 'Your $binNames bins are collected today.'
        : 'Your $binLabel is collected today.';
    return (title: title, body: body);
  }

  /// Whether the device can schedule exact alarms (granted by default on
  /// Android <= 13; user-granted on Android 14+).
  static Future<bool> exactAlarmsAllowed() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<AndroidScheduleMode> _scheduleMode() async {
    final exact = await exactAlarmsAllowed();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    debugPrint('[Notif] scheduleMode: exactAllowed=$exact â†’ $mode');
    return mode;
  }

  /// Opens the system "Alarms & reminders" special-access page. Android-only.
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Plugin can throw (e.g. a request already in progress). The user can
      // still reach "Alarms & reminders" from system settings.
    }
  }

  /// On app resume: if reminders are on and the user just granted exact-alarm
  /// access, reschedule in exact mode so alerts fire on time.
  static Future<void> maybeRescheduleIfExactAlarmGranted() async {
    if (_rescheduling) return;
    _rescheduling = true;
    try {
      if (!await ReminderStore.isEnabled()) return;
      if (_lastExact) return;
      if (!await exactAlarmsAllowed()) return;
      final area = await ReminderStore.getCachedArea();
      final slug = await ReminderStore.getCachedCouncilSlug();
      if (area == null || slug == null) return;
      debugPrint('[Notif] exact alarms now permitted - rescheduling on-time reminders');
      await scheduleReminders(area, slug);
    } catch (e) {
      debugPrint('[Notif] maybeRescheduleIfExactAlarmGranted error: $e');
      // Swallow: this runs on app resume and must not crash or escape to the zone.
    } finally {
      _rescheduling = false;
    }
  }

  static Future<void> scheduleReminders(
      AreaSchedule area, String councilSlug) async {
    await init();
    await configureBackgroundFetch();
    final enabled = await ReminderStore.isEnabled();
    if (!enabled) return;

    await ReminderStore.cacheArea(area);
    await ReminderStore.cacheCouncilSlug(councilSlug);

    final scheduleMode = await _scheduleMode();
    _lastExact = scheduleMode == AndroidScheduleMode.exactAllowWhileIdle;
    final now = DateTime.now();
    final collectionDays = getNextCollectionDays(area, 8, now);
    final slotDesc = reminderSlots
        .map((s) => '${s.$1}:${s.$2}@${s.$3 >= 0 ? 'same day' : 'day before'}')
        .join(', ');
    debugPrint('[Notif] scheduleReminders: enabled=$enabled '
        'slots=$slotDesc now=$now days=${collectionDays.length} '
        'slug=$councilSlug');

    for (final day in collectionDays) {
      final allBinLabels = day.collections
          .map((c) => CouncilScheme.resolve(councilSlug, c.stream).label)
          .toList();
      for (var slot = 0; slot < reminderSlots.length; slot++) {
        final (hour, minute, offset) = reminderSlots[slot];
        final reminderDate = day.date.add(Duration(days: offset));
        final scheduled = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          hour,
          minute,
        );

        if (scheduled.isBefore(now)) continue;

        final rel = offset == 0 ? 'today' : 'tomorrow';
        final content = _slotContent(allBinLabels, rel, slot);
        final id = _uniqueReminderId(reminderDate, slot: slot);

        // Best-effort zonedSchedule
        final tzWhen = tz.TZDateTime.from(scheduled, tz.local);
        debugPrint('[Notif]   schedule #$id "${content.title}" '
            'local=$scheduled tz=${tzWhen.toIso8601String()} mode=$scheduleMode');
        try {
          await _plugin.zonedSchedule(
            id,
            content.title,
            content.body,
            tzWhen,
            await _notificationDetails(),
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'reminder_$councilSlug',
          );
          debugPrint('[Notif]   OK #$id');
        } on PlatformException catch (e) {
          if (e.code == 'exact_alarms_not_permitted' &&
              scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
            debugPrint('[Notif]   exact denied, retrying inexact #$id');
            try {
              await _plugin.zonedSchedule(
                id,
                content.title,
                content.body,
                tzWhen,
                await _notificationDetails(),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                payload: 'reminder_$councilSlug',
              );
              debugPrint('[Notif]   OK #$id (inexact)');
              _lastExact = false;
            } catch (e2) {
              debugPrint('[Notif]   inexact retry error #$id: $e2');
            }
          } else {
            debugPrint('[Notif]   zonedSchedule error #$id: $e');
          }
        } catch (e) {
          debugPrint('[Notif]   zonedSchedule error #$id: $e');
        }
      }
    }
  }
}