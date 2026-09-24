import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class WeatherCard extends StatefulWidget {
  final String councilSlug;
  const WeatherCard({
    super.key,
    required this.councilSlug,
  });

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherBundle? _weather;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await WeatherService.fetchWeather(widget.councilSlug);
    if (mounted) {
      setState(() {
        _weather = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.binColors.surfaceTinted,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.binColors.textMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Loading weather...', style: AppTypography.caption),
          ],
        ),
      );
    }

    if (_weather == null) return const SizedBox.shrink();

    final sections = <Widget>[];
    if (_weather!.now != null) {
      sections.add(_section(context, 'Today', _weather!.now!, isNow: true));
    }
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          sections[i],
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String label, WeatherData w,
      {required bool isNow}) {
    final icon = weatherIconForCode(w.weatherCode);
    final color = weatherColorForCode(w.weatherCode);
    final temp = '${w.temperature.round()}°C';
    final message = isNow
        ? (w.willRain ? 'Raining now' : 'Dry now')
        : (w.willRain
            ? 'Rain expected. Bring your bins in promptly.'
            : 'Good conditions for putting bins out.');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption
                      .copyWith(color: context.binColors.textMuted),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      w.condition ?? 'Unknown',
                      style: AppTypography.title.copyWith(color: color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      temp,
                      style: AppTypography.title.copyWith(color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTypography.caption
                      .copyWith(color: color.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData weatherIconForCode(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code <= 3) return Icons.cloud;
  if (code <= 49) return Icons.foggy;
  if (code <= 59) return Icons.grain;
  if (code <= 69) return Icons.water_drop;
  if (code <= 79) return Icons.ac_unit;
  if (code <= 82) return Icons.show_chart;
  if (code <= 99) return Icons.thunderstorm;
  return Icons.wb_cloudy;
}

Color weatherColorForCode(int code) {
  if (code == 0) return const Color(0xFFE68A2E);
  if (code <= 3) return const Color(0xFF5A8FBF);
  if (code <= 49) return const Color(0xFF8A918D);
  if (code <= 69) return const Color(0xFF4A7FB5);
  if (code <= 82) return const Color(0xFF4A7FB5);
  if (code <= 99) return const Color(0xFF7B61A5);
  return const Color(0xFF5A8FBF);
}
