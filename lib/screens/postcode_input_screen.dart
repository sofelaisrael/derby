import '../main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:derby_bins/services/bin_scheme.dart';
import 'package:derby_bins/services/council_api.dart';
import 'package:derby_bins/services/schedule_service.dart';
import 'package:derby_bins/services/theme_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'calendar_screen.dart';
import 'address_picker_screen.dart';

double _segValue(Animation<double> c, double a, double b,
    [Curve curve = Curves.easeOutCubic]) {
  final p = c.value;
  if (p <= a) return 0;
  if (p >= b) return 1;
  return curve.transform((p - a) / (b - a));
}

class _UppercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text == newValue.text.toUpperCase()) return newValue;
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class PostcodeInputScreen extends StatefulWidget {
  final ThemeService? themeService;
  const PostcodeInputScreen({super.key, this.themeService});

  @override
  State<PostcodeInputScreen> createState() => _PostcodeInputScreenState();
}

class _PostcodeInputScreenState extends State<PostcodeInputScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final AnimationController _entrance;
  bool _entranceStarted = false;
  bool _loading = false;
  List<CouncilInfo> _councils = [];
  CouncilInfo? _selectedCouncil;
  String _checkingPostcode = '';
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _loadCouncils();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_entranceStarted) {
      _entranceStarted = true;
      if (MediaQuery.of(context).disableAnimations) {
        _entrance.value = 1.0;
      } else {
        _entrance.forward();
      }
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCouncils() async {
    final councils = await CouncilApi.listCouncils();
    if (mounted) {
      setState(() {
        _councils = councils;
        _selectedCouncil ??= councils.isNotEmpty ? councils[0] : null;
      });
    }
  }

  void _pickCouncil(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.binColors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusXl)),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.binColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Select council', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: context.binColors.borderLight),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _councils.length,
                  itemBuilder: (ctx, i) {
                    final c = _councils[i];
                    final selected = c == _selectedCouncil;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color:
                            selected ? context.binColors.primaryLight : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? context.binColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? context.binColors.primary
                                  : context.binColors.textMuted,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        title: Text(c.name,
                            style: AppTypography.title.copyWith(
                              color: selected
                                  ? context.binColors.primary
                                  : context.binColors.textPrimary,
                            )),
                        onTap: () {
                          setState(() => _selectedCouncil = c);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.binColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.error_outline,
                    color: context.binColors.error, size: 24),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Oops', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(message,
                  style: AppTypography.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.binColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: Text('OK',
                      style: AppTypography.title.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(String postcode) async {
    if (_loading) return;
    final council = _selectedCouncil;
    if (council == null) {
      _showError('Select a council first.');
      return;
    }
    final raw = postcode.trim();
    if (raw.isEmpty) {
      setState(() => _fieldError = 'Enter your postcode first.');
      return;
    }
    setState(() {
      _loading = true;
      _fieldError = null;
      _checkingPostcode = formatPostcode(raw);
    });
    try {
      final result = await resolvePostcode(raw,
          councilSlug: council.slug, councilName: council.name);
      if (result is ResolveUncovered) {
        if (mounted) {
          _showError('We couldn\u2019t find any addresses for that '
              'postcode in ${council.name}. Check the postcode or try a different council.');
        }
        return;
      }
      if (!mounted) return;
      if (result is ResolveAddresses) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddressPickerScreen(
              postcode: result.postcode,
              councilSlug: council.slug,
              councilName: council.name,
              addresses: result.addresses,
              themeService: widget.themeService,
            ),
          ),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CalendarScreen(
            postcode: result.postcode,
            councilSlug: council.slug,
            councilName: council.name,
          ),
        ),
      );
    } on ScheduleError catch (e) {
      if (mounted) {
        if (e.code == 'INVALID') {
          setState(() => _fieldError = e.message);
        } else {
          _showError(e.message);
        }
      }
    } catch (_) {
      if (mounted) {
        _showError('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final smallHeight = MediaQuery.sizeOf(context).height < 700;
    final wide = MediaQuery.sizeOf(context).width >= 600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SingleChildScrollView(
          controller: _scrollController,
          child: AnimatedBuilder(
            animation: _entrance,
            builder: (context, _) {
              final herKerb = _segValue(_entrance, 0.00, 0.45);
              final head = _segValue(_entrance, 0.20, 0.45);
              final sub = _segValue(_entrance, 0.32, 0.52);
              final cardT = _segValue(_entrance, 0.45, 0.72);
              final cardFade = _segValue(_entrance, 0.45, 0.55);
              final proof = _segValue(_entrance, 0.72, 0.88);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Hero(
                    herKerb: herKerb,
                    head: head,
                    sub: sub,
                    smallHeight: smallHeight,
                    wide: wide,
                    themeService: widget.themeService,
                    councilSlug: _selectedCouncil?.slug ?? 'derby',
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _FormCard(
                        opacity: cardFade,
                        offsetY: 24 - 56 * cardT,
                        councilLabel: _selectedCouncil != null
                            ? _selectedCouncil!.name
                            : 'Your council',
                        proofOpacity: proof,
                        loading: _loading,
                        checking: _checkingPostcode,
                        fieldError: _fieldError,
                        controller: _controller,
                        onPickCouncil: () => _pickCouncil(context),
                        onChanged: (_) {
                          if (_fieldError != null) {
                            setState(() => _fieldError = null);
                          } else {
                            setState(() {});
                          }
                        },
                        onClear: () {
                          _controller.clear();
                          setState(() {});
                        },
                        onSubmit: () => _submit(_controller.text),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final double herKerb;
  final double head;
  final double sub;
  final bool smallHeight;
  final bool wide;
  final ThemeService? themeService;
  final String councilSlug;

  const _Hero({
    required this.herKerb,
    required this.head,
    required this.sub,
    required this.smallHeight,
    required this.wide,
    required this.themeService,
    this.councilSlug = 'derby',
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.binColors;
    final gradientColors = dark
        ? const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF3730A3)]
        : const [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSpacing.radiusXl),
          bottomRight: Radius.circular(AppSpacing.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        MediaQuery.of(context).padding.top + AppSpacing.xl,
        AppSpacing.xl,
        smallHeight ? 24 : 40,
      ),
      child: Stack(
        children: [
          // Radial light, top-left behind the headline.
          Positioned(
            top: -140,
            left: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.6),
                  radius: 0.9,
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Decorative white dots.
          const Positioned(
            top: 90,
            right: 70,
            child: _HeroDot(size: 6),
          ),
          const Positioned(
            top: 120,
            right: 30,
            child: _HeroDot(size: 8),
          ),
          const Positioned(
            top: 40,
            right: 24,
            child: _HeroDot(size: 6),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: herKerb,
                child: Row(
                  children: [
                    _BinCircles(
                      bins: CouncilScheme.streamsFor(councilSlug)
                          .map((s) {
                            final p =
                                CouncilScheme.resolve(councilSlug, s);
                            return _BinCircle(p.themed(context), p.icon);
                          })
                          .toList(),
                    ),
                    const Spacer(),
                    if (themeService != null)
                      GestureDetector(
                        onTap: () => themeService!.toggle(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(
                            themeService!.isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Opacity(
                opacity: head,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - head)),
                  child: Text(
                    'Your bin days,\nfor your street.',
                    style: TextStyle(
                      fontSize: wide ? 48 : 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: wide ? -1.5 : -1.0,
                      height: wide ? 1.0 : 1.05,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Opacity(
                opacity: sub,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - sub)),
                  child: Text(
                    'Enter your postcode and we\u2019ll show you exactly what goes out, and when.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroDot extends StatelessWidget {
  final double size;

  const _HeroDot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );
  }
}

/// A single coloured bin "token" inside the hero.
class _BinCircle {
  final Color color;
  final IconData icon;

  const _BinCircle(this.color, this.icon);
}

/// The four bin types as overlapping colour discs. Replaces the literal bin
/// imagery so the screen reads like a familiar "what goes out" motif rather
/// than a photo of the bin crew's truck.
class _BinCircles extends StatelessWidget {
  static const _size = 46.0;
  static const _overlap = 10.0;
  final List<_BinCircle> bins;

  const _BinCircles({required this.bins});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size * bins.length - _overlap * (bins.length - 1),
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < bins.length; i++)
            Positioned(
              left: i * (_size - _overlap),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bins[i].color,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  bins[i].icon,
                  color: binForeground(bins[i].color),
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final double opacity;
  final double offsetY;
  final String councilLabel;
  final double proofOpacity;
  final bool loading;
  final String checking;
  final String? fieldError;
  final TextEditingController controller;
  final VoidCallback onPickCouncil;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.opacity,
    required this.offsetY,
    required this.councilLabel,
    required this.proofOpacity,
    required this.loading,
    required this.checking,
    required this.fieldError,
    required this.controller,
    required this.onPickCouncil,
    required this.onChanged,
    required this.onClear,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, offsetY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: dark
                          ? colors.primaryLight.withValues(alpha: 0.22)
                          : colors.primary.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CouncilRow(
                      label: councilLabel,
                      onTap: onPickCouncil,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9 ]')),
                          _UppercaseFormatter(),
                        ],
                        maxLength: 8,
                        scrollPadding:
                            const EdgeInsets.only(bottom: 220),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your postcode',
                          hintStyle:
                              TextStyle(color: colors.textMuted),
                          prefixIcon: const Icon(
                              Icons.location_on_outlined, size: 18),
                          prefixIconColor: colors.textMuted,
                          suffixIcon: controller.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: onClear,
                                  child: Icon(Icons.cancel,
                                      size: 18,
                                      color: colors.textMuted),
                                )
                              : null,
                          counterText: '',
                        ),
                        onChanged: onChanged,
                        onSubmitted: (_) => onSubmit(),
                      ),
                    ),
                    if (fieldError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        fieldError!,
                        style: AppTypography.caption.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _SubmitButton(
                      loading: loading,
                      checking: checking,
                      onSubmit: onSubmit,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Opacity(
                opacity: proofOpacity,
                child: const _ProofStrip(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final opened = await launchUrl(
                      Uri.parse('https://www.gov.uk/rubbish-collection-day'),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Could not open GOV.UK.')),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.binColors.primary,
                  ),
                  child: Text(
                    'Check your bin day on GOV.UK',
                    style: AppTypography.caption.copyWith(
                      color: context.binColors.primary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
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

class _CouncilRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CouncilRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(Icons.apartment_rounded,
                    size: 20, color: colors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your council',
                        style: AppTypography.label
                            .copyWith(color: colors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title
                          .copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.10),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final bool loading;
  final String checking;
  final VoidCallback onSubmit;

  const _SubmitButton({
    required this.loading,
    required this.checking,
    required this.onSubmit,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  bool get _enabled => !widget.loading;

  void _setPressed(bool value) {
    if (!_enabled && value) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled ? widget.onSubmit : null,
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.loading
            ? 'Checking ${widget.checking}\u2026'
            : 'Find my bins',
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: Duration(milliseconds: _pressed ? 90 : 140),
          curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: widget.loading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Checking ${widget.checking}\u2026',
                        style:
                            AppTypography.title.copyWith(color: Colors.white),
                      ),
                    ],
                  )
                : Text('Find my bins',
                    style:
                        AppTypography.title.copyWith(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _ProofStrip extends StatelessWidget {
  const _ProofStrip();

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceTinted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        supportedCouncilsText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: colors.textMuted.withValues(alpha: 0.9),
          height: 1.4,
        ),
      ),
    );
  }
}