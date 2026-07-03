import 'package:flutter/cupertino.dart';

/// Decorative hollow circle
class Ring extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const Ring({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity), width: 1.5),
      ),
    );
  }
}
