import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/theme_service.dart';
import '../services/session_store.dart';
import '../services/schedule_service.dart';
import '../models/council_info.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import 'postcode_input_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeService = ThemeService();

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
          child: Column(
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
                      'Settings',
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

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  children: [
                    // Appearance section
                    _buildSectionHeader('Appearance', isDark),
                    _buildThemeTile(context, themeService, isDark),

                    const SizedBox(height: AppSpacing.lg),

                    // Council section
                    _buildSectionHeader('Council', isDark),
                    _buildCouncilInfoTile(isDark),

                    const SizedBox(height: AppSpacing.lg),

                    // Data section
                    _buildSectionHeader('Data', isDark),
                    _buildClearCacheTile(context, isDark),

                    const SizedBox(height: AppSpacing.lg),

                    // About section
                    _buildSectionHeader('About', isDark),
                    _buildAboutTile(isDark),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
        ),
      ),
    );
  }

  Widget _buildThemeTile(
      BuildContext context, ThemeService themeService, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: ListTile(
        leading: Icon(
          isDark ? Icons.dark_mode : Icons.light_mode,
          color: AppColors.accent,
        ),
        title: Text(
          isDark ? 'Dark Mode' : 'Light Mode',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        trailing: Switch(
          value: isDark,
          onChanged: (_) => themeService.toggleTheme(),
          activeColor: AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildCouncilInfoTile(bool isDark) {
    return FutureBuilder<Map<String, String>?>(
      future: SessionStore().loadSession(),
      builder: (context, snapshot) {
        final session = snapshot.data;
        final councilId = session?['council'] ?? 'derby';
        final council = DerbyCouncil.fromId(councilId);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.location_city, color: AppColors.accent, size: 20),
            ),
            title: Text(
              council.displayName,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              session?['address'] ?? '',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClearCacheTile(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.delete_outline, color: AppColors.error),
        title: Text(
          'Clear Cache',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          'Remove cached collection data',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
        ),
        onTap: () async {
          await ScheduleService().clearCache();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cache cleared',
                  style: GoogleFonts.plusJakartaSans(),
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildAboutTile(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.info_outline,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        title: Text(
          'Derby Bins v1.0.0',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          'Derbyshire bin collection schedules',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
        ),
      ),
    );
  }
}
