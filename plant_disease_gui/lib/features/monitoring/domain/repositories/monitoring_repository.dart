import '../entities/sensor_data_entity.dart';

abstract class MonitoringRepository {
  Future<void> updateSensorValue(String key, double value);
  Stream<SensorDataEntity> get sensorDataStream;
  Future<void> loadInitialData();
}
