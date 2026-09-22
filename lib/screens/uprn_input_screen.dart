import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/schedule_service.dart';
import '../services/session_store.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import 'home_page.dart';

class UprnInputScreen extends StatefulWidget {
  final String postcode;

  const UprnInputScreen({super.key, required this.postcode});

  @override
  State<UprnInputScreen> createState() => _UprnInputScreenState();
}

class _UprnInputScreenState extends State<UprnInputScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scheduleService = ScheduleService();
  final _sessionStore = SessionStore();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openUprnSite() async {
    final cleanPostcode = widget.postcode.replaceAll(' ', '');
    final uri = Uri.parse('https://uprn.uk/postcode/$cleanPostcode');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _continue() async {
    final uprn = _controller.text.trim();

    if (uprn.isEmpty) {
      setState(() => _error = 'Please enter your UPRN');
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(uprn)) {
      setState(() => _error = 'UPRN must be a number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final schedule = await _scheduleService.getSchedule(
        uprn: uprn,
        council: 'auto',
        postcode: widget.postcode,
      );

      await _sessionStore.saveSession(
        uprn: uprn,
        address: 'UPRN: $uprn',
        council: schedule.council,
        postcode: widget.postcode,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load schedule. Please check your UPRN and try again.';
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
                  'Find your UPRN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'We need your UPRN to find your bin collection dates',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: AppColors.accent,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        widget.postcode,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _openUprnSite,
                    icon: const Icon(Icons.open_in_new, size: 20),
                    label: Text(
                      'Open uprn.uk',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accent, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Paste your UPRN here',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) {
                    if (_error != null) {
                      setState(() => _error = null);
                    }
                  },
                  onSubmitted: (_) => _continue(),
                  decoration: InputDecoration(
                    hintText: 'e.g. 100023456789',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    errorText: _error,
                    prefixIcon: Icon(
                      Icons.tag,
                      color: _error != null
                          ? AppColors.error
                          : AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _continue,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.glassDark
                        : AppColors.glassLight,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: isDark
                          ? AppColors.glassBorderDark
                          : AppColors.glassBorderLight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.help_outline,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Go to uprn.uk, search your postcode, find your property, and copy the UPRN number',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
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
      ),
    );
  }
}
