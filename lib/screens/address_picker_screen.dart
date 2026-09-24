import 'package:flutter/material.dart';
import 'package:derby_bins/services/council_api.dart';
import 'package:derby_bins/services/schedule_service.dart';
import 'package:derby_bins/services/theme_service.dart';
import 'package:derby_bins/theme/app_colors.dart';
import 'package:derby_bins/theme/spacing.dart';
import 'package:derby_bins/theme/typography.dart';
import 'package:derby_bins/widgets/app_background.dart';
import 'calendar_screen.dart';
import 'report_missing_address_screen.dart';

class AddressPickerScreen extends StatelessWidget {
  final String postcode;
  final String councilSlug;
  final String councilName;
  final List<CouncilAddress> addresses;
  final bool isCalendar;
  final ThemeService? themeService;
  const AddressPickerScreen({
    super.key,
    required this.postcode,
    required this.councilSlug,
    required this.councilName,
    required this.addresses,
    this.isCalendar = false,
    this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: ScreenBackground(child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xxl, vertical: Spacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            isCalendar
                                ? 'Choose your calendar'
                                : 'Choose your address',
                            style: AppText.h1),
                        const SizedBox(height: 2),
                        Text(
                          isCalendar
                              ? '2 calendars · $councilName'
                              : '${addresses.length} addresses found Â· $postcode',
                          style: AppTypography.caption
                              .copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      clearResolveCache();
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close,
                              size: 14,
                              color: colors.textSecondary),
                          const SizedBox(width: 6),
                          Text('Change',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.xxl, Spacing.lg, Spacing.xxl, Spacing.xxl),
                children: [
                  const SizedBox(height: Spacing.sm),
                  ...addresses.map((a) {
                    final idx = a.label.lastIndexOf(',');
                    final street = idx < 0
                        ? a.label
                        : a.label.substring(0, idx).trim();
                    final sub = idx < 0
                        ? null
                        : a.label.substring(idx + 1).trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: Spacing.sm),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.container),
                        border: Border.all(color: colors.border),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => CalendarScreen(
                                  postcode: postcode,
                                  councilSlug: councilSlug,
                                  councilName: councilName,
                                  uprn: a.uprn,
                                  addressLabel: a.label,
                                  addresses: addresses,
                                  themeService: themeService,
                                ),
                              ),
                              (route) => false,
                            );
                          },
                          borderRadius:
                              BorderRadius.circular(AppRadius.container),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: Spacing.lg, horizontal: Spacing.md),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colors.primaryLight,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.home_outlined,
                                      size: 20, color: colors.primary),
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(street,
                                          style: AppTypography.title.copyWith(
                                              color: colors.textPrimary)),
                                      if (sub != null) ...[
                                        const SizedBox(height: 2),
                                        Text(sub,
                                            style: AppTypography.caption),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 18, color: colors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: Spacing.sm),
                  if (!isCalendar)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportMissingAddressScreen(
                                postcode: postcode,
                                councilSlug: councilSlug,
                                councilName: councilName,
                              ),
                            ),
                          );
                        },
                        borderRadius:
                            BorderRadius.circular(AppRadius.container),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.lg),
                          decoration: BoxDecoration(
                            color: colors.surfaceTinted,
                            borderRadius:
                                BorderRadius.circular(AppRadius.container),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.add_circle_outline,
                                    size: 20, color: colors.primary),
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('My address isn\u2019t listed',
                                        style: AppTypography.title.copyWith(
                                            color: colors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Let us know and we\u2019ll work on adding it',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 18, color: colors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.xxl),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }
}
