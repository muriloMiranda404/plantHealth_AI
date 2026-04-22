import 'package:plant_health/core/data/datasources/local_database.dart';

abstract class MonitoringLocalDataSource {
  Future<void> saveHistory(String key, double value);
  Future<List<Map<String, dynamic>>> getHistory({int limit = 500});
}

class MonitoringLocalDataSourceImpl implements MonitoringLocalDataSource {
  final LocalDatabase localDatabase;

  MonitoringLocalDataSourceImpl(this.localDatabase);

  @override
  Future<void> saveHistory(String key, double value) async {
    final db = await localDatabase.database;
    await db.insert('history', {
      'sensor_key': key,
      'value': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory({int limit = 500}) async {
    final db = await localDatabase.database;
    return await db.query('history', orderBy: 'timestamp DESC', limit: limit);
  }
}
