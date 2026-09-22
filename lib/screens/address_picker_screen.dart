import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/schedule_service.dart';
import '../services/session_store.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import 'home_page.dart';

class AddressPickerScreen extends StatefulWidget {
  final List<Map<String, String>> addresses;
  final String postcode;

  const AddressPickerScreen({
    super.key,
    required this.addresses,
    required this.postcode,
  });

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  final _scheduleService = ScheduleService();
  final _sessionStore = SessionStore();
  bool _isLoading = false;
  String? _error;

  Future<void> _selectAddress(Map<String, String> address) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uprn = address['uprn'] ?? '';
      
      // First, try to fetch the schedule to determine council
      final schedule = await _scheduleService.getSchedule(
        uprn: uprn,
        council: 'auto', // Proxy auto-detects
        postcode: widget.postcode,
      );

      // Save session
      await _sessionStore.saveSession(
        uprn: uprn,
        address: address['address'] ?? '',
        council: schedule.council,
        postcode: widget.postcode,
      );

      if (!mounted) return;

      // Navigate to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load schedule. Please try again.';
          _isLoading = false;
        });
      }
    }
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
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                // Back button
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Select your address',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${widget.addresses.length} addresses found for ${widget.postcode}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                // Address list
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        )
                      : ListView.builder(
                          itemCount: widget.addresses.length,
                          itemBuilder: (context, index) {
                            final address = widget.addresses[index];
                            return _buildAddressCard(address, isDark);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(Map<String, String> address, bool isDark) {
    final addressText = address['address'] ?? '';
    final town = address['town'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : () => _selectAddress(address),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
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
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.home_outlined,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addressText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (town.isNotEmpty)
                        Text(
                          town,
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
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
