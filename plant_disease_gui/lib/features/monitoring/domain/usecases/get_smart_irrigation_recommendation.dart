import 'package:plant_health/core/services/weather_service.dart';

class SmartIrrigationRecommendation {
  final bool shouldPostpone;
  final String reason;

  SmartIrrigationRecommendation({required this.shouldPostpone, required this.reason});
}

class GetSmartIrrigationRecommendation {
  final WeatherService weatherService;

  GetSmartIrrigationRecommendation(this.weatherService);

  Future<SmartIrrigationRecommendation> call(double lat, double lon) async {
    final weather = await weatherService.getForecast(lat, lon);
    
    if (weather == null) {
      return SmartIrrigationRecommendation(
        shouldPostpone: false, 
        reason: "Sem dados meteorológicos."
      );
    }

    if (weather.rainProbability > 70) {
      return SmartIrrigationRecommendation(
        shouldPostpone: true,
        reason: "Probabilidade de chuva de ${weather.rainProbability.toStringAsFixed(0)}%. Economizando água!"
      );
    }

    if (weather.humidity > 85 && weather.temperature < 20) {
      return SmartIrrigationRecommendation(
        shouldPostpone: true,
        reason: "Tempo muito úmido e frio. A evaporação será lenta."
      );
    }

    return SmartIrrigationRecommendation(
      shouldPostpone: false,
      reason: "Condições ideais para irrigação manual se necessário."
    );
  }
}
