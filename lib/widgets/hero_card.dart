import 'package:flutter/material.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../widgets/bin_swatch.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class TodayBanner extends StatelessWidget {
  final List<BinCollection> collections;
  final String councilSlug;

  const TodayBanner(
      {super.key, required this.collections, this.councilSlug = 'derby'});

  @override
  Widget build(BuildContext context) {
    final labels = collections
        .map((c) => CouncilScheme.resolve(councilSlug, c.stream).label)
        .toList();
    final text = labels.length == 1
        ? '${labels[0]} collected today'
        : '${labels.map((l) => l.replaceAll(' bin', '')).join(' and ')} bins collected today';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: context.binColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.binColors.borderLight),
      ),
      child: Row(
        children: [
          ...collections.map((c) {
            final p = CouncilScheme.resolve(councilSlug, c.stream);
            final t = p.themed(context);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  BinSwatch(p: p, size: 30),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: binForeground(t.bodyColor),
                  ),
                ],
              ),
            );
          }),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppTypography.title.copyWith(
                    color: context.binColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  collections.length == 1 ? 'Hope your bin is out!' : 'Hope your bins are out!',
                  style: AppTypography.caption.copyWith(
                    color: context.binColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HeroCollectionCard extends StatelessWidget {
  final String binLabel;
  final String display;
  final String? subtitle;
  final List<BinCollection> collections;
  final double progress;
  final VoidCallback onTap;
  final String councilSlug;

  const HeroCollectionCard({
    super.key,
    required this.binLabel,
    required this.display,
    this.subtitle,
    required this.collections,
    required this.progress,
    required this.onTap,
    this.councilSlug = 'derby',
  });

  /// Splits "3 Days" into a large number + small unit for editorial type.
  ({String? number, String label}) _splitDisplay() {
    final match = RegExp(r'^(\d+) Days$').firstMatch(display);
    if (match != null) {
      return (number: match.group(1), label: 'Days');
    }
    return (number: null, label: display);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final animDuration = reduce ? Duration.zero : const Duration(milliseconds: 700);
    final curve = reduce ? Curves.linear : Curves.easeOutCubic;
    const textColor = Colors.white;
    final mutedColor = Colors.white.withValues(alpha: 0.72);
    final split = _splitDisplay();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF4338CA)],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Soft radial glow, top-right ─────────────
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // ── Ambient highlight, bottom ───────────
            Positioned(
              left: -20,
              bottom: -40,
              child: Container(
                width: 180,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // ── Translucent bin icon watermark ──────
            if (collections.isNotEmpty)
              Positioned(
                right: -6,
                bottom: -12,
                child: Opacity(
                  opacity: 0.12,
                  child: Icon(
                    Icons.recycling_outlined,
                    size: 96,
                    color: Colors.white,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bin chips ─────────────────────────
                  if (binLabel.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                          for (final c in collections)
                            Builder(builder: (context) {
                              final p =
                                  CouncilScheme.resolve(councilSlug, c.stream);
                              final fg = binForeground(p.themed(context));
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: p.themed(context),
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(p.icon, size: 12, color: fg),
                                    const SizedBox(width: 5),
                                    Text(
                                      p.label.toUpperCase(),
                                      style: TextStyle(
                                        color: fg,
                                        letterSpacing: 1.1,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // ── Countdown ────────────────────────
                  AnimatedSwitcher(
                    duration: animDuration,
                    switchInCurve: curve,
                    switchOutCurve: curve,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Row(
                      key: ValueKey(display),
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (split.number != null) ...[
                          Text(
                            split.number!,
                            style: TextStyle(
                              fontSize: 60,
                              height: 0.9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                              color: textColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Days',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                              color: mutedColor,
                            ),
                          ),
                        ] else
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              split.label,
                              style: TextStyle(
                                fontSize: split.label.length > 8 ? 28 : 36,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: textColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle!,
                      style: AppTypography.body.copyWith(
                        color: mutedColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  // ── Meta + progress ──────────────────
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: mutedColor),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Before 7:00 AM',
                        style: AppTypography.caption.copyWith(color: mutedColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: animDuration,
                      curve: curve,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation(textColor),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double calculateProgress(DateTime date, DateTime today) {
    final daysUntil = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (daysUntil <= 0) return 1.0;
    return 1.0 - (daysUntil / 7.0).clamp(0.0, 1.0);
  }
}
