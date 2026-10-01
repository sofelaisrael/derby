# Scheduled notifications not delivered after the app is swiped away (Android OEM process governor)

App: Derby Bins, `uk.co.derbybins.app`
Test device: TECNO BF6, Android 12 (API 31), Transsion "Griffin" process governor.

Claim labels used throughout: **MEASURED** (from a log, adb output, or quoted source in this repo), **INFERRED** (reasoning from measured facts), **UNVERIFIED** (hypothesis, not tested).

## 1. Symptom

**MEASURED** Scheduled local notifications deliver while the app process is alive or the app is foregrounded. They do not arrive after the app has been swiped out of recents, which also kills the process.

**MEASURED** Force-stop is a *different* and expected failure mode, and is not what is being investigated here. Force-stop cancels all alarms registered by the app by design; the OS removes the app's registered alarms and does not reschedule them. Swipe-away leaves the registered alarms intact but terminates the process, so the OS still holds the alarm and still fires it. The swipe-away case is the defect.

## 2. Architecture

**MEASURED**, read from `lib/services/notification_service.dart`. There are two independent delivery mechanisms, and they have different survival properties.

| Mechanism | Location | Delivers via | Survives process death |
| --- | --- | --- | --- |
| `scheduleReminders` | line 687 | `zonedSchedule`, 3 alarms x 8 collection days | Yes, alarm is held by AlarmManager |
| `backgroundFetchCheck` | line 356 | `show()`, on a 15-min `background_fetch` poll | No, requires a live process |

- **MEASURED** `scheduleReminders` builds a `zonedSchedule` call per slot per collection day. `getNextCollectionDays(area, 8, now)` (line 707) yields 8 days, and 3 slots each, so up to 24 alarms per reschedule. On Android this is handed to AlarmManager; on iOS to `UNTimeIntervalNotificationTrigger`.
- **MEASURED** `backgroundFetchCheck` is the 15-minute `background_fetch` callback. It re-checks pending reminders and calls `show()`, so it only works while a process exists.
- **MEASURED** Plugin config at lines 325-332: `minimumFetchInterval: 15`, `stopOnTerminate: false`, `enableHeadless: true`, `forceAlarmManager: true`, `startOnBoot: true`.
- **MEASURED** The headless task is registered in `lib/main.dart` line 19 via `BackgroundFetch.registerHeadlessTask`.
- **MEASURED** Boot survival is handled by `ScheduledNotificationBootReceiver`, declared in `android/app/src/main/AndroidManifest.xml` lines 49-58 for `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, and `com.htc.intent.action.QUICKBOOT_POWERON`.
- **MEASURED** Duplicate suppression: `static Set<int> _delivered` (line 60) is loaded from and persisted through `ReminderStore` (`lib/services/reminder_store.dart`) at lines 370-372 and 403-405. The 15-minute poll checks `if (_delivered.contains(id)) continue;` so it does not re-show a reminder that AlarmManager already fired.
- **MEASURED** `reminderSlots = [(12, 0, -1), (20, 0, -1), (7, 0, 0)]` (line 23): 12:00 and 20:00 on the day before collection, 07:00 on the collection day. `_windowHours = [4, 4, 2]` (line 24) is the look-back window per slot used by the poll.
- **MEASURED** Reminder ID scheme, `_uniqueReminderId` (line 480): `dayKey * 4 + slot` where `dayKey` is `YYYYMMDD`. The channel ID is `_channelId = 'bin_reminders_v2'` (line 16).
- **MEASURED** Note for readers reproducing the log in the next section: the single-shot test helpers use a separate fixed ID, `_singleShotTimedTestId = 960001` (line 530), not the `_uniqueReminderId` scheme. Test IDs and production reminder IDs are distinct namespaces.

## 3. Measured: the app side is correct

**MEASURED** `adb logcat` during a 2-minute scheduled test, on the test device:

```
[Notif] single test +2min: #960001 permissionGranted=true
        fireAt=2026-09-30 13:30:19.040231 mode=AndroidScheduleMode.exactAllowWhileIdle
AlarmManager: set(PendingIntent{ee83b1f ... uk.co.derbybins.app broadcastIntent})
AlarmManager: sending alarm.type = 0,
        cn = ComponentInfo{uk.co.derbybins.app/...ScheduledNotificationReceiver}
```

**MEASURED** The alarm fired 11 ms *early* relative to the target time. `exactAllowed=true` and `permissionGranted=true` in the same run. `alarm.type = 0` is `RTC_WAKEUP`.

**MEASURED** `adb shell dumpsys alarm`, taken later after the app had been used, comparing against the working reference app Notts Bins (`uk.co.nottsbins.app`):

| Package | Pending intents | Alarm entries |
| --- | --- | --- |
| `derbybins` | 22 | 84 |
| `notts` | 25 | 76 |

**INFERRED** Scheduling works, and Derby registers at least as many alarm entries as an app that works. The failure is not a failure to schedule.

## 4. Measured: the failure point

**MEASURED** Immediately after the on-time alarm send in the same log:

```
Griffin/ComponentManager: Limit sendBroadcastP:Intent {
    cmp=uk.co.derbybins.app/...ScheduledNotificationReceiver (has extras) } for 3rd-died
ActivityManager: Limit sendBroadcastInPackage for Intent {
    cmp=uk.co.derbybins.app/...ScheduledNotificationReceiver }, ordered=true
```

**MEASURED** Process death and restart throttling, immediately prior:

```
ActivityManager: Killing 12790:uk.co.derbybins.app/u0a510 (adj 800): remove task
Griffin/ComponentManager: Limit Start proc uk.co.derbybins.app restart for 3rd-normal
Griffin/RecentClean: killBackgroundProcesses for uk.co.derbybins.app recent-7
```

**INFERRED** From the pairing and ordering: Android accepted the alarm and fired it on time, then the Transsion vendor governor refused to start the app process needed to receive the broadcast. The governor log line appears immediately after the on-time `sendBroadcast`, and the kill/throttle lines show the process had been taken down for the swipe-away with a restart counter already incremented.

**INFERRED** This is not an AOSP background-execution-limit failure. The broadcast is an *explicit* broadcast to a manifest-declared receiver, and AOSP exempts explicit broadcasts from background execution limits. The refusal comes from vendor policy layered on top, not from the platform rule the plugin would be violating.

## 5. Ruled out

Each item below was investigated and eliminated. Recorded so they are not re-investigated.

| Theory | Evidence that eliminated it | Verdict |
| --- | --- | --- |
| Missing broadcast receivers | Plugin 18.0.1 declares no receivers in its own manifest; the app must declare them. Derby declares `ActionBroadcastReceiver`, `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver` (AndroidManifest lines 43-58). Installed package dump confirms `ScheduledNotificationBootReceiver` registered. | Not the bug |
| Missing runtime permissions | `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED` all `granted=true` via `dumpsys package`. | Not the bug |
| Exact-alarm permission denied | `exactAllowed=true` in log, and the alarm fired on time (11 ms early). | Not the bug |
| Resource shrinking strips `ic_notification` | Was a real bug, fixed by `shrink=false` (commit `c0bf03a`). Already resolved, and separate from this issue. | Fixed previously |
| `initScheduled` flag differs | Identical in the reference app. Not a differentiator. | Not the bug |
| Any code difference vs the working reference app | Verified byte-identical: plugin versions (same sha256 in both `pubspec.lock`), `main()` startup, `_scheduleMode`, `zonedSchedule` arguments, `reminderSlots`, `_windowHours`, `_uniqueReminderId`, `_channelId`, and the `cancelAll` / `scheduleReminders` / `maybeRescheduleIfExactAlarmGranted` call graph. Installed granted permissions match. Installed standby bucket: derby 10 (ACTIVE), notts 20 (WORKING_SET). | No meaningful difference found |
| Migrating to Awesome Notifications | Verified from its source that it uses the identical OS primitive: `alarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP, t, PendingIntent.getBroadcast(...))` into a manifest-declared `BroadcastReceiver` in `NotificationScheduler.java`. Its WorkManager path exists but is commented out, with the author's stated reason in the source. | Would hit the identical wall; rejected as churn |

**INFERRED** The Awesome Notifications finding matters beyond that library: the app is not blocked by a plugin choice. Anything that ultimately lands on `setExactAndAllowWhileIdle` plus an explicit broadcast reaches the same governor decision.

## 6. Upstream positions

Cited, not paraphrased.

- `flutter_local_notifications` README: scheduled notifications may not work in the background on certain OEMs, with Xiaomi and Huawei cited as examples. "As it's a restriction imposed by the OS, this is not something that can be resolved by the plugin."
- Maintainer, in issue #2737: "To be upfront, there's nothing further this plugin can do."
- `flutter_workmanager` troubleshooting docs: "No plugin can override the OEM's battery manager."
- dontkillmyapp.com/tecno, Tecno ranked #15 worst: the aggressive battery setting leaves apps "completely halted, like frozen in time, so, timers, services, foreground services, all of them stop working". Under "Solution for devs": "No known solution on the developer end."

## 7. Conclusion

**MEASURED + INFERRED** The notification stack in this app is correctly configured, and is measured to register alarms and have them fire on time. The failure after process death happens *after* the alarm fires: the OEM process governor refuses to start the app to receive the broadcast.

**INFERRED** No change to Dart code, the manifest, or the notification plugin can intercept or override a vendor decision made at that layer. The device's own documentation states there is no developer-side solution. The remaining levers are user-side or out-of-band:

1. Battery-optimisation exemption, via `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, now wired in `MainActivity.kt`.
2. Tecno/Transsion auto-start management, and locking the app in recents. No Android API exposes this; it is a manual user action.
3. Avoiding force-stop, which permanently cancels all alarms.

**UNVERIFIED** That any of these three actually restores delivery on this device. The exemption path was unreachable in the build that was tested (see the corrections section), so lever 1 has never been exercised against this symptom.

## 8. Not tested / open

- **UNVERIFIED** No end-to-end check that a real reminder at 12:00, 20:00, or 07:00 arrives after the app is swiped away with the battery exemption granted. This is the first thing to run.
- **UNVERIFIED** iOS was never tested on a device. Research indicates iOS is structurally unaffected, because `UNTimeIntervalNotificationTrigger` is held by the OS notification daemon, there is no per-app power governor, and there is no equivalent to AlarmManager process gating. Expectation only.
- **UNVERIFIED** Push notifications via FCM were considered and not adopted. **INFERRED** they would work around the governor, because Play Services posts the notification without the app process starting, and Play Services was confirmed present on the test device (`com.google.android.gms`). Not adopted because it needs a server-side scheduler and network at delivery time, so it fails offline, making it a second channel rather than a replacement.

## 9. Corrections made during this investigation

Recorded because they are more useful to a future reader than omitting them. The first four were false claims made during the investigation and later disproven.

- "Mansfield/Derby differ in battery-optimisation code." **FALSE.** Both apps have identical `isIgnoringBatteryOptimizations` / `openBatterySettings` implementations. The reference app also has no test buttons at all, so it was never actually tested post-swipe the way Derby was. The comparison was not like-for-like.
- "Derby is on standby bucket restricted, Mansfield active." **FALSE, and reversed.** derby is 10 (ACTIVE), notts is 20 (WORKING_SET).
- "Derby has 0 pending intents vs Mansfield 25." **FALSE.** Caused by reading a truncated grep result as a finding. Actual: 22 vs 25.
- "No Google Play Services on the test device." **FALSE.** Caused by querying adb with the phone disconnected, and reading empty output as a positive fact. Play Services is present.
- "Derby ships `minimumFetchInterval: 1` as a leftover debug value." **FALSE as a shipped-code claim.** The `1` was an uncommitted working-tree edit only; committed HEAD has 15. **MEASURED** current source, line 327, is `minimumFetchInterval: 15`.
- "The 'Keep reminders reliable' tile throws `MissingPluginException`." **TRUE, and a real bug.** `MainActivity.kt` was a bare `FlutterActivity` with no `MethodChannel` handler while Dart called the `derbybins/battery` channel. Fixed in commit `bede19c`. Consequence worth noting: the battery exemption was unreachable in the build that was tested, so the earlier test could not have granted it. Any conclusion drawn from that test about the exemption is void.

## 10. Related fixes shipped

- **`bede19c`** — added the `derbybins/battery` `MethodChannel` handler in `MainActivity.kt`: `isIgnoringBatteryOptimizations` via `PowerManager`, and `openBatterySettings` via `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` with a `package:` URI, falling back to `ACTION_APPLICATION_DETAILS_SETTINGS` and then `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`. Declared `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. Removed the notification test section and its helpers.
- **Uncommitted** — `runSingleTestNow` / `runSingleTestInMinutes` restored without the previous cancel-then-reschedule call; `_initFailed` / `_initError` logging so a failed plugin initialise is greppable rather than silent; `scheduleReminders` and `backgroundFetchCheck` bail early with a clear log instead of swallowing one exception per alarm.

**MEASURED** The `bede19c` handler, the `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` declaration, the `_initFailed` bail-outs, and `minimumFetchInterval: 15` are all present in the current working tree. The last group is uncommitted, so it is not in `bede19c` and is not reflected on the test device.
