import 'package:flutter/material.dart';
import '../../domain/entities/sensor_config_entity.dart';

class SensorConfigModel extends SensorConfigEntity {
  SensorConfigModel({
    required super.key,
    required super.name,
    required super.unit,
    required super.icon,
    required super.color,
    super.min,
    super.max,
    super.step,
  });

  factory SensorConfigModel.fromMap(Map<String, dynamic> map) {
    return SensorConfigModel(
      key: map['key'],
      name: map['name'] ?? '',
      unit: map['unit'] ?? '',
      icon: _getIconData(map['icon']),
      color: Color(map['color'] ?? 0xFF00FF00),
      min: (map['min'] ?? 0).toDouble(),
      max: (map['max'] ?? 100).toDouble(),
      step: (map['step'] ?? 1).toDouble(),
    );
  }

  static IconData _getIconData(dynamic icon) {
    if (icon is int) return IconData(icon, fontFamily: 'MaterialIcons');
    return Icons.sensors;
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'name': name,
      'unit': unit,
      'icon': icon.codePoint,
      'color': color.value,
      'min': min,
      'max': max,
      'step': step,
    };
  }
}
