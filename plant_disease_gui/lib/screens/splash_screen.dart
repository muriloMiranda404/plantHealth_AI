import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final bool isDarkMode;
  const SplashScreen({super.key, required this.isDarkMode});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  final List<_Leaf> _leaves = List.generate(25, (i) {
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
    return _Leaf(
      x: math.Random().nextDouble(),
      y: math.Random().nextDouble() * -2.0,
      speed: math.Random().nextDouble() * 0.002 + 0.001,
      size: math.Random().nextDouble() * 40 + 45,
      rotation: math.Random().nextDouble() * 2 * math.pi,
      initialProgress: math.Random().nextDouble(),
      icon: leafIcons[math.Random().nextInt(leafIcons.length)],
    );
  });
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF5F1E8);
    final textColor = widget.isDarkMode ? Colors.greenAccent : Colors.green;
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          ..._leaves.map(
            (leaf) => _FallingLeaf(
              key: ValueKey('leaf_${leaf.hashCode}'),
              leaf: leaf,
              color: textColor,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: textColor.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.eco, size: 80, color: textColor),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  "PLANTGUARD PRO",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "IA Real-Time & IoT",
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Leaf {
  double x;
  double y;
  double speed;
  double size;
  double rotation;
  double initialProgress;
  IconData icon;
  _Leaf({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.initialProgress,
    required this.icon,
  });
}

class _FallingLeaf extends StatefulWidget {
  final _Leaf leaf;
  final Color color;
  const _FallingLeaf({
    required this.leaf,
    required this.color,
    required ValueKey<String> key,
  });
  @override
  State<_FallingLeaf> createState() => _FallingLeafState();
}

class _FallingLeafState extends State<_FallingLeaf>
    with SingleTickerProviderStateMixin {
  late AnimationController _leafController;
  @override
  void initState() {
    super.initState();
    _leafController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _leafController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _leafController,
        builder: (context, child) {
          double progress =
              (_leafController.value + widget.leaf.initialProgress) % 1.0;
          double yPos = (widget.leaf.y + (progress * 2.5)) % 1.5;
          double screenY = (yPos - 0.25) * MediaQuery.of(context).size.height;
          double xOffset =
              math.sin((progress * 2 * math.pi) + widget.leaf.rotation) * 30;
          double screenX =
              (widget.leaf.x * MediaQuery.of(context).size.width) + xOffset;
          return Transform.translate(
            offset: Offset(screenX, screenY),
            child: Transform.rotate(
              angle: widget.leaf.rotation + (progress * 2 * math.pi * 0.5),
              child: Icon(
                widget.leaf.icon,
                size: widget.leaf.size,
                color: widget.color.withValues(alpha: 0.25),
              ),
            ),
          );
        },
      ),
    );
  }
}
