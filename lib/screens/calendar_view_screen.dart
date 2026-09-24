import '../main.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../services/calendar_export_service.dart';
import '../services/schedule_service.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_background.dart';
import '../widgets/banded_gradient.dart';
import '../widgets/bin_swatch.dart';

class CalendarViewScreen extends StatefulWidget {
  final AreaSchedule area;
  final String councilSlug;
  final String councilName;
  final String postcode;
  final String? addressLabel;
  final DateTime? now;

  const CalendarViewScreen({
    super.key,
    required this.area,
    required this.councilSlug,
    required this.councilName,
    required this.postcode,
    this.addressLabel,
    this.now,
  });

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  late DateTime _viewMonth;
  DateTime? _selectedDate;
  bool _addingToCalendar = false;

  DateTime get _now => widget.now ?? DateTime.now();

  AreaSchedule get _area => widget.area;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(_now.year, _now.month);
  }

  List<CollectionDay> get _upcomingDays =>
      getNextCollectionDays(_area, 5, _now);

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

  void _showExportSheet(BuildContext context, Rect? origin) {
    final colors = context.binColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceElevated,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                gradient: binBandedGradient(const Color(0xFF3B82F6)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
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
    final colors = context.binColors;
    final todayDate = DateTime(_now.year, _now.month, _now.day);
    final first = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final leadBlanks = (first.weekday + 6) % 7;
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;

    return Scaffold(
      backgroundColor: colors.background,
      body: ScreenBackground(child: Column(
        children: [
          _header(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        monthTitle(_viewMonth.year, _viewMonth.month),
                        style: AppTypography.h2.copyWith(
                          color: colors.textPrimary,
                        ),
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
                                  color: colors.textMuted,
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
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }

  Widget _header(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: forestBandedGradient(dark: isDark),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                _HeaderButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    'Your calendar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                _HeaderButton(
                  icon: Icons.ios_share,
                  onTap: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final origin = (box != null && box.hasSize)
                        ? box.localToGlobal(Offset.zero) & box.size
                        : const Rect.fromLTWH(0, 0, 1, 1);
                    _showExportSheet(context, origin);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

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
          border: Border.all(color: context.binColors.borderLight),
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
        ? binForeground(colors.primary)
        : isSelected
            ? colors.primary
            : hasCollection
                ? colors.textPrimary
                : colors.textMuted;
    final singleBin = binStreams.length == 1;
    final binColor = singleBin
        ? CouncilScheme.resolve(councilSlug, binStreams.first).themed(context)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (singleBin)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: binColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  "$day",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: binForeground(binColor!),
                  ),
                ),
              )
            else
              Text(
                "$day",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: dayColor,
                ),
              ),
            if (binStreams.length > 1) ...[
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: binStreams
                      .map((stream) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Container(
                              width: 16,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: binBandedGradient(
                                  CouncilScheme.resolve(councilSlug, stream)
                                      .themed(context),
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ))
                      .toList(),
                ),
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.binColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: context.binColors.textMuted),
              const SizedBox(width: 6),
              Text(
                fullDateLabel(date),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.binColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.binColors.borderLight),
          const SizedBox(height: 10),
          ...collections.map((c) {
            final p = CouncilScheme.resolve(councilSlug, c.stream);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  BinSwatch(p: p, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.binColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.binColors.primaryLight,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      frequencyLabel[c.schedule.frequency] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.binColors.primary,
                      ),
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
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
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