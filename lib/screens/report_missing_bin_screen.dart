import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/banded_gradient.dart';

class ReportMissingBinScreen extends StatefulWidget {
  final String postcode;
  final String councilName;
  final String? addressLabel;

  const ReportMissingBinScreen({
    super.key,
    required this.postcode,
    required this.councilName,
    this.addressLabel,
  });

  @override
  State<ReportMissingBinScreen> createState() => _ReportMissingBinScreenState();
}

class _ReportMissingBinScreenState extends State<ReportMissingBinScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _issueType = 'Missing bin';
  bool _submitted = false;
  bool _submitting = false;

  // Keep in sync with ALLOWED_ISSUE_TYPES in proxy/vercel/api/report.js.
  static const _issueTypes = [
    'Missing bin',
    'Bin not collected',
    'Bin damaged',
    'Wrong bin collected',
    'Collection schedule wrong',
    'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide(color: context.binColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide(color: context.binColors.primary, width: 2),
      ),
      filled: true,
      fillColor: context.binColors.surfaceTinted,
      isDense: true,
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final result = await ReportService.submit(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        issueType: _issueType,
        description: _descCtrl.text,
        address: widget.addressLabel ?? '',
        council: widget.councilName,
        postcode: widget.postcode,
      );
      if (!mounted) return;
      if (result is ReportSuccess) {
        setState(() => _submitted = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page, vertical: AppSpacing.md),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 18, color: colors.textMuted),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Report an issue', style: AppTypography.h1),
                ],
              ),
            ),
            Expanded(
              child: _submitted ? _buildSuccess() : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final colors = context.binColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: forestBandedGradient(dark: false),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(Icons.check, size: 34, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Report submitted',
                style: AppTypography.h2.copyWith(color: colors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Thanks for letting us know. We\u2019ll look into your ${_issueType.toLowerCase()} report.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final colors = context.binColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xxl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Intro card ────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: forestBandedGradient(dark: false),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.report_problem_outlined,
                        size: 22, color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('What\u2019s the issue?',
                      style: AppTypography.h2
                          .copyWith(color: colors.textPrimary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tell us about the problem and we\u2019ll help sort it out.',
                    style: AppTypography.body
                        .copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // ── Reporting context ──
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.surfaceTinted,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: colors.textMuted),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${widget.addressLabel ?? 'Your address'}, ${widget.postcode} · ${widget.councilName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Issue type ────────────────────────────
            Text(
              'ISSUE TYPE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _issueTypes.map((type) {
                final selected = _issueType == type;
                return GestureDetector(
                  onTap: () => setState(() => _issueType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary
                          : colors.surfaceElevated,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Details ───────────────────────────────
            Text(
              'YOUR DETAILS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDeco('Your name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _emailCtrl,
              decoration: _inputDeco('Your email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descCtrl,
              decoration: _inputDeco('Describe the issue'),
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit report'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel',
                    style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
