import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/slide_fade_transition.dart';

class AnalyticsTab extends StatelessWidget {
  final bool isDarkMode;
  final List<String> analyticsOrder;
  final List<String> enabledSensorKeys;
  final String activeGraphKey;
  final Map<String, List<FlSpot>> histories;
  final Map<String, String> sensorUnits;
  final List<String> comparisonSensors;
  final Function(int, int) onReorder;
  final Function(String) onSensorTap;
  final VoidCallback onSensorManager;
  final VoidCallback onFullscreenChart;
  final VoidCallback onExport;
  final VoidCallback onReset;
  final Widget Function(List<List<FlSpot>>, List<Color>, List<String>)
  chartBuilder;
  final dynamic Function(String) getSensorConfig;
  final double Function(String, double, String) convertValue;

  const AnalyticsTab({
    super.key,
    required this.isDarkMode,
    required this.analyticsOrder,
    required this.enabledSensorKeys,
    required this.activeGraphKey,
    required this.histories,
    required this.sensorUnits,
    required this.comparisonSensors,
    required this.onReorder,
    required this.onSensorTap,
    required this.onSensorManager,
    required this.onFullscreenChart,
    required this.onExport,
    required this.onReset,
    required this.chartBuilder,
    required this.getSensorConfig,
    required this.convertValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    final config = getSensorConfig(activeGraphKey);

    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: onReorder,
      children: analyticsOrder.asMap().entries.map((entry) {
        final index = entry.key;
        final key = entry.value;
        if (key == 'chart') {
          return SlideFadeTransition(
            key: const ValueKey('chart'),
            index: index,
            child: Container(
              height: 240,
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black26,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          comparisonSensors.isEmpty
                              ? config.name
                              : "Comparativo",
                          style: TextStyle(
                            color: comparisonSensors.isEmpty
                                ? config.color
                                : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: onSensorManager,
                            ),
                            IconButton(
                              icon: const Icon(Icons.fullscreen, size: 20),
                              onPressed: onFullscreenChart,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: enabledSensorKeys.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sensors_off,
                                    color: subTextColor,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Sem sensores configurados",
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : chartBuilder(
                              comparisonSensors.isEmpty
                                  ? [
                                      histories[activeGraphKey]!
                                          .map(
                                            (spot) => FlSpot(
                                              spot.x,
                                              convertValue(
                                                activeGraphKey,
                                                spot.y,
                                                sensorUnits[activeGraphKey] ??
                                                    "",
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ]
                                  : comparisonSensors
                                        .where(
                                          (k) => enabledSensorKeys.contains(k),
                                        )
                                        .map(
                                          (k) => histories[k]!
                                              .map(
                                                (spot) => FlSpot(
                                                  spot.x,
                                                  convertValue(
                                                    k,
                                                    spot.y,
                                                    sensorUnits[k] ?? "",
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        )
                                        .toList(),
                              comparisonSensors.isEmpty
                                  ? [config.color]
                                  : comparisonSensors
                                        .where(
                                          (k) => enabledSensorKeys.contains(k),
                                        )
                                        .map(
                                          (k) =>
                                              getSensorConfig(k).color as Color,
                                        )
                                        .toList(),
                              comparisonSensors.isEmpty
                                  ? [activeGraphKey]
                                  : comparisonSensors
                                        .where(
                                          (k) => enabledSensorKeys.contains(k),
                                        )
                                        .toList(),
                            ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: onExport,
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text(
                            "Exportar",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onReset,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text(
                            "Resetar",
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return SlideFadeTransition(
            key: const ValueKey('sensor_selector'),
            index: index,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  "SELECIONE UM SENSOR",
                  style: TextStyle(
                    fontSize: 10,
                    color: subTextColor.withValues(alpha: 0.5),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: enabledSensorKeys.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final k = entry.value;
                    final sCfg = getSensorConfig(k);
                    final isSelected = activeGraphKey == k;
                    return SlideFadeTransition(
                      index: idx,
                      delay: const Duration(milliseconds: 30),
                      child: GestureDetector(
                        onTap: () => onSensorTap(k),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? sCfg.color.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected
                                  ? sCfg.color
                                  : subTextColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                sCfg.icon,
                                size: 16,
                                color: isSelected ? sCfg.color : subTextColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                sCfg.name,
                                style: TextStyle(
                                  color: isSelected ? textColor : subTextColor,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }
      }).toList(),
    );
  }
}
