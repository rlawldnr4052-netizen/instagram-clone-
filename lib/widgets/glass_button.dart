import 'dart:ui';
import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;
  final double size;
  final Color? color;

  const GlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
    this.size = 50,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isSelected 
                  ? Colors.white.withOpacity(0.3) 
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.0,
              ),
            ),
            child: Icon(
              icon,
              color: color ?? Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
