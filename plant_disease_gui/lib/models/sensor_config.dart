import 'package:flutter/material.dart';

class SensorConfig {
  final String key;
  final String name;
  final String unit;
  final IconData icon;
  final Color color;
  final double min;
  final double max;
  final double step;

  SensorConfig({
    required this.key,
    required this.name,
    required this.unit,
    required this.icon,
    required this.color,
    this.min = 0,
    this.max = 100,
    this.step = 1,
  });
}
