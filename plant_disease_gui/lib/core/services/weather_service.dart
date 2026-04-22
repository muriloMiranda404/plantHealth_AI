import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final double humidity;
  final double rainProbability;
  final String condition;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.rainProbability,
    required this.condition,
  });
}

class WeatherService {
  final http.Client client;

  WeatherService({required this.client});

  Future<WeatherData?> getForecast(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,weather_code&hourly=precipitation_probability&forecast_days=1'
    );

    try {
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final current = data['current'];
        final rainProb = (data['hourly']['precipitation_probability'] as List).first.toDouble();

        return WeatherData(
          temperature: current['temperature_2m'].toDouble(),
          humidity: current['relative_humidity_2m'].toDouble(),
          rainProbability: rainProb,
          condition: _mapWeatherCode(current['weather_code']),
        );
      }
    } catch (e) {
      print('WeatherService: Erro ao buscar clima: $e');
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
