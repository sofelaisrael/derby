import 'package:flutter/material.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../services/reminder_store.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_background.dart';
import '../widgets/banded_gradient.dart';
import '../widgets/bin_badge.dart';

const _wasteNames = {
  WasteStream.general: 'General household waste',
  WasteStream.recycling: 'Recycling',
  WasteStream.garden: 'Garden waste',
  WasteStream.food: 'Food waste',
};

const _frequencyNames = {
  WasteStream.general: 'Collected weekly',
  WasteStream.recycling: 'Collected fortnightly',
  WasteStream.garden: 'Collected fortnightly',
  WasteStream.food: 'Collected weekly',
};

class BinGuideScreen extends StatefulWidget {
  const BinGuideScreen({super.key});

  @override
  State<BinGuideScreen> createState() => _BinGuideScreenState();
}

class _BinGuideScreenState extends State<BinGuideScreen> {
  String _councilSlug = 'derby';

  @override
  void initState() {
    super.initState();
    _loadCouncil();
  }

  Future<void> _loadCouncil() async {
    final slug = await ReminderStore.getCachedCouncilSlug();
    if (mounted && slug != null) setState(() => _councilSlug = slug);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final streams = CouncilScheme.streamsFor(_councilSlug);
    return Scaffold(
      backgroundColor: colors.background,
      body: ScreenBackground(child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page, vertical: AppSpacing.md),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: colors.borderLight),
                      ),
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 18, color: colors.textMuted),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Bin guide', style: AppTypography.h1),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page,
                    AppSpacing.sm, AppSpacing.page, AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What goes where',
                      style: AppTypography.h2
                          .copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Know what belongs in each bin before collection day.',
                      style: AppTypography.body
                          .copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (final stream in streams) ...[
                      Builder(builder: (context) {
                        final p = CouncilScheme.resolve(_councilSlug, stream);
                        return Column(
                          children: [
                            _BinSection(
                              presentation: p,
                              stream: stream,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        );
                      }),
                    ],
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.primaryLight,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: colors.primary, size: 20),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Not sure which bin? Check your council website for the most up-to-date guide for your area.',
                              style: AppTypography.caption.copyWith(
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
          ],
        ),
      )),
    );
  }
}

class _BinSection extends StatelessWidget {
  final BinPresentation presentation;
  final WasteStream stream;

  const _BinSection({
    required this.presentation,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final subtitle = _wasteNames[stream] ?? '';
    final frequency = _frequencyNames[stream] ?? '';
    final color = presentation.themed(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: binBandedGradient(color),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BinBadge(presentation: presentation, size: 52),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(presentation.label,
                              style: AppTypography.title.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: AppTypography.caption
                                  .copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_repeat, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        frequency,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(height: 1, color: colors.borderLight),
                const SizedBox(height: AppSpacing.md),
                ...presentation.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_rounded,
                                size: 11, color: color),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(item,
                                  style: AppTypography.body.copyWith(
                                    fontSize: 14,
                                    color: colors.textPrimary,
                                  )),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surfaceTinted,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: colors.textMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                            'Belongs in your ${presentation.label.toLowerCase()}.',
                            style: AppTypography.caption.copyWith(
                                fontSize: 12, color: colors.textSecondary)),
                      ),
                    ],
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
