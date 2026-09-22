import '../main.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../services/calendar_export_service.dart';
import '../services/schedule_service.dart';
import '../services/theme_service.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/hero_card.dart';
import '../widgets/upcoming_tile.dart';
import '../widgets/weather_card.dart';
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
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _viewMonth;
  DateTime? _selectedDate;
  bool _addingToCalendar = false;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  AreaSchedule get _area => widget.area;

  List<CollectionDay> get _upcomingDays =>
      getNextCollectionDays(_area, 5, DateTime.now());

  bool get _hasTodayCollection {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return getCollectionsOnDate(_area, todayDate).isNotEmpty;
  }

  List<BinCollection> get _todayCollections {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return getCollectionsOnDate(_area, todayDate);
  }

  List<WasteStream> _binStreamsFor(DateTime date) {
    final streams = <WasteStream>[];
    for (final s in _area.schedules) {
      final d = DateTime(date.year, date.month, date.day);
      if (d.weekday != s.dayOfWeek) continue;
      final interval = switch (s.frequency) {
        Frequency.weekly => 7,
        Frequency.fortnightly => 14,
        Frequency.threeWeekly => 21,
        Frequency.fourWeekly => 28,
        Frequency.sixWeekly => 42,
        Frequency.eightWeekly => 56,
        Frequency.twelveWeekly => 84,
      };
      final diff = d
          .difference(DateTime(
              s.anchorDate.year, s.anchorDate.month, s.anchorDate.day))
          .inDays;
      if (((diff % interval) + interval) % interval == 0) {
        streams.add(s.stream);
      }
    }
    return streams;
  }

  Widget _binStreamsForDay(int day, DateTime todayDate) {
    final date = DateTime(_viewMonth.year, _viewMonth.month, day);
    final streams = _binStreamsFor(date);
    return _DayCell(
      day: day,
      isToday: todayDate == date,
      isSelected: _selectedDate == date,
      hasCollection: streams.isNotEmpty,
      binStreams: streams,
      councilSlug: widget.councilSlug,
      onTap: () {
        if (streams.isEmpty) return;
        setState(() {
          _selectedDate = date;
        });
      },
    );
  }

  Future<void> _addToCalendar(BuildContext context) async {
    if (_addingToCalendar) return;
    _addingToCalendar = true;
    try {
      final added = await CalendarExportService.addNextCollectionToCalendar(
        area: _area,
        councilName: widget.councilName,
        postcode: widget.postcode,
        addressLabel: widget.addressLabel,
        councilSlug: widget.councilSlug,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        added
            ? const SnackBar(
                content: Text('Added next collection to your calendar.'))
            : const SnackBar(content: Text('Could not add to calendar.')),
      );
    } finally {
      _addingToCalendar = false;
    }
  }

  /// One Export button instead of three: a bottom sheet holds the calendar,
  /// .ics export and text-share actions so the screen stays uncluttered.
  void _showExportSheet(BuildContext context, Rect? origin) {
    final colors = context.binColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceElevated,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                'Export your schedule',
                style: AppTypography.h3.copyWith(color: colors.textPrimary),
              ),
            ),
            _SheetAction(
              icon: Icons.event_available_outlined,
              title: 'Add to calendar',
              subtitle: 'Save the next collection to your phone calendar',
              onTap: () {
                Navigator.pop(sheet);
                _addToCalendar(context);
              },
            ),
            _SheetAction(
              icon: Icons.calendar_today_outlined,
              title: 'Export .ics file',
              subtitle: 'Share a calendar file you can open on any device',
              onTap: () {
                Navigator.pop(sheet);
                CalendarExportService.exportCollections(
                  area: _area,
                  councilSlug: widget.councilSlug,
                  councilName: widget.councilName,
                  postcode: widget.postcode,
                  addressLabel: widget.addressLabel,
                  sharePositionOrigin: origin,
                );
              },
            ),
            _SheetAction(
              icon: Icons.share_outlined,
              title: 'Share schedule',
              subtitle: 'Send the next few collections as a message',
              onTap: () {
                Navigator.pop(sheet);
                _shareSchedule(origin);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _shareSchedule(Rect? origin) {
    final summary = _upcomingDays.take(3).map((d) {
      final bins = d.collections
          .map((c) => CouncilScheme.resolve(widget.councilSlug, c.stream).label)
          .join(', ');
      return '${fullDateLabel(d.date)}: $bins';
    }).join('\n');
    SharePlus.instance.share(ShareParams(
      text: 'My bin collection schedule:\n\n$summary\n\nvia $appName',
      sharePositionOrigin: origin,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _upcomingDays;
    final hasToday = _hasTodayCollection;
    final next = upcoming.length > (hasToday ? 1 : 0)
        ? upcoming[hasToday ? 1 : 0]
        : null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    String display;
    String? subtitle;
    double progress = 0;

    if (next != null) {
      final daysUntil = DateTime(next.date.year, next.date.month, next.date.day)
          .difference(todayDate)
          .inDays;
      if (daysUntil == 0) {
        display = 'Today';
        subtitle = fullDateLabel(next.date);
        progress = 1.0;
      } else if (daysUntil == 1) {
        display = 'Tomorrow';
        subtitle = fullDateLabel(next.date);
        progress = 0.85;
      } else {
        display = '$daysUntil ${daysUntil == 1 ? "Day" : "Days"}';
        subtitle = fullDateLabel(next.date);
        progress = 1.0 - (daysUntil / 7.0).clamp(0.0, 1.0);
      }
    } else {
      display = 'No collections';
      subtitle = null;
      progress = 0;
    }

    final first = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final leadBlanks = (first.weekday + 6) % 7;
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;

    return Scaffold(
      backgroundColor: context.binColors.background,
      body: SafeArea(
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
              // ── Top row: title + settings gear ──────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.h1.copyWith(
                            fontSize: 26,
                            color: context.binColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.addressLabel ?? _area.areaName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: context.binColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
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
                        color: context.binColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(20, 33, 26, 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: context.binColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Today banner ─────────────────────────
              if (hasToday)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TodayBanner(
                    collections: _todayCollections,
                    councilSlug: widget.councilSlug,
                  ),
                ),

              // ── Hero countdown ──────────────────────
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
                progress: progress,
                onTap: () {},
                councilSlug: widget.councilSlug,
              ),
              const SizedBox(height: 20),

              // ── Quick actions ────────────────────────
              _QuickAction(
                icon: Icons.ios_share,
                label: 'Export & share',
                onTap: (origin) => _showExportSheet(context, origin),
              ),
              const SizedBox(height: 20),

              // ── Weather ─────────────────────────────
              WeatherCard(
                councilSlug: widget.councilSlug,
              ),
              const SizedBox(height: 24),

              // ── Calendar ────────────────────────────
              Row(
                children: [
                  Text(
                    monthTitle(_viewMonth.year, _viewMonth.month),
                    style: AppTypography.h2,
                  ),
                  const Spacer(),
                  _RoundButton(
                    icon: Icons.chevron_left,
                    onTap: () {
                      setState(() {
                        _viewMonth = DateTime(
                            _viewMonth.year, _viewMonth.month - 1);
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: Icons.chevron_right,
                    onTap: () {
                      setState(() {
                        _viewMonth = DateTime(
                            _viewMonth.year, _viewMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map((d) => SizedBox(
                          width: 38,
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.binColors.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: .9,
                children: [
                  for (var i = 0; i < leadBlanks; i++) const SizedBox(),
                  for (var day = 1; day <= daysInMonth; day++)
                    _binStreamsForDay(day, todayDate),
                ],
              ),
              if (_selectedDate != null) ...[
                const SizedBox(height: 12),
                _DayDetail(
                  date: _selectedDate!,
                  collections: getCollectionsOnDate(_area, _selectedDate!),
                  councilSlug: widget.councilSlug,
                ),
              ],
              const SizedBox(height: 28),

              // ── Upcoming ────────────────────────────
              Row(
                children: [
                  Text(
                    'Upcoming',
                    style: AppTypography.h3.copyWith(
                      color: context.binColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Next 5 collections',
                    style: AppTypography.caption.copyWith(
                      color: context.binColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._upcomingDays.map((d) {
                return UpcomingTile(
                  date: d.date,
                  collections: d.collections,
                  councilSlug: widget.councilSlug,
                );
              }),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text(
                  supportedCouncilsText,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: context.binColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.binColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(20, 33, 26, 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: context.binColors.textPrimary),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasCollection;
  final List<WasteStream> binStreams;
  final String councilSlug;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    this.hasCollection = false,
    this.binStreams = const [],
    this.councilSlug = 'derby',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final bg = isToday
        ? colors.primary
        : isSelected
            ? colors.calendarCollection
            : Colors.transparent;
    final dayColor = isToday
        ? Colors.white
        : isSelected
            ? colors.primary
            : hasCollection
                ? colors.textPrimary
                : colors.textMuted;
    final WasteStream? singleStream =
        binStreams.length == 1 ? binStreams.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected && !isToday
                ? colors.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "$day",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: dayColor,
              ),
            ),
            if (singleStream != null) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxWidth: 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: CouncilScheme.resolve(councilSlug, singleStream)
                      .themed(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CouncilScheme.resolve(councilSlug, singleStream)
                        .label
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ] else if (binStreams.length > 1) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: binStreams
                    .map((stream) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: CouncilScheme.resolve(councilSlug, stream)
                                  .themed(context),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isToday || isSelected
                                    ? bg
                                    : colors.surfaceElevated,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final DateTime date;
  final List<BinCollection> collections;
  final String councilSlug;

  const _DayDetail(
      {required this.date,
      required this.collections,
      this.councilSlug = 'derby'});

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.binColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(20, 33, 26, 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fullDateLabel(date),
            style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.binColors.textPrimary,
                ),
          ),
          const SizedBox(height: 10),
          ...collections.map((c) {
            final p = CouncilScheme.resolve(councilSlug, c.stream);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: p.themed(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.binColors.textPrimary,
                    ),
                  ),
                    const Spacer(),
                    Text(
                      frequencyLabel[c.schedule.frequency] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.binColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final void Function(Rect? origin) onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        final origin = (box != null && box.hasSize)
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 1, 1);
        onTap(origin);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.binColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(20, 33, 26, 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.binColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: context.binColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTypography.title.copyWith(
                fontSize: 14,
                color: context.binColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.title.copyWith(
                      fontSize: 15,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
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
}
