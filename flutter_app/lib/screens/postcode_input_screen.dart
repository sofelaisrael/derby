import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/schedule_service.dart';
import '../services/session_store.dart';
import 'address_picker_screen.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';

class PostcodeInputScreen extends StatefulWidget {
  const PostcodeInputScreen({super.key});

  @override
  State<PostcodeInputScreen> createState() => _PostcodeInputScreenState();
}

class _PostcodeInputScreenState extends State<PostcodeInputScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scheduleService = ScheduleService();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatPostcode(String value) {
    final clean = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 ]'), '');
    if (clean.length > 4) {
      return '${clean.substring(0, clean.length - 3)} ${clean.substring(clean.length - 3)}';
    }
    return clean;
  }

  Future<void> _lookupPostcode() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Please enter a postcode');
      return;
    }

    final postcode = _formatPostcode(raw);
    if (!_isValidPostcode(postcode)) {
      setState(() => _error = 'Please enter a valid UK postcode');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final addresses = await _scheduleService.lookupAddresses(postcode);
      if (!mounted) return;

      if (addresses.isEmpty) {
        setState(() {
          _error = 'No addresses found for this postcode';
          _isLoading = false;
        });
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddressPickerScreen(
            addresses: addresses,
            postcode: postcode,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to look up postcode. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  bool _isValidPostcode(String postcode) {
    final regex = RegExp(
      r'^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$',
    );
    return regex.hasMatch(postcode);
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
                  'Enter your postcode',
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
                  'We\'ll find your bin collection schedule',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Postcode input
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(8),
                  ],
                  onChanged: (value) {
                    final formatted = _formatPostcode(value);
                    if (formatted != value) {
                      _controller.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                    if (_error != null) {
                      setState(() => _error = null);
                    }
                  },
                  onSubmitted: (_) => _lookupPostcode(),
                  decoration: InputDecoration(
                    hintText: 'DE1 1AA',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    errorText: _error,
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: _error != null
                          ? AppColors.error
                          : AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Look up button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _lookupPostcode,
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
                                'Find my collections',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.search, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Help text
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
                    children: [
                      const Icon(
                        Icons.help_outline,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Your postcode helps us find your council and collection dates.',
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
