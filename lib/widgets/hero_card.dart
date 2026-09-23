import 'package:flutter/material.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../widgets/bin_swatch.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'banded_gradient.dart';

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

  ({String? number, String label}) _splitDisplay() {
    final match = RegExp(r'^(\d+) Days$').firstMatch(display);
    if (match != null) {
      return (number: match.group(1), label: 'Days');
    }
    return (number: null, label: display);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final reduce = MediaQuery.of(context).disableAnimations;
    final animDuration = reduce ? Duration.zero : const Duration(milliseconds: 700);
    final curve = reduce ? Curves.linear : Curves.easeOutCubic;
    final split = _splitDisplay();

    final stripBase = collections.isNotEmpty
        ? CouncilScheme.resolve(councilSlug, collections.first.stream)
            .themed(context)
        : colors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                gradient: binBandedGradient(stripBase),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.primaryLight,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Icon(
                          collections.isNotEmpty
                              ? CouncilScheme.resolve(
                                      councilSlug, collections.first.stream)
                                  .icon
                              : Icons.recycling_outlined,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          binLabel.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (collections.length > 1) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in collections)
                          Builder(builder: (context) {
                            final p =
                                CouncilScheme.resolve(councilSlug, c.stream);
                            final t = p.themed(context);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: t.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(p.icon, size: 12, color: t),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.label.toUpperCase(),
                                    style: TextStyle(
                                      color: colors.textPrimary,
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
                  ],
                  const SizedBox(height: AppSpacing.xl),
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
                              fontSize: 40,
                              height: 1.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: colors.textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            split.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ] else
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              split.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: split.label.length > 8 ? 28 : 40,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: colors.textPrimary,
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
                        color: colors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
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