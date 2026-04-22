import '../entities/sensor_data_entity.dart';
import '../repositories/monitoring_repository.dart';

class GetSensorData {
  final MonitoringRepository repository;

  GetSensorData(this.repository);

  Stream<SensorDataEntity> call() {
    return repository.sensorDataStream;
  }
}
