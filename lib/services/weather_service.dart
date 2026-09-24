import 'dart:convert';
import 'package:http/http.dart' as http;

enum WeatherLoadStatus { loading, success, failure }

class WeatherData {
  final double temperature;
  final int weatherCode;
  final String condition;
  final bool willRain;

  const WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.condition,
    required this.willRain,
  });
}

class WeatherBundle {
  final WeatherData? now;
  const WeatherBundle({this.now});
}

class WeatherService {
  static const Map<String, List<double>> _councilCoords = {
    'derby': [52.9219, -1.4756],
    'erewash': [52.9305, -1.3259],
    'ambervalley': [53.0153, -1.4707],
    'highpeak': [53.3483, -1.9747],
    'derbyshiredales': [53.1630, -1.6120],
    'bolsover': [53.2285, -1.2900],
    'chesterfield': [53.2350, -1.4216],
    'southderbyshire': [52.8200, -1.6300],
    'northeastderbyshire': [53.2400, -1.4300],
  };

  // Single call returns the live "now" reading for the council's location.
  static Future<WeatherBundle> fetchWeather(String councilSlug) async {
    try {
      final coords = _councilCoords[councilSlug] ?? [52.9219, -1.4756];
      final lat = coords[0];
      final lon = coords[1];
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,weather_code,precipitation'
        '&timezone=Europe/London',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const WeatherBundle();

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      // Live "now"
      WeatherData? now;
      try {
        final cur = data['current'] as Map<String, dynamic>;
        final temp = (cur['temperature_2m'] as num).toDouble();
        final code = (cur['weather_code'] as num).toInt();
        final precip = (cur['precipitation'] as num?)?.toDouble() ?? 0;
        now = WeatherData(
          temperature: temp,
          weatherCode: code,
          condition: _conditionFromCode(code),
          willRain: precip > 0.1,
        );
      } catch (_) {
        now = null;
      }

      return WeatherBundle(now: now);
    } catch (_) {
      return const WeatherBundle();
    }
  }

  static String _conditionFromCode(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly Cloudy';
    if (code <= 49) return 'Fog';
    if (code <= 59) return 'Drizzle';
    if (code <= 69) return 'Rain';
    if (code <= 79) return 'Snow';
    if (code <= 82) return 'Rain Showers';
    if (code <= 86) return 'Snow Showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }
}
