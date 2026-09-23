import '../main.dart';
import 'package:flutter/material.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../services/schedule_service.dart';
import '../services/theme_service.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_background.dart';
import '../widgets/hero_card.dart';
import '../widgets/upcoming_tile.dart';
import 'calendar_view_screen.dart';
import 'settings_tab.dart';

class HomePage extends StatefulWidget {
  final String postcode;
  final String councilSlug;
  final String councilName;
  final String? uprn;
  final String? addressLabel;
  final AreaSchedule area;
  final bool isLive;
  final ThemeService? themeService;
  final DateTime? now;

  const HomePage({
    super.key,
    required this.postcode,
    required this.councilSlug,
    required this.councilName,
    this.uprn,
    this.addressLabel,
    required this.area,
    required this.isLive,
    this.themeService,
    this.now,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime get _now => widget.now ?? DateTime.now();

  AreaSchedule get _area => widget.area;

  List<CollectionDay> get _upcomingDays =>
      getNextCollectionDays(_area, 5, _now);

  bool get _hasTodayCollection {
    final todayDate = DateTime(_now.year, _now.month, _now.day);
    return getCollectionsOnDate(_area, todayDate).isNotEmpty;
  }

  List<BinCollection> get _todayCollections {
    final todayDate = DateTime(_now.year, _now.month, _now.day);
    return getCollectionsOnDate(_area, todayDate);
  }

  String get _greeting {
    final hour = _now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _shortDateLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  void _openCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalendarViewScreen(
          area: widget.area,
          councilSlug: widget.councilSlug,
          councilName: widget.councilName,
          postcode: widget.postcode,
          addressLabel: widget.addressLabel,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final upcoming = _upcomingDays;
    final hasToday = _hasTodayCollection;
    final next = upcoming.length > (hasToday ? 1 : 0)
        ? upcoming[hasToday ? 1 : 0]
        : null;
    final todayDate = DateTime(_now.year, _now.month, _now.day);

    String display;
    String? subtitle;

    if (next != null) {
      final daysUntil = DateTime(next.date.year, next.date.month, next.date.day)
          .difference(todayDate)
          .inDays;
      if (daysUntil == 0) {
        display = 'Today';
        subtitle = _shortDateLabel(next.date);
      } else if (daysUntil == 1) {
        display = 'Tomorrow';
        subtitle = _shortDateLabel(next.date);
      } else {
        display = '$daysUntil ${daysUntil == 1 ? "Day" : "Days"}';
        subtitle = _shortDateLabel(next.date);
      }
    } else {
      display = 'No collections';
      subtitle = null;
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: ScreenBackground(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.h1.copyWith(
                            fontSize: 26,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.addressLabel ?? _area.areaName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  GestureDetector(
                    onTap: _openCalendar,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: colors.borderLight),
                      ),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsTab(
                            postcode: widget.postcode,
                            councilSlug: widget.councilSlug,
                            councilName: widget.councilName,
                            addressLabel: widget.addressLabel,
                            area: widget.area,
                            isLive: widget.isLive,
                            themeService: widget.themeService,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: colors.borderLight),
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'Your schedule',
                style: AppTypography.h2.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (hasToday)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: TodayBanner(
                    collections: _todayCollections,
                    councilSlug: widget.councilSlug,
                  ),
                ),

              HeroCollectionCard(
                binLabel: next?.collections
                        .map((c) =>
                            CouncilScheme.resolve(widget.councilSlug, c.stream)
                                .label)
                        .join(', ') ??
                    '',
                display: display,
                subtitle: subtitle,
                collections: next?.collections ?? [],
                onTap: _openCalendar,
                councilSlug: widget.councilSlug,
              ),
              const SizedBox(height: AppSpacing.xl),

              Row(
                children: [
                  Text(
                    'UP NEXT',
                    style: AppTypography.h3.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Next 5 collections',
                    style: AppTypography.caption.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              ...upcoming.map((d) {
                return UpcomingTile(
                  date: d.date,
                  collections: d.collections,
                  councilSlug: widget.councilSlug,
                  now: _now,
                );
              }),
              const SizedBox(height: AppSpacing.lg),

              Center(
                child: Column(
                  children: [
                    Text(
                      appName,
                      style: AppTypography.label.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      supportedCouncilsText,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}