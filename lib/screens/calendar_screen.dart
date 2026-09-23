import 'package:flutter/material.dart';
import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/services/council_api.dart';
import 'package:derby_bins/services/notification_service.dart';
import 'package:derby_bins/services/reminder_store.dart';
import 'package:derby_bins/services/schedule_cache.dart';
import 'package:derby_bins/services/schedule_service.dart';
import 'package:derby_bins/services/session_store.dart';
import 'package:derby_bins/services/theme_service.dart';
import 'package:derby_bins/theme/app_colors.dart';
import 'package:derby_bins/theme/spacing.dart';
import 'package:derby_bins/theme/typography.dart';
import 'address_picker_screen.dart';
import 'home_page.dart';

class CalendarScreen extends StatefulWidget {
  final String postcode;
  final String councilSlug;
  final String councilName;
  final String? uprn;
  final String? addressLabel;
  final List<CouncilAddress>? addresses;
  final ThemeService? themeService;
  const CalendarScreen({
    super.key,
    required this.postcode,
    this.councilSlug = 'derby',
    this.councilName = 'Derby City Council',
    this.uprn,
    this.addressLabel,
    this.addresses,
    this.themeService,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  ResolveResult? _resolution;
  String _status = 'loading';
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    try {
      final result = await resolvePostcode(widget.postcode,
          force: force, uprn: widget.uprn, addressLabel: widget.addressLabel,
          councilSlug: widget.councilSlug, councilName: widget.councilName);
      if (result is ResolveUncovered) {
        if (await _loadCached()) return;
        setState(() {
          _status = 'error';
          _errorMsg =
              'We could not find collection data for this postcode, and the live council feed could not identify it either. Try a different postcode.';
        });
        return;
      }
      if (result is ResolveNoData) {
        if (await _loadCached()) return;
        setState(() {
          _status = 'error';
          _errorMsg =
              'Couldn\u2019t reach the server. Check your internet connection and try again.';
        });
        return;
      }
      setState(() {
        _resolution = result;
        if (result is ResolveCoverage) {
          _status = 'coverage';
        } else {
          _status = 'ready';
        }
      });
      if (result is ResolveReady) {
        SessionStore.save(SavedSession(
          councilSlug: widget.councilSlug,
          councilName: widget.councilName,
          postcode: widget.postcode,
          uprn: widget.uprn ?? '',
          addressLabel: widget.addressLabel ?? widget.postcode,
        ));
        // If reminders were enabled during onboarding, schedule them now that
        // we know the user's area.
        if (await ReminderStore.isEnabled()) {
          await NotificationService.scheduleReminders(
            (_resolution as ResolveReady).area,
            widget.councilSlug,
          );
        }
        if (widget.uprn != null) {
          await ScheduleCache.save(
            uprn: widget.uprn!,
            postcode: widget.postcode,
            councilSlug: widget.councilSlug,
            councilName: widget.councilName,
            area: (_resolution as ResolveReady).area,
            isLive: (_resolution as ResolveReady).liveCouncil,
          );
        }
      }
    } on ScheduleError catch (e) {
      if (await _loadCached()) return;
      setState(() {
        _status = 'error';
        _errorMsg = e.message;
      });
    } catch (_) {
      if (await _loadCached()) return;
      setState(() {
        _status = 'error';
        _errorMsg = 'Something went wrong loading your schedule.';
      });
    }
  }

  AreaSchedule? get _area =>
      _resolution is ResolveReady ? (_resolution as ResolveReady).area : null;

  Future<bool> _loadCached() async {
    if (widget.uprn == null) return false;
    final cached = await ScheduleCache.load(widget.uprn!);
    if (cached != null && mounted) {
      setState(() {
        _resolution = ResolveReady(
          widget.postcode, widget.councilSlug, cached.councilName,
          cached.area, null, cached.isLive,
        );
        _status = 'ready';
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_status == 'loading') {
      return _poppable(_loadingView());
    }
    if (_status == 'error') {
      return _poppable(_errorView());
    }
    if (_status == 'coverage' && _resolution is ResolveCoverage) {
      return _poppable(_coverageView(_resolution as ResolveCoverage));
    }
    return _readyView();
  }

  // The loading/error/coverage/no-data states are full-screen and sit at the
  // root route, so a normal back gesture would quit the app. Intercept it and
  // return the user to postcode entry instead of closing the app.
  Widget _poppable(Widget child) => PopScope(
        canPop: false,
        onPopInvoked: (_) =>
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
        child: Scaffold(body: child),
      );

  Widget _loadingView() {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: context.binColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.container),
          border: Border.all(color: context.binColors.border),
        ),
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: context.binColors.primary),
            const SizedBox(height: Spacing.lg),
            const Text('Finding your collections', style: AppText.h2),
            const SizedBox(height: Spacing.sm),
            Text(
              'Looking up bin collections for ${widget.postcode}...',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: context.binColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.container),
          border: Border.all(color: context.binColors.border),
        ),
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.binColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(Icons.cloud_off_outlined,
                  size: 24, color: context.binColors.error),
            ),
            const SizedBox(height: Spacing.lg),
            const Text("Couldn't load your schedule", style: AppText.h2),
            const SizedBox(height: Spacing.sm),
            Text(_errorMsg,
                textAlign: TextAlign.center,
                style: AppText.body),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _load(force: true),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.lg)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 15, color: context.binColors.primary),
                    const SizedBox(width: 7),
                    const Text('Try again', style: AppText.button),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                clearResolveCache();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: Text('Use a different postcode',
                  style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: context.binColors.primary,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverageView(ResolveCoverage c) {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: context.binColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.container),
          border: Border.all(color: context.binColors.border),
        ),
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: context.binColors.primaryLight,
                borderRadius: BorderRadius.circular(27),
              ),
              child: Icon(Icons.check, size: 26, color: context.binColors.primary),
            ),
            const SizedBox(height: Spacing.lg),
            Text(c.councilName,
                style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: -0.3,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.xl),
            const Text(
              'Great news - your council is covered by our live feed. We are working on adding per-address collection dates for your area.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: Spacing.xl),
            TextButton(
              onPressed: () {
                clearResolveCache();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: Text('Try another postcode',
                  style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: context.binColors.primary,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readyView() {
    final area = _area!;
    final isLive = (_resolution as ResolveReady).liveCouncil;

    return HomePage(
      postcode: widget.postcode,
      councilSlug: widget.councilSlug,
      councilName: (_resolution as ResolveReady).councilName,
      uprn: widget.uprn,
      addressLabel: widget.addressLabel,
      area: area,
      isLive: isLive,
      themeService: widget.themeService,
    );
  }
}
