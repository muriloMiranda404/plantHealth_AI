import 'package:flutter/material.dart';
import 'cards.dart';

class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool isHealthy;
  final bool isDarkMode;
  final double cardRadius;
  final double borderWidth;
  final bool glassCards;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.isHealthy = true,
    this.isDarkMode = true,
    this.cardRadius = 25.0,
    this.borderWidth = 1.5,
    this.glassCards = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;

    return InteractiveCard(
      isDarkMode: isDarkMode,
      borderRadius: cardRadius,
      borderWidth: borderWidth,
      glassEffect: glassCards,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                if (!isHealthy)
                  const Icon(Icons.warning, color: Colors.redAccent, size: 16),
              ],
            ),
            const Spacer(),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
