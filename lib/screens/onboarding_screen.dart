import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:derby_bins/services/notification_service.dart';
import 'package:derby_bins/services/onboarding_store.dart';
import 'package:derby_bins/services/reminder_store.dart';
import 'package:derby_bins/services/theme_service.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/banded_gradient.dart';

const _kickerLight = Color(0xFFA9714B);
const _kickerDark = Color(0xFFC08A5E);

double _seg(Animation<double> c, double a, double b,
    [Curve curve = Curves.easeOutCubic]) {
  final p = c.value;
  if (p <= a) return 0;
  if (p >= b) return 1;
  return curve.transform((p - a) / (b - a));
}

/// First-launch welcome flow: three animated steps (the kerb, the calendar,
/// the nudge) before the user lands in the app.
class OnboardingScreen extends StatefulWidget {
  final ThemeService? themeService;
  final VoidCallback onDone;

  const OnboardingScreen({super.key, this.themeService, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _lastStep = 2;

  bool _busy = false;
  int _step = 0;
  bool _everNavigated = false;
  bool? _remindersGranted; // null = still checking / show "Enable reminders"

  @override
  void initState() {
    super.initState();
    _checkPermissionState();
  }

  Future<void> _checkPermissionState() async {
    final granted = await NotificationService.notificationsPermissionGranted();
    if (mounted) setState(() => _remindersGranted = granted);
  }

  Future<void> _enableReminders() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Guideline 5.1.1(iv): pre-permission is informational only -- always hand off to system dialog.
    // Button is neutral ("Continue") so it doesn't mimic the system Allow/Don't Allow.
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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLg),
            ),
            border: Border.all(color: sheetColors.border),
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
                  'Get a reminder the evening before each collection and a heads-up on the morning. Local to your device, off anytime in Settings.',
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
                      backgroundColor: sheetColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    // Always show system dialog after custom explanation -- do not branch on Not Now.
    var granted = await NotificationService.notificationsPermissionGranted();
    if (!granted) {
      granted = await NotificationService.requestPermissions();
    }
    if (granted) {
      if (mounted) setState(() => _remindersGranted = true);
      await ReminderStore.setEnabled(true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No problem — you can enable reminders any time in Settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => NotificationService.openAppSettings(),
            ),
          ),
        );
      }
    }
    await OnboardingStore.setSeen();
    if (mounted) widget.onDone();
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await OnboardingStore.setSeen();
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_busy || _step >= _lastStep) return;
    _everNavigated = true;
    setState(() => _step++);
  }

  void _back() {
    if (_busy || _step == 0) return;
    _everNavigated = true;
    setState(() => _step--);
  }

  Widget _fadeTransition(Widget child, Animation<double> animation) {
    return FadeTransition(opacity: animation, child: child);
  }

  Widget _buildStepContent() {
    final artHeight = MediaQuery.sizeOf(context).height < 700 ? 150.0 : 200.0;
    final page = _StepPage(
      key: ValueKey('step-$_step'),
      step: _step,
      artHeight: artHeight,
    );
    if (!_everNavigated) {
      return _InitialEntrance(key: ValueKey('step-$_step'), child: page);
    }
    return page;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final switchDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              step: _step,
              busy: _busy,
              onBack: _back,
              onSkip: _skip,
            ),
            _SegmentedProgress(current: _step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.xl),
                child: AnimatedSwitcher(
                  duration: switchDuration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: _fadeTransition,
                  child: _buildStepContent(),
                ),
              ),
            ),
            _BottomCta(
              key: ValueKey('cta-$_step'),
              step: _step,
              busy: _busy,
              reduceMotion: reduceMotion,
              remindersGranted: _remindersGranted,
              onGetStarted: _next,
              onNext: _next,
              onEnable: _enableReminders,
              onNotNow: _skip,
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Top bar: brand mark + wordmark, back and skip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TopBar extends StatelessWidget {
  final int step;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _TopBar({
    required this.step,
    required this.busy,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
      child: Row(
        children: [
          if (step > 0)
            _RoundButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 17,
              onTap: busy ? null : onBack,
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: forestBandedGradient(
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.recycling_outlined,
                  size: 22, color: Colors.white),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'DerbyBins',
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (step < _OnboardingScreenState._lastStep)
            TextButton(
              onPressed: busy ? null : onSkip,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  final int current;

  const _SegmentedProgress({required this.current});

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const count = _OnboardingScreenState._lastStep + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: List.generate(count, (i) {
          final active = i <= current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: 32,
            height: 4,
            margin: EdgeInsets.only(right: i < count - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: active
                  ? (dark ? _kickerDark : colors.primary)
                  : colors.border,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          );
        }),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;

  const _RoundButton({
    required this.icon,
    required this.iconSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.borderLight),
        ),
        child: Icon(icon, size: iconSize, color: colors.textPrimary),
      ),
    );
  }
}

// â”€â”€â”€ Step page: entrance controller + staggered content â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StepPage extends StatefulWidget {
  final int step;
  final double artHeight;

  const _StepPage({super.key, required this.step, required this.artHeight});

  @override
  State<_StepPage> createState() => _StepPageState();
}

class _StepPageState extends State<_StepPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  Duration get _duration => switch (widget.step) {
        0 => const Duration(milliseconds: 2200),
        1 => const Duration(milliseconds: 1500),
        _ => const Duration(milliseconds: 1400),
      };

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kickerColor = dark ? _kickerDark : _kickerLight;

    final (kicker, title, body) = switch (widget.step) {
      0 => (
          'YOUR STREET',
          'Your bin days,\nwithout the rota.',
          'Black, blue, green, food caddy — which one goes out this week, for your street, at a glance.',
        ),
      1 => (
          'AT A GLANCE',
          'Everything,\nat a glance.',
          'The full year of collection days. A nudge the evening before. And a way to flag a missed bin in seconds.',
        ),
      _ => (
          'ONE MORE THING',
          'A nudge the\nevening before.',
          "We'll ask your permission before sending reminder notifications. You can choose whether to receive them.",
        ),
    };

    final (kickerA, kickerB, titleA, titleB, bodyA, bodyB) =
        switch (widget.step) {
      0 => (0.28, 0.44, 0.40, 0.62, 0.52, 0.70),
      1 => (0.26, 0.40, 0.34, 0.56, 0.44, 0.64),
      _ => (0.24, 0.38, 0.30, 0.52, 0.40, 0.60),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: _StagePanel(
            height: widget.artHeight,
            artBuilder: _buildArt,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _Stagger(
          controller: _controller,
          start: kickerA,
          end: kickerB,
          rise: 8,
          child: Text(
            kicker,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: kickerColor,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Stagger(
          controller: _controller,
          start: titleA,
          end: titleB,
          child: Text(
            title,
            style: AppTypography.h1.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Stagger(
          controller: _controller,
          start: bodyA,
          end: bodyB,
          child: Text(
            body,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ..._buildChildren(colors, dark),
      ],
    );
  }

  Widget _buildArt(double w) {
    switch (widget.step) {
      case 0:
        return SizedBox(
          width: w,
          height: widget.artHeight,
          child: Center(
            child: _WheelieBinArt(
              color: CouncilScheme.resolve('derby', WasteStream.recycling)
                  .themed(context),
              progress: CurvedAnimation(
                parent: _controller,
                curve: const Interval(0.14, 0.40, curve: Curves.easeOutCubic),
              ),
              width: 240,
              height: widget.artHeight,
            ),
          ),
        );
      case 1:
        return _buildCalendarArt(w);
      default:
        return _buildReminderArt(w);
    }
  }

  Widget _buildCalendarArt(double w) {
    final colors = context.binColors;
    final streams = CouncilScheme.streamsFor('derby');
    final binColors = [
      for (final s in streams)
        CouncilScheme.resolve('derby', s).themed(context),
    ];
    return SizedBox(
      width: w,
      height: widget.artHeight,
      child: Center(
        child: Container(
          width: math.min(w * 0.82, 260),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: colors.borderLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    _scheduleRow('Thu 24 Sep', [binColors[1], binColors[3]]),
                    _scheduleRow('Mon 28 Sep', [binColors[0]]),
                    _scheduleRow('Wed 30 Sep', [binColors[2]]),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                decoration: BoxDecoration(color: colors.primaryLight),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        size: 12, color: colors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Evening nudge before each collection',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 12, color: colors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Missed a bin? Flag it in seconds.',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleRow(String label, List<Color> chips) {
    final colors = context.binColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          for (final c in chips)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  gradient: binBandedGradient(c),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderArt(double w) {
    final colors = context.binColors;
    return SizedBox(
      width: w,
      height: widget.artHeight,
      child: Center(
        child: Container(
          width: math.min(w * 0.82, 260),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: colors.borderLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: binBandedGradient(const Color(0xFF3B82F6)),
                ),
                child: const Text(
                  'BIN DAY REMINDERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Recycling tomorrow',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '24 September',
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primaryLight,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Text(
                        'Reminder set',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(BinColors colors, bool dark) {
    switch (widget.step) {
      case 0:
        final bins = CouncilScheme.streamsFor('derby')
            .map((s) => CouncilScheme.resolve('derby', s))
            .toList();
        return [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < bins.length; i++)
                _Stagger(
                  controller: _controller,
                  start: 0.62 + i * 0.07,
                  end: 0.78 + i * 0.07,
                  rise: 12,
                  child: _BinPill(
                    color: bins[i].themed(context),
                    label: bins[i].label,
                  ),
                ),
            ],
          ),
        ];
      case 1:
        const cards = [
          _FeatureCardData(
            icon: Icons.calendar_month_outlined,
            title: 'Full schedule',
            caption: 'Every bin, every week — all in one place.',
          ),
          _FeatureCardData(
            icon: Icons.notifications_active_outlined,
            title: 'Evening nudges',
            caption: 'A gentle reminder the night before collection.',
          ),
          _FeatureCardData(
            icon: Icons.flag_outlined,
            title: 'Missed a bin?',
            caption: 'Flag it to your council in a couple of taps.',
          ),
        ];
        return [
          for (var i = 0; i < cards.length; i++)
            _Stagger(
              controller: _controller,
              start: 0.42 + i * 0.08,
              end: 0.62 + i * 0.08,
              rise: 18,
              child: Padding(
                padding: EdgeInsets.only(bottom: i < cards.length - 1 ? AppSpacing.md : 0),
                child: _FeatureCard(data: cards[i]),
              ),
            ),
        ];
      default:
        return const [];
    }
  }
}

class _FeatureCardData {
  final IconData icon;
  final String title;
  final String caption;

  const _FeatureCardData({
    required this.icon,
    required this.title,
    required this.caption,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureCardData data;

  const _FeatureCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(data.icon, size: 21, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title,
                    style: AppTypography.title
                        .copyWith(color: colors.textPrimary)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.caption,
                  style: AppTypography.caption
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BinPill extends StatelessWidget {
  final Color color;
  final String label;

  const _BinPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Stage panel behind the art â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StagePanel extends StatelessWidget {
  final double height;
  final Widget Function(double width) artBuilder;

  const _StagePanel({
    required this.height,
    required this.artBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: forestBandedGradient(dark: dark),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Center(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = math.min(c.maxWidth, 360.0);
            return SizedBox(width: w, child: artBuilder(w));
          },
        ),
      ),
    );
  }
}

// â”€â”€â”€ Staggered entrance helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Stagger extends StatelessWidget {
  final Animation<double> controller;
  final double start;
  final double end;
  final double rise;
  final Widget child;

  const _Stagger({
    required this.controller,
    required this.start,
    required this.end,
    this.rise = 12,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final t = _seg(controller, start, end);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, rise * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

// â”€â”€â”€ Initial page entrance (slide-up + fade, once) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _InitialEntrance extends StatefulWidget {
  final Widget child;

  const _InitialEntrance({super.key, required this.child});

  @override
  State<_InitialEntrance> createState() => _InitialEntranceState();
}

class _InitialEntranceState extends State<_InitialEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

// â”€â”€â”€ Bottom CTA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomCta extends StatelessWidget {
  final int step;
  final bool busy;
  final bool reduceMotion;
  final bool? remindersGranted;
  final VoidCallback onGetStarted;
  final VoidCallback onNext;
  final VoidCallback onEnable;
  final VoidCallback onNotNow;

  const _BottomCta({
    super.key,
    required this.step,
    required this.busy,
    required this.reduceMotion,
    required this.remindersGranted,
    required this.onGetStarted,
    required this.onNext,
    required this.onEnable,
    required this.onNotNow,
  });

  Widget _transition(Widget child, Animation<double> animation) {
    return FadeTransition(opacity: animation, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: _transition,
        child: _buildCta(colors),
      ),
    );
  }

  Widget _buildCta(BinColors colors) {
    switch (step) {
      case 0:
        return _PrimaryButton(
          key: const ValueKey('cta-get-started'),
          busy: busy,
          label: 'See my street.',
          onPressed: onGetStarted,
        );
      case 1:
        return _PrimaryButton(
          key: const ValueKey('cta-next'),
          busy: busy,
          label: 'Show me the nudge.',
          onPressed: onNext,
        );
      default:
        return Column(
          key: const ValueKey('cta-reminders'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _PrimaryButton(
              busy: busy,
              label: 'Continue',
              onPressed: onEnable,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: busy ? null : onNotNow,
                child: Text(
                  'Not now',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _PrimaryButton extends StatefulWidget {
  final bool busy;
  final String label;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    super.key,
    required this.busy,
    required this.label,
    this.onPressed,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  bool get _enabled => !widget.busy && widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled && value) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled ? widget.onPressed : null,
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.label,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: Duration(milliseconds: _pressed ? 90 : 140),
          curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
          child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: widget.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
      ),
    );
  }
}

class _WheelieBinArt extends StatelessWidget {
  final Color color;
  final Animation<double> progress;
  final double width;
  final double height;

  const _WheelieBinArt({
    required this.color,
    required this.progress,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _WheelieBinPainter(color: color, progress: progress),
      ),
    );
  }
}

class _WheelieBinPainter extends CustomPainter {
  final Color color;
  final Animation<double> progress;

  _WheelieBinPainter({required this.color, required this.progress})
      : super(repaint: progress);

  double _segP(double p, double a, double b) {
    if (p <= a) return 0;
    if (p >= b) return 1;
    return Curves.easeOutCubic.transform((p - a) / (b - a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = progress.value;

    final entrance = _segP(p, 0.00, 0.26);
    if (entrance <= 0) return;

    final bw = w * 0.46;
    final bh = bw * 1.45;
    final cx = w / 2;
    final gy = h * 0.90;
    final drop = bh * 0.35 * (1 - entrance);
    final box = Rect.fromLTWH(cx - bw / 2, gy - bh + drop, bw, bh);

    _drawFeatheredEllipse(
      canvas,
      center: Offset(cx, gy + h * 0.015),
      rx: bw * 0.45,
      ry: bw * 0.10,
      color: Colors.black.withValues(alpha: 0.10 * entrance),
    );

    final glowEnt = _segP(p, 0.45, 0.75);
    if (glowEnt > 0) {
      final lift = _segP(p, 0.45, 0.65);
      _drawFeatheredEllipse(
        canvas,
        center: Offset(cx, gy - bh * 0.55 - h * 0.03 * lift),
        rx: bw * 0.80,
        ry: bh * 0.58,
        color: color.withValues(alpha: 0.30 * glowEnt),
      );
    }

    _paintBin(canvas, box, color);

    final dots = [
      (Offset(w * 0.12, h * 0.24), 8.0),
      (Offset(w * 0.88, h * 0.18), 6.0),
      (Offset(w * 0.80, h * 0.34), 7.0),
    ];
    for (final d in dots) {
      _drawFeatheredEllipse(
        canvas,
        center: d.$1,
        rx: d.$2 * 0.5,
        ry: d.$2 * 0.5,
        color: color.withValues(alpha: 0.18),
      );
    }
  }

  void _paintBin(Canvas canvas, Rect box, Color color) {
    final w = box.width;
    final h = box.height;
    final dark = Color.lerp(color, const Color(0xFF000000), 0.16)!;
    final darker = Color.lerp(color, const Color(0xFF000000), 0.32)!;
    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.28)!;

    canvas.save();
    canvas.translate(box.left, box.top);

    final body = Path()
      ..moveTo(w * 0.20, h * 0.48)
      ..lineTo(w * 0.80, h * 0.48)
      ..quadraticBezierTo(w * 0.82, h * 0.60, w * 0.80, h * 0.80)
      ..lineTo(w * 0.64, h * 0.88)
      ..lineTo(w * 0.36, h * 0.88)
      ..lineTo(w * 0.20, h * 0.80)
      ..quadraticBezierTo(w * 0.18, h * 0.60, w * 0.20, h * 0.48)
      ..close();
    canvas.drawPath(body, Paint()..color = color);

    final bodyShade = Path()
      ..moveTo(w * 0.68, h * 0.50)
      ..lineTo(w * 0.80, h * 0.48)
      ..quadraticBezierTo(w * 0.82, h * 0.60, w * 0.80, h * 0.80)
      ..lineTo(w * 0.64, h * 0.88)
      ..lineTo(w * 0.60, h * 0.88)
      ..lineTo(w * 0.74, h * 0.80)
      ..quadraticBezierTo(w * 0.76, h * 0.60, w * 0.66, h * 0.50)
      ..close();
    canvas.drawPath(bodyShade, Paint()..color = dark.withValues(alpha: 0.55));

    final rib = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.21, h * 0.52, w * 0.795, h * 0.60),
      bottomLeft: Radius.circular(w * 0.02),
      bottomRight: Radius.circular(w * 0.02),
    );
    canvas.drawRRect(rib, Paint()..color = light.withValues(alpha: 0.5));

    final sheen = Path()
      ..moveTo(w * 0.30, h * 0.56)
      ..lineTo(w * 0.36, h * 0.56)
      ..lineTo(w * 0.34, h * 0.82)
      ..lineTo(w * 0.28, h * 0.82)
      ..close();
    canvas.drawPath(
        sheen, Paint()..color = Colors.white.withValues(alpha: 0.28));

    final lid = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.14, h * 0.30, w * 0.86, h * 0.50),
      topLeft: Radius.circular(w * 0.14),
      topRight: Radius.circular(w * 0.14),
    );
    canvas.drawRRect(lid, Paint()..color = dark);

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.14, h * 0.30, w * 0.86, h * 0.36),
        topLeft: Radius.circular(w * 0.14),
        topRight: Radius.circular(w * 0.14),
      ),
      Paint()..color = _lighter(dark),
    );

    final handle = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.44, h * 0.22, w * 0.56, h * 0.32),
      topLeft: Radius.circular(w * 0.06),
      topRight: Radius.circular(w * 0.06),
    );
    canvas.drawRRect(handle, Paint()..color = _lighter(darker));

    final wheelPaint = Paint()..color = const Color(0xFF2A2F2B);
    canvas.drawCircle(Offset(w * 0.34, h * 0.86), w * 0.10, wheelPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.86), w * 0.10, wheelPaint);
    final hubPaint = Paint()..color = const Color(0xFF545C56);
    canvas.drawCircle(Offset(w * 0.34, h * 0.86), w * 0.035, hubPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.86), w * 0.035, hubPaint);

    canvas.restore();
  }

  Color _lighter(Color c) => Color.lerp(c, const Color(0xFFFFFFFF), 0.42)!;

  void _drawFeatheredEllipse(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, ry / rx);
    canvas.translate(-center.dx, -center.dy);
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: rx * 2, height: rx * 2),
      Radius.circular(rx),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelieBinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}