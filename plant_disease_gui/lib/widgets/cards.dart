import 'package:flutter/material.dart';

class InteractiveCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final VoidCallback? onTap;
  final bool glassEffect;
  final double borderRadius;
  final double borderWidth;
  final bool isDarkMode;

  const InteractiveCard({
    super.key,
    required this.child,
    this.height,
    this.onTap,
    this.glassEffect = true,
    this.borderRadius = 25.0,
    this.borderWidth = 1.5,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (!glassEffect)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            decoration: BoxDecoration(
              color: glassEffect
                  ? (isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.4))
                  : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDarkMode ? Colors.white10 : Colors.black26,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
