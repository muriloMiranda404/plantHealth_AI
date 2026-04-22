class SensorDataEntity {
  final Map<String, double> values;
  final Map<String, List<SensorPoint>> histories;

  SensorDataEntity({
    required this.values,
    required this.histories,
  });
}

class SensorPoint {
  final double x;
  final double y;

  SensorPoint(this.x, this.y);
}
