import 'package:flutter/material.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../widgets/bin_swatch.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class UpcomingTile extends StatelessWidget {
  final DateTime date;
  final List<BinCollection> collections;
  final String councilSlug;

  const UpcomingTile({
    super.key,
    required this.date,
    required this.collections,
    this.councilSlug = 'derby',
  });

  String _relativeLabel(DateTime today) {
    final a = DateTime(date.year, date.month, date.day);
    final b = DateTime(today.year, today.month, today.day);
    final diff = a.difference(b).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = context.binColors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: themeColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Date chip ─────────────────────────
            Container(
              width: 52,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF4338CA)],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekday,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // ── Bins + relative date ───────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                       for (final c in collections)
                         Builder(builder: (context) {
                           final p =
                               CouncilScheme.resolve(councilSlug, c.stream);
                           return _BinPill(
                             presentation: p,
                             name: p.label,
                           );
                         }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeLabel(DateTime.now()),
                    style: AppTypography.caption.copyWith(
                      color: themeColors.primary,
                      fontWeight: FontWeight.w700,
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

  String get _weekday => _weekNames[date.weekday - 1];
}

const _weekNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _BinPill extends StatelessWidget {
  final BinPresentation presentation;
  final String name;

  const _BinPill({required this.presentation, required this.name});

  @override
  Widget build(BuildContext context) {
    final themeColors = context.binColors;
    final color = presentation.themed(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BinSwatch(
              p: presentation, size: 8, radius: AppSpacing.radiusFull),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: themeColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}