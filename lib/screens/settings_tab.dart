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
    final batteryOptimized = await NotificationService.isIgnoringBatteryOptimizations();
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
                            dark ? sheetColors.textPrimary : Colors.white,
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
      await NotificationService.scheduleReminders(widget.area, widget.councilSlug);
      if (gen != _toggleGeneration) return;
      if (mounted && Platform.isAndroid && !await NotificationService.exactAlarmsAllowed()) {
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
          'Exact alarms are currently off for DerbyBins, so reminders may '
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final councilWebsite = CouncilApi.websiteFor(widget.councilSlug);
    return Scaffold(
      body: SafeArea(
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
                        Text('Current address',
                            style: AppTypography.caption),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.addressLabel ?? widget.area.areaName,
                          style: AppTypography.title,
                        ),
                        const SizedBox(height: 2),
                        Text(widget.postcode,
                            style: AppTypography.caption),
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
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
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
                  backgroundColor: context.binColors.primaryLight,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : context.binColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
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
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
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
                        presentation:
                            CouncilScheme.resolve(widget.councilSlug, s.stream),
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
                              '${weekdayNames[s.dayOfWeek - 1]} · ${frequencyLabel[s.frequency]}',
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
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
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
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6))],
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
                                  : 'Allow DerbyBins to run in the background so reminders fire even after you swipe the app away.',
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
                          final updated =
                              await NotificationService.isIgnoringBatteryOptimizations();
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

            // ── Appearance ──────────────────────────
            _SectionLabel('Appearance'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: context.binColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6))],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Dark mode',
                          style: AppTypography.title),
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
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6))],
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
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6))],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appName, style: AppTypography.title),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Bin collection schedule',
                        style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.binColors.background,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
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
      ),
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