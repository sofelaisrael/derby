import 'package:flutter/material.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../services/weather_service.dart';
import '../widgets/bin_icon.dart';
import '../widgets/bin_swatch.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'banded_gradient.dart';
import 'weather_card.dart';

class TodayBanner extends StatelessWidget {
  final DateTime date;
  final List<BinCollection> collections;
  final String councilSlug;

  const TodayBanner({
    super.key,
    required this.date,
    required this.collections,
    this.councilSlug = 'derby',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final theme = Theme.of(context);
    final presentations = collections
        .map((collection) =>
            CouncilScheme.resolve(councilSlug, collection.stream))
        .toList();
    final labels = presentations.map((presentation) => presentation.label);
    final labelList = labels.toList();
    final collectionText = labelList.length == 1
        ? '${labelList.first} goes out today'
        : '${labelList.join(' and ')} go out today';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final semanticDate =
        '${weekdayNames[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year}';
    final semanticLabel = "$semanticDate. Today's collection. $collectionText.";

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.primaryLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 60,
              decoration: BoxDecoration(
                gradient: forestBandedGradient(
                  dark: theme.brightness == Brightness.dark,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x40000000)),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdayNames[date.weekday - 1]
                              .substring(0, 3)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${date.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY'S COLLECTION",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    collectionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final presentation in presentations)
                  BinSwatch(p: presentation, size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBinChip extends StatelessWidget {
  final BinPresentation presentation;
  final double maxWidth;

  const _HeroBinChip({
    required this.presentation,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final color = presentation.themed(context);
    const foreground = Colors.white;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BinIcon(
            presentation: presentation,
            size: 12,
            color: foreground,
            semanticLabel: presentation.label,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              presentation.label.toUpperCase(),
              semanticsLabel: presentation.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: foreground,
                letterSpacing: 1.1,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroCollectionCard extends StatelessWidget {
  final String binLabel;
  final String display;
  final String? subtitle;
  final List<BinCollection> collections;
  final VoidCallback onTap;
  final String councilSlug;
  final WeatherLoadStatus weatherStatus;
  final WeatherBundle? weatherData;

  const HeroCollectionCard({
    super.key,
    required this.binLabel,
    required this.display,
    this.subtitle,
    required this.collections,
    required this.onTap,
    this.councilSlug = 'derby',
    this.weatherStatus = WeatherLoadStatus.failure,
    this.weatherData,
  });

  ({String? number, String label}) _splitDisplay() {
    final match = RegExp(r'^(\d+) Days$').firstMatch(display);
    if (match != null) {
      return (number: match.group(1), label: 'Days');
    }
    return (number: null, label: display);
  }

  String _semanticLabel() {
    if (collections.isEmpty) {
      return 'No collections scheduled. Open calendar.';
    }
    final date = subtitle == null ? display : '$display, $subtitle';
    return '$date, $binLabel. Open calendar.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.binColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.of(context).disableAnimations;
    final animDuration =
        reduce ? Duration.zero : const Duration(milliseconds: 700);
    final curve = reduce ? Curves.linear : Curves.easeOutCubic;
    final split = _splitDisplay();
    final radius = BorderRadius.circular(AppSpacing.radiusXl);
    const textColor = Colors.white;
    const mutedColor = Color(0xFFF2F6F0);

    return Semantics(
      button: true,
      label: _semanticLabel(),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.16),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Ink(
            decoration: BoxDecoration(
              gradient: forestBandedGradient(dark: dark),
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: dark ? 0.28 : 0.20),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x33000000)),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (collections.isNotEmpty)
                        _binChips(context)
                      else
                        _emptyCollectionChip(mutedColor),
                      const SizedBox(height: AppSpacing.xl),
                      AnimatedSwitcher(
                        duration: animDuration,
                        switchInCurve: curve,
                        switchOutCurve: curve,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: FittedBox(
                          key: ValueKey(display),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _countdownContent(
                            split,
                            textColor: textColor,
                            mutedColor: mutedColor,
                          ),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              subtitle!,
                              style: AppTypography.body.copyWith(
                                color: mutedColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _weatherRow(mutedColor),
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

  Widget _binChips(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final collection in collections)
              Builder(
                builder: (context) {
                  final presentation =
                      CouncilScheme.resolve(councilSlug, collection.stream);
                  return _HeroBinChip(
                    presentation: presentation,
                    maxWidth: constraints.maxWidth,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _emptyCollectionChip(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_outlined, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'No collection scheduled',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownContent(
    ({String? number, String label}) split, {
    required Color textColor,
    required Color mutedColor,
  }) {
    if (split.number != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            split.number!,
            style: TextStyle(
              fontSize: 64,
              height: 0.9,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            split.label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: mutedColor,
            ),
          ),
        ],
      );
    }
    return Text(
      split.label,
      style: TextStyle(
        fontSize: split.label.length > 9 ? 38 : 48,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        color: textColor,
      ),
    );
  }

  Widget _weatherRow(Color mutedColor) {
    Widget leading;
    String label;
    if (weatherStatus == WeatherLoadStatus.loading) {
      leading = const Icon(
        Icons.cloud_queue_outlined,
        size: 20,
        color: Colors.white,
      );
      label = 'Loading weather';
    } else if (weatherStatus == WeatherLoadStatus.success &&
        weatherData?.now != null) {
      final data = weatherData!.now!;
      leading = Icon(
        weatherIconForCode(data.weatherCode),
        size: 20,
        color: Colors.white,
      );
      label = '${data.condition}  ${data.temperature.round()}°C  '
          '${data.willRain ? 'Raining now' : 'Dry now'}';
    } else {
      leading = const Icon(
        Icons.cloud_off_outlined,
        size: 20,
        color: Colors.white,
      );
      label = 'Weather unavailable';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: mutedColor),
            ),
          ),
        ],
      ),
    );
  }
}
