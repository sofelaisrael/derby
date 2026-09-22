import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/bin_schedule.dart';
import '../models/council_info.dart';
import '../services/schedule_service.dart';
import '../services/session_store.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'report_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final _scheduleService = ScheduleService();
  final _sessionStore = SessionStore();
  CollectionSchedule? _schedule;
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadSchedule();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule({bool forceRefresh = false}) async {
    final session = await _sessionStore.loadSession();
    if (session == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/postcode');
      }
      return;
    }

    try {
      final schedule = await _scheduleService.getSchedule(
        uprn: session['uprn']!,
        council: session['council']!,
        postcode: session['postcode'] ?? '',
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _schedule = schedule;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load collections. Pull down to retry.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? _buildLoadingState(isDark)
          : _error != null
              ? _buildErrorState(isDark)
              : _buildContent(isDark),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.darkBackground, AppColors.darkSurface]
              : [AppColors.lightBackground, const Color(0xFFEEF2FF)],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.darkBackground, AppColors.darkSurface]
              : [AppColors.lightBackground, const Color(0xFFEEF2FF)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadSchedule(forceRefresh: true);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final nextCollection = _schedule?.nextCollection;
    final upcoming = _schedule?.nextCollections(5) ?? [];

    return RefreshIndicator(
      onRefresh: () => _loadSchedule(forceRefresh: true),
      color: AppColors.accent,
      child: CustomScrollView(
        slivers: [
          // App bar
          SliverToBoxAdapter(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Derby Bins',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          _schedule?.address ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Council badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        DerbyCouncil.fromId(_schedule?.council ?? 'derby')
                            .displayName
                            .replaceAll(' Council', '')
                            .replaceAll(' Borough', '')
                            .replaceAll(' District', ''),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Hero card - Next collection
          if (nextCollection != null)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildHeroCard(nextCollection, isDark),
              ),
            ),

          // Quick actions
          SliverToBoxAdapter(
            child: _buildQuickActions(isDark),
          ),

          // Upcoming collections header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
              ),
              child: Text(
                'Upcoming Collections',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ),

          // Collection timeline
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final collection = upcoming[index];
                return _buildCollectionTimelineItem(
                  collection,
                  index,
                  upcoming.length,
                  isDark,
                );
              },
              childCount: upcoming.length,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BinCollection nextCollection, bool isDark) {
    final daysUntil = nextCollection.daysUntil;
    final daysLabel = daysUntil == 0
        ? 'Today'
        : daysUntil == 1
            ? 'Tomorrow'
            : 'In $daysUntil days';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  daysLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  DateFormat('EEE, d MMM').format(nextCollection.date),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Bin streams
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: nextCollection.wasteStreams.map((stream) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stream.icon, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        stream.displayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            // Countdown
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$daysUntil',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    daysUntil == 1 ? 'day' : 'days',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Row(
        children: [
          _buildQuickAction(
            icon: Icons.calendar_month_outlined,
            label: 'Calendar',
            onTap: () => setState(() => _currentIndex = 1),
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildQuickAction(
            icon: Icons.report_outlined,
            label: 'Report',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportScreen()),
              );
            },
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildQuickAction(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => setState(() => _currentIndex = 2),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isDark
                    ? AppColors.darkCardBorder
                    : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.accent, size: 24),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionTimelineItem(
    BinCollection collection,
    int index,
    int total,
    bool isDark,
  ) {
    final isLast = index == total - 1;
    final dayLabel = collection.isToday
        ? 'Today'
        : collection.isTomorrow
            ? 'Tomorrow'
            : DateFormat('EEE, d MMM').format(collection.date);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + dot
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: collection.isToday
                          ? AppColors.accent
                          : isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDark
                            ? AppColors.darkCardBorder
                            : AppColors.lightCardBorder,
                      ),
                    ),
                ],
              ),
            ),
            // Content card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: collection.isToday
                        ? AppColors.accent.withOpacity(0.3)
                        : isDark
                            ? AppColors.darkCardBorder
                            : AppColors.lightCardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dayLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          collection.frequency.shortLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      children: collection.wasteStreams.map((stream) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: stream.color.withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(stream.icon, size: 12, color: stream.color),
                              const SizedBox(width: 3),
                              Text(
                                stream.displayName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: stream.color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                isDark: isDark,
              ),
              _buildNavItem(
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label: 'Calendar',
                index: 1,
                isDark: isDark,
              ),
              _buildNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                index: 2,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? AppColors.accent
                    : isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? AppColors.accent
                      : isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
