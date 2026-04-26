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
    switch (code) {
      case 0:
        return "Céu Limpo";
      case 1:
        return "Principalmente Limpo";
      case 2:
        return "Parcialmente Nublado";
      case 3:
        return "Nublado";
      case 45:
      case 48:
        return "Nevoeiro";
      case 51:
      case 53:
      case 55:
        return "Garoa";
      case 61:
      case 63:
      case 65:
        return "Chuva";
      case 71:
      case 73:
      case 75:
        return "Neve";
      case 80:
      case 81:
      case 82:
        return "Pancadas de Chuva";
      case 95:
      case 96:
      case 99:
        return "Tempestade";
      default:
        return "Desconhecido";
    }
  }
}
