import 'dart:math' as math;
import 'package:flutter/material.dart';

class LeafBackground extends StatefulWidget {
  final bool isDarkMode;
  const LeafBackground({super.key, required this.isDarkMode});

  @override
  State<LeafBackground> createState() => _LeafBackgroundState();
}

class _LeafBackgroundState extends State<LeafBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<LeafModel> _leaves = List.generate(25, (i) {
    final leafIcons = [
      Icons.eco,
      Icons.eco_outlined,
      Icons.grass,
      Icons.local_florist,
      Icons.nature,
      Icons.park,
      Icons.yard,
      Icons.filter_vintage,
      Icons.energy_savings_leaf,
      Icons.spa,
    ];
    final random = math.Random();
    return LeafModel(
      x: random.nextDouble(),
      y: random.nextDouble() * -2.0,
      speed: random.nextDouble() * 0.002 + 0.001,
      size: random.nextDouble() * 40 + 45,
      rotation: random.nextDouble() * 2 * math.pi,
      initialProgress: random.nextDouble(),
      icon: leafIcons[random.nextInt(leafIcons.length)],
    );
  });

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        for (var leaf in _leaves) {
          leaf.y += leaf.speed;
          if (leaf.y > 1.2) {
            leaf.y = -0.2;
            leaf.x = math.Random().nextDouble();
          }
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final size = MediaQuery.of(context).size;
          return Stack(
            children: _leaves.map((leaf) {
              return Positioned(
                left: leaf.x * size.width,
                top: leaf.y * size.height,
                child: Transform.rotate(
                  angle: leaf.rotation + (_controller.value * 2 * math.pi * 0.1),
                  child: Icon(
                    leaf.icon,
                    size: leaf.size,
                    color:
                        (widget.isDarkMode ? Colors.greenAccent : Colors.green)
                            .withValues(alpha: 0.1),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class LeafModel {
  double x;
  double y;
  final double speed;
  final double size;
  final double rotation;
  final double initialProgress;
  final IconData icon;

  LeafModel({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.initialProgress,
    required this.icon,
  });
}
