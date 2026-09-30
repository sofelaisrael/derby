import '../main.dart';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../services/council_api.dart';
import '../services/notification_service.dart';
import '../services/reminder_store.dart';
import '../services/schedule_service.dart';
import '../services/session_store.dart';
import '../services/theme_service.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_background.dart';
import '../widgets/bin_badge.dart';
import '../widgets/centered_dialog.dart';
import 'bin_guide_screen.dart';
import 'report_missing_bin_screen.dart';

class SettingsTab extends StatefulWidget {
  final String postcode;
  final String councilSlug;
  final String councilName;
  final String? addressLabel;
  final AreaSchedule area;
  final bool isLive;
  final ThemeService? themeService;

  const SettingsTab({
    super.key,
    required this.postcode,
    required this.councilSlug,
    required this.councilName,
    this.addressLabel,
    required this.area,
    required this.isLive,
    this.themeService,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const _privacyPolicyUrl = 'https://derbybins.web.app/privacy';
  bool _remindersEnabled = false;
  bool _loading = true;
  int _toggleGeneration = 0;
  bool? _batteryOptimized;

  void _showSnack(String message) {
    showCenteredPopup(context, message);
  }

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final enabled = await ReminderStore.isEnabled();
    final batteryOptimized =
        await NotificationService.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() {
        _remindersEnabled = enabled;
        _batteryOptimized = batteryOptimized;
        _loading = false;
      });
    }
  }

  Future<void> _toggleReminder(bool value) async {
    final gen = ++_toggleGeneration;
    setState(() => _remindersEnabled = value);

    if (value) {
      // Guideline 5.1.1(iv): informational pre-permission — always hand off to system dialog.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final sheetColors = ctx.binColors;
          final dark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            decoration: BoxDecoration(
              color: dark
                  ? AppColorsDark.surfaceElevated
                  : sheetColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: sheetColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: sheetColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 28,
                      color: sheetColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bin day reminders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: sheetColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A reminder the evening before each collection and a heads-up on the morning. You can turn this off anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: sheetColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: dark
                            ? Colors.white.withValues(alpha: 0.9)
                            : sheetColors.primary,
                        foregroundColor:
                            dark ? AppColorsDark.background : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      // Always show system dialog after custom explanation.
      final granted = await NotificationService.requestPermissions();
      if (gen != _toggleGeneration) return;
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Notification permission is off. Enable it in Settings to receive reminders.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => NotificationService.openAppSettings(),
            ),
          ),
        );
        setState(() => _remindersEnabled = false);
        await ReminderStore.setEnabled(false);
        return;
      }
      await ReminderStore.setEnabled(true);
      await NotificationService.scheduleReminders(
          widget.area, widget.councilSlug);
      if (gen != _toggleGeneration) return;
      if (mounted &&
          Platform.isAndroid &&
          !await NotificationService.exactAlarmsAllowed()) {
        await _maybePromptExactAlarms();
      }
    } else {
      await NotificationService.cancelAll();
      await ReminderStore.setEnabled(false);
    }
  }

  Future<void> _maybePromptExactAlarms() async {
    if (await ReminderStore.exactAlarmPromptDismissed()) return;
    if (!mounted) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.binColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: context.binColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text('On-time reminders',
            style: AppTypography.title
                .copyWith(color: context.binColors.textPrimary)),
        content: Text(
          'Exact alarms are currently off for Derby Bins, so reminders may '
          'be delayed in low-power modes. Allow "Alarms & reminders" in '
          'system settings for on-time alerts.',
          style: AppTypography.body
              .copyWith(color: context.binColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Don't ask again",
                style: AppTypography.body
                    .copyWith(color: context.binColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Open settings',
                style: AppTypography.body
                    .copyWith(color: context.binColors.primary)),
          ),
        ],
      ),
    );
    if (openSettings == null) return;
    if (openSettings) {
      await NotificationService.openExactAlarmSettings();
    } else {
      await ReminderStore.setExactAlarmPromptDismissed(true);
    }
  }

  Future<void> _runNotificationWordingTest() async {
    final WordingTestResult result = await NotificationService.runWordingTest();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.binColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: ctx.binColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(
          'Test now — wording',
          style: AppTypography.title.copyWith(color: ctx.binColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.permissionGranted
                    ? 'Permission granted. ${result.fired.length} notifications sent.'
                    : 'Permission NOT granted, so nothing will appear. Wording:',
                style: AppTypography.caption.copyWith(
                  color: ctx.binColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This checks the wording and the permission only. These arrived '
                'instantly, so it does not prove scheduled alarms work — use '
                '"Test in 2 min" for that.',
                style: AppTypography.caption.copyWith(
                  color: ctx.binColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var slot = 0; slot < result.fired.length; slot++)
                _wordingTestSlotRow(ctx, slot, result.fired[slot]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: AppTypography.body.copyWith(color: ctx.binColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runScheduledNotificationTest(Duration delay) async {
    final ScheduledTestResult result =
        await NotificationService.runScheduledTest(
            delays: [delay, delay, delay]);
    if (!mounted) return;
    final delayLabel = '${delay.inMinutes} min';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.binColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: ctx.binColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(
          'Test in $delayLabel — alarms',
          style: AppTypography.title.copyWith(color: ctx.binColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _scheduledTestFact(
                ctx,
                'Permission',
                result.permissionGranted
                    ? 'granted'
                    : 'NOT granted, so nothing will appear',
              ),
              _scheduledTestFact(
                ctx,
                'Exact alarms',
                result.exactAllowed
                    ? 'allowed'
                    : 'not allowed, so these may be delayed',
              ),
              _scheduledTestFact(
                ctx,
                'Scheduled with',
                result.usedExact
                    ? 'exact alarms'
                    : 'inexact alarms, so these may arrive late',
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final slot in result.slots) _scheduledTestSlotRow(ctx, slot),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'These are test alarms, not real bin reminders, and they are '
                'temporary. Running either timed test cancels the previous set '
                'first, and "Cancel test alarms" below clears them now.',
                style: AppTypography.caption.copyWith(
                  color: ctx.binColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.cancelScheduledTestAlarms();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(
              'Cancel test alarms',
              style:
                  AppTypography.body.copyWith(color: ctx.binColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: AppTypography.body.copyWith(color: ctx.binColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduledTestFact(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label: $value',
        style: AppTypography.caption.copyWith(
          color: ctx.binColors.textSecondary,
        ),
      ),
    );
  }

  Widget _scheduledTestSlotRow(BuildContext ctx, ScheduledTestSlotResult sent) {
    final minutesAway = sent.fireAt.difference(DateTime.now()).inMinutes + 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Slot ${sent.slot} · fires ${_clockLabel(sent.fireAt)} '
            '(in about $minutesAway min)',
            style: AppTypography.title.copyWith(
              color: ctx.binColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sent.error != null
                ? 'Failed — ${sent.error}'
                : sent.usedInexactFallback
                    ? 'Scheduled, fell back to inexact — "${sent.title}" / ${sent.body}'
                    : 'Scheduled — "${sent.title}" / ${sent.body}',
            style: AppTypography.body.copyWith(
              color: ctx.binColors.textSecondary,
            ),
          ),
          const Divider(height: AppSpacing.md),
        ],
      ),
    );
  }

  String _clockLabel(DateTime when) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(when.hour)}:${two(when.minute)}:${two(when.second)}';
  }

  Widget _wordingTestSlotRow(
    BuildContext ctx,
    int slot,
    WordingSample sent,
  ) {
    final single = NotificationService.wordingTestPreview(
      slot,
      multipleBins: false,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Slot $slot · ${_slotTimeLabel(slot)}',
            style: AppTypography.title.copyWith(
              color: ctx.binColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Sent — "${sent.title}" / ${sent.body}',
            style: AppTypography.body.copyWith(
              color: ctx.binColors.textSecondary,
            ),
          ),
          Text(
            'One bin — "${single.title}" / ${single.body}',
            style: AppTypography.body.copyWith(
              color: ctx.binColors.textSecondary,
            ),
          ),
          const Divider(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _notificationTestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Notification tests'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Developer controls. "Test now" checks the wording of all three '
          'reminders immediately. The timed ones set real alarms so you can '
          'check that scheduled notifications actually arrive.',
          style: AppTypography.caption.copyWith(
            color: context.binColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _notificationTestButton(
          label: 'Test now',
          icon: Icons.notifications_active_outlined,
          filled: true,
          onPressed: () => _runNotificationWordingTest(),
        ),
        const SizedBox(height: AppSpacing.sm),
        _notificationTestButton(
          label: 'Test in 2 min',
          icon: Icons.timer_outlined,
          onPressed: () => _runScheduledNotificationTest(
            const Duration(minutes: 2),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _notificationTestButton(
          label: 'Test in 10 min',
          icon: Icons.schedule_outlined,
          onPressed: () => _runScheduledNotificationTest(
            const Duration(minutes: 10),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _cancelScheduledNotificationTests,
            style: TextButton.styleFrom(
              foregroundColor: context.binColors.textMuted,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            child: Text(
              'Cancel test alarms',
              style: AppTypography.body.copyWith(
                color: context.binColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notificationTestButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: filled
              ? (dark ? AppColors.primary : context.binColors.primary)
              : context.binColors.surfaceElevated,
          foregroundColor:
              filled ? Colors.white : context.binColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: filled
                ? BorderSide.none
                : BorderSide(color: context.binColors.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelScheduledNotificationTests() async {
    await NotificationService.cancelScheduledTestAlarms();
    if (!mounted) return;
    _showSnack('Test alarms cancelled.');
  }

  Widget _appNameLabel() {
    return Text(appName, style: AppTypography.title);
  }

  String _slotTimeLabel(int slot) {
    final (hour, minute, dayOffset) = reminderSlots[slot];
    final time = '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
    return '$time ${dayOffset == 0 ? 'collection day' : 'day before'}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: ScreenBackground(
          child: SafeArea(
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    final councilWebsite = CouncilApi.websiteFor(widget.councilSlug);
    return Scaffold(
      body: ScreenBackground(
          child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.binColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: context.binColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Settings', style: AppTypography.h1),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Address ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.binColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.binColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.location_on_outlined,
                          size: 20, color: context.binColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current address', style: AppTypography.caption),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.addressLabel ?? widget.area.areaName,
                            style: AppTypography.title,
                          ),
                          if (widget.postcode.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(widget.postcode, style: AppTypography.caption),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                Icons.business_outlined,
                                size: 14,
                                color: context.binColors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(widget.councilName,
                                    style: AppTypography.caption,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.isLive
                                      ? context.binColors.primaryLight
                                      : context.binColors.background,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  widget.isLive ? 'Live' : 'Demo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: widget.isLive
                                        ? Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : context.binColors.primary
                                        : context.binColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Change address ───────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _changeAddress(context),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.primary
                            : context.binColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_location_alt_outlined, size: 18),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Change address',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Report an issue ─────────────────────
              _SectionLabel('Bin schedules'),
              const SizedBox(height: AppSpacing.sm),
              ...widget.area.schedules.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.binColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 12,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      children: [
                        BinBadge(
                          presentation: CouncilScheme.resolve(
                              widget.councilSlug, s.stream),
                          size: 36,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  CouncilScheme.resolve(
                                          widget.councilSlug, s.stream)
                                      .label,
                                  style: AppTypography.title),
                              const SizedBox(height: 2),
                              Text(
                                '${weekdayNames[effectiveWeekday(s) - 1]} · ${frequencyLabel[s.frequency]}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: AppSpacing.xl),

              // ── Bin guide ──────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BinGuideScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: context.binColors.surfaceElevated,
                    foregroundColor: context.binColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      side: BorderSide.none,
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.recycling_outlined, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'Bin guide',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Reminders ────────────────────────────
              _SectionLabel('Reminders'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: context.binColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text('Enable reminders',
                            style: AppTypography.title),
                        subtitle: Text(
                          "A reminder the evening before and a heads-up on the morning",
                          style: AppTypography.caption,
                        ),
                        value: _remindersEnabled,
                        activeTrackColor:
                            context.binColors.primary.withValues(alpha: 0.3),
                        activeThumbColor: context.binColors.primary,
                        onChanged: _toggleReminder,
                      ),
                      Divider(height: 1, color: context.binColors.borderLight),
                      if (!Platform.isIOS)
                        ListTile(
                          title: Text('Keep reminders reliable',
                              style: AppTypography.title),
                          subtitle: Text(
                            _batteryOptimized == null
                                ? 'Check battery optimisation'
                                : _batteryOptimized!
                                    ? 'Battery optimisation is off — reminders can run in the background.'
                                    : 'Allow Derby Bins to run in the background so reminders fire even after you swipe the app away.',
                            style: AppTypography.caption,
                          ),
                          trailing: Icon(
                            Icons.battery_saver,
                            size: 20,
                            color: _batteryOptimized == true
                                ? context.binColors.primary
                                : context.binColors.textMuted,
                          ),
                          onTap: () async {
                            await NotificationService.openBatterySettings();
                            final updated = await NotificationService
                                .isIgnoringBatteryOptimizations();
                            if (mounted) {
                              setState(() => _batteryOptimized = updated);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              _notificationTestsSection(),
              const SizedBox(height: AppSpacing.xl),

              // ── Appearance ──────────────────────────
              _SectionLabel('Appearance'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: context.binColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text('Dark mode', style: AppTypography.title),
                        subtitle: Text(
                          'Easier on the eyes at night',
                          style: AppTypography.caption,
                        ),
                        value: widget.themeService?.isDark ?? false,
                        activeTrackColor:
                            context.binColors.primary.withValues(alpha: 0.3),
                        activeThumbColor: context.binColors.primary,
                        onChanged: widget.themeService != null
                            ? (_) => widget.themeService!.toggle()
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Report an issue ─────────────────────
              _SectionLabel('Report an issue'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: context.binColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.binColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.report_problem_outlined,
                              size: 18, color: context.binColors.textMuted),
                        ),
                        title: Text('Report a problem',
                            style: AppTypography.title),
                        subtitle: Text(
                          'Missing bin, wrong collection, or damaged bin',
                          style: AppTypography.caption,
                        ),
                        trailing: Icon(Icons.chevron_right,
                            size: 18, color: context.binColors.textMuted),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportMissingBinScreen(
                                postcode: widget.postcode,
                                councilName: widget.councilName,
                                addressLabel: widget.addressLabel,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── About ────────────────────────────────
              _SectionLabel('About'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.binColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 18,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _appNameLabel(),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Bin collection schedule',
                          style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: context.binColors.background,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          supportedCouncilsText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.binColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (councilWebsite != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        GestureDetector(
                          onTap: () async {
                            final opened = await launchUrl(
                              Uri.parse(councilWebsite),
                              mode: LaunchMode.externalApplication,
                            );
                            if (!opened && mounted) {
                              _showSnack('Could not open the council website.');
                            }
                          },
                          child: Text(
                            councilWebsite.replaceFirst('https://www.', ''),
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color: context.binColors.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      Text(
                        'Not affiliated with or endorsed by any council.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: context.binColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Privacy policy',
                            style: AppTypography.title),
                        subtitle: const Text(
                          'How your data is handled',
                          style: AppTypography.caption,
                        ),
                        trailing: Icon(Icons.open_in_new,
                            size: 16, color: context.binColors.textMuted),
                        onTap: _openPrivacyPolicy,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      )),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      Uri.parse(_privacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showSnack('Could not open the privacy policy.');
    }
  }

  void _changeAddress(BuildContext context) async {
    await NotificationService.cancelAll();
    await SessionStore.clear();
    clearResolveCache();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: context.binColors.textMuted,
      ),
    );
  }
}
