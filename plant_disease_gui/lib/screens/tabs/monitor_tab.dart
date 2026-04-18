import 'package:flutter/material.dart';

class MonitorTab extends StatelessWidget {
  final bool isDarkMode;
  final bool isEcoModeEnabled;
  final bool isFirstAidMode;
  final List<String> dashboardOrder;
  final Map<String, double> sensorData;
  final Map<String, bool> sensorIntegrity;
  final Function(int, int) onReorder;
  final Widget Function(String) cardBuilder;

  const MonitorTab({
    super.key,
    required this.isDarkMode,
    required this.isEcoModeEnabled,
    required this.isFirstAidMode,
    required this.dashboardOrder,
    required this.sensorData,
    required this.sensorIntegrity,
    required this.onReorder,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      buildDefaultDragHandles: false,
      header: Column(
        children: [
          if (isEcoModeEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.eco, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "MODO ECONÔMICO ATIVO: Economizando bateria da Raspberry Pi",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (isFirstAidMode)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orangeAccent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "MODO PRIMEIROS SOCORROS: Dados em cache",
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      onReorder: onReorder,
      children: dashboardOrder.map((key) {
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              cardBuilder(key),
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: dashboardOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: isDarkMode ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
