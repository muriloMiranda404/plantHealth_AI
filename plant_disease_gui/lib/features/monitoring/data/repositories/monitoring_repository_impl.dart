import 'dart:async';
import '../../domain/entities/sensor_data_entity.dart';
import '../../domain/repositories/monitoring_repository.dart';
import '../datasources/monitoring_local_data_source.dart';

class MonitoringRepositoryImpl implements MonitoringRepository {
  final MonitoringLocalDataSource localDataSource;
  final _controller = StreamController<SensorDataEntity>.broadcast();
  
  final Map<String, double> _currentValues = {};
  final Map<String, List<SensorPoint>> _histories = {};

  MonitoringRepositoryImpl(this.localDataSource);

  @override
  Stream<SensorDataEntity> get sensorDataStream => _controller.stream;

  @override
  Future<void> loadInitialData() async {
    final historyData = await localDataSource.getHistory();
    for (var item in historyData) {
      final key = item['sensor_key'] as String;
      final value = item['value'] as double;
      final timestamp = item['timestamp'] as int;
      
      if (!_histories.containsKey(key)) _histories[key] = [];
      _histories[key]!.add(SensorPoint(timestamp.toDouble(), value));
      
      if (!_currentValues.containsKey(key)) {
        _currentValues[key] = value;
      }
    }
    _emit();
  }

  @override
  Future<void> updateSensorValue(String key, double value) async {
    _currentValues[key] = value;
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    
    if (!_histories.containsKey(key)) _histories[key] = [];
    _histories[key]!.add(SensorPoint(now, value));
    if (_histories[key]!.length > 50) _histories[key]!.removeAt(0);
    
    await localDataSource.saveHistory(key, value);
    _emit();
  }

  void _emit() {
    _controller.add(SensorDataEntity(
      values: Map.from(_currentValues),
      histories: Map.from(_histories),
    ));
  }
}
