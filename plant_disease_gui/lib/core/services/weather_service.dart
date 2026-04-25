import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final double humidity;
  final double rainProbability;
  final String condition;
  final double windSpeed;
  final bool isDay;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.rainProbability,
    required this.condition,
    required this.windSpeed,
    required this.isDay,
  });
}

class WeatherService {
  final http.Client client;

  WeatherService({required this.client});

  Future<WeatherData?> getForecast(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,is_day,weather_code,wind_speed_10m&hourly=precipitation_probability&timezone=auto&forecast_days=1',
    );

    try {
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final current = data['current'];

        final DateTime now = DateTime.now();
        final List<dynamic> hourlyTimes = data['hourly']['time'];
        final List<dynamic> hourlyRain =
            data['hourly']['precipitation_probability'];

        double rainProb = 0.0;

        for (int i = 0; i < hourlyTimes.length; i++) {
          final DateTime time = DateTime.parse(hourlyTimes[i]);
          if (time.year == now.year &&
              time.month == now.month &&
              time.day == now.day &&
              time.hour == now.hour) {
            rainProb = hourlyRain[i].toDouble();
            break;
          }
        }

        return WeatherData(
          temperature: current['temperature_2m'].toDouble(),
          humidity: current['relative_humidity_2m'].toDouble(),
          rainProbability: rainProb,
          condition: _mapWeatherCode(current['weather_code']),
          windSpeed: current['wind_speed_10m'].toDouble(),
          isDay: current['is_day'] == 1,
        );
      }
    } catch (e) {
      debugPrint('WeatherService Error: $e');
    }
    return null;
  }

  String _mapWeatherCode(int code) {
    if (code == 0) return "Céu Limpo";
    if (code < 3) return "Parcialmente Nublado";
    if (code < 50) return "Nevoeiro";
    if (code < 60) return "Garoa";
    if (code < 70) return "Chuva";
    if (code < 80) return "Neve";
    return "Tempestade";
  }
}
