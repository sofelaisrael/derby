import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/bin_schedule.dart';
import '../services/schedule_service.dart';
import '../services/session_store.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _scheduleService = ScheduleService();
  final _sessionStore = SessionStore();
  CollectionSchedule? _schedule;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final session = await _sessionStore.loadSession();
    if (session == null) return;

    try {
      final schedule = await _scheduleService.getSchedule(
        uprn: session['uprn']!,
        council: session['council']!,
        postcode: session['postcode'] ?? '',
      );
      if (mounted) {
        setState(() {
          _schedule = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<BinCollection> _collectionsForDay(DateTime day) {
    return _schedule?.collections.where((c) =>
        c.date.year == day.year &&
        c.date.month == day.month &&
        c.date.day == day.day).toList() ?? [];
  }

  List<BinCollection> _collectionsForMonth(DateTime month) {
    return _schedule?.collections.where((c) =>
        c.date.year == month.year &&
        c.date.month == month.month).toList() ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, const Color(0xFFEEF2FF)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Calendar',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Month navigator
                    _buildMonthNavigator(isDark),

                    // Calendar grid
                    _buildCalendarGrid(isDark),

                    const SizedBox(height: AppSpacing.md),

                    // Selected day details
                    Expanded(
                      child: _buildDayDetails(isDark),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
              });
            },
            icon: Icon(
              Icons.chevron_left,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
              });
            },
            icon: Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startOffset = firstDay.weekday % 7; // Monday = 1, Sunday = 0

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Day cells
          ...List.generate((lastDay.day + startOffset + 6) ~/ 7, (week) {
            return Row(
              children: List.generate(7, (dayOfWeek) {
                final dayIndex = week * 7 + dayOfWeek - startOffset + 1;
                if (dayIndex < 1 || dayIndex > lastDay.day) {
                  return const Expanded(child: SizedBox(height: 44));
                }
                final day = DateTime(
                  _currentMonth.year,
                  _currentMonth.month,
                  dayIndex,
                );
                final collections = _collectionsForDay(day);
                final isToday = _isToday(day);
                final isSelected = day.year == _selectedDate.year &&
                    day.month == _selectedDate.month &&
                    day.day == _selectedDate.day;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                            : isToday
                                ? AppColors.accent.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayIndex',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? AppColors.accent
                                      : isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (collections.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: collections
                                  .take(3)
                                  .map((c) => Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.all(0.5),
                                        decoration: BoxDecoration(
                                          color: c.wasteStreams.first.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  Widget _buildDayDetails(bool isDark) {
    final collections = _collectionsForDay(_selectedDate);
    final isToday = _isToday(_selectedDate);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToday
                ? 'Today'
                : DateFormat('EEEE, d MMMM').format(_selectedDate),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: collections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No collections on this day',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            ...collection.wasteStreams.map((stream) => Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: stream.color.withOpacity(0.15),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Icon(stream.icon, color: stream.color, size: 20),
                            )),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    collection.wasteStreams
                                        .map((w) => w.displayName)
                                        .join(', '),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    collection.frequency.shortLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.lightTextTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
