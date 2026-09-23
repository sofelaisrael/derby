import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_background.dart';
import '../widgets/banded_gradient.dart';

class ReportMissingAddressScreen extends StatefulWidget {
  final String postcode;
  final String councilSlug;
  final String councilName;
  final String? addressLabel;

  const ReportMissingAddressScreen({
    super.key,
    required this.postcode,
    required this.councilSlug,
    required this.councilName,
    this.addressLabel,
  });

  @override
  State<ReportMissingAddressScreen> createState() =>
      _ReportMissingAddressScreenState();
}

class _ReportMissingAddressScreenState extends State<ReportMissingAddressScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;
  bool _submitting = false;

  // Keep in sync with ALLOWED_ISSUE_TYPES in proxy/vercel/api/report.js.
  static const _issueType = 'Missing address';

  @override
  void initState() {
    super.initState();
    if (widget.addressLabel != null) {
      _addressCtrl.text = widget.addressLabel!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.container),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.container),
        borderSide: BorderSide(color: context.binColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.container),
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
        description: _notesCtrl.text,
        address: _addressCtrl.text,
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
    return Scaffold(
      backgroundColor: context.binColors.background,
      body: ScreenBackground(child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xxl, vertical: Spacing.md),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.binColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: context.binColors.border),
                      ),
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 18, color: context.binColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  const Text('Report missing address',
                      style: AppText.h2),
                ],
              ),
            ),
            Expanded(
              child: _submitted ? _buildSuccess() : _buildForm(),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.binColors.primaryLight,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.check, size: 32, color: context.binColors.primary),
            ),
            const SizedBox(height: Spacing.lg),
            const Text('Thanks! We\u2019ll look into it.',
                style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.sm),
            Text(
              'We\u2019ll work on adding your address so you can see your bin collection dates.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back', style: AppText.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          Spacing.xxl, Spacing.lg, Spacing.xxl, Spacing.xxl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: context.binColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.container),
                border: Border.all(color: context.binColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderMark(icon: Icons.flag_outlined),
                  SizedBox(height: Spacing.md),
                  Text('Help us add your address', style: AppText.h2),
                  SizedBox(height: 4),
                  Text(
                    'Tell us about your address and we\u2019ll work on getting your collection dates.',
                    style: AppText.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Text(
              'YOUR DETAILS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: context.binColors.textMuted,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDeco('Your name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: Spacing.md),
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
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _addressCtrl,
              decoration: _inputDeco('Full address'),
              maxLines: 2,
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _notesCtrl,
              decoration: _inputDeco('Notes (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: Spacing.xxl),
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
                    : const Text('Submit report', style: AppText.button),
              ),
            ),
            const SizedBox(height: Spacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel',
                    style: TextStyle(
                        color: context.binColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMark extends StatelessWidget {
  final IconData icon;

  const _HeaderMark({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: forestBandedGradient(dark: false),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 24, color: Colors.white),
    );
  }
}
