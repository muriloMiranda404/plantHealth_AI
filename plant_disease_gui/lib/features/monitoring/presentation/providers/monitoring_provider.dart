import 'package:flutter/material.dart';
import 'package:plant_health/core/services/weather_service.dart';
import '../../domain/entities/sensor_data_entity.dart';
import '../../domain/usecases/get_sensor_data.dart';
import '../../domain/usecases/update_sensor_value.dart';
import '../../domain/usecases/get_smart_irrigation_recommendation.dart';

class MonitoringProvider with ChangeNotifier {
  final GetSensorData getSensorData;
  final UpdateSensorValue updateSensorValue;
  final GetSmartIrrigationRecommendation getSmartIrrigationRecommendation;

  SensorDataEntity? _currentData;
  SensorDataEntity? get currentData => _currentData;

  SmartIrrigationRecommendation? _recommendation;
  SmartIrrigationRecommendation? get recommendation => _recommendation;

  WeatherData? _weatherData;
  WeatherData? get weatherData => _weatherData;

  MonitoringProvider({
    required this.getSensorData,
    required this.updateSensorValue,
    required this.getSmartIrrigationRecommendation,
  }) {
    getSensorData().listen((data) {
      _currentData = data;
      notifyListeners();
    });
  }

  Future<void> checkSmartIrrigation(double lat, double lon) async {
    _recommendation = await getSmartIrrigationRecommendation(lat, lon);
    _weatherData = await getSmartIrrigationRecommendation.weatherService
        .getForecast(lat, lon);
    notifyListeners();
  }

  Future<void> updateSensor(String key, double value) async {
    await updateSensorValue(key, value);
  }
}
