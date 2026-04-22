import '../repositories/monitoring_repository.dart';

class UpdateSensorValue {
  final MonitoringRepository repository;

  UpdateSensorValue(this.repository);

  Future<void> call(String key, double value) async {
    await repository.updateSensorValue(key, value);
  }
}
