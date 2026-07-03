import 'package:flutter/material.dart';
import 'dart:math' as math;


class CubeGridBounceLoader extends StatefulWidget {
  const CubeGridBounceLoader({
    super.key,
    this.gridSize = 4,
    this.cubeSize = 10.0,
    this.duration = const Duration(milliseconds: 1500),
    this.primaryColor,
  });

  final int gridSize;
  final double cubeSize;
  final Duration duration;
  final Color? primaryColor;

  @override
  State<CubeGridBounceLoader> createState() => _CubeGridBounceLoaderState();
}

class _CubeGridBounceLoaderState extends State<CubeGridBounceLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Color? primaryColor;
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCube(int index) {
    final i = index ~/ widget.gridSize;
    final j = index % widget.gridSize;

    final positionFactor = (i + j) / (2 * (widget.gridSize - 1));
    final delay = positionFactor * 0.5;

    final cubeInterval = Interval(
      delay,
      delay + 0.5,
      curve: Curves.easeInOutSine,
    );

    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: cubeInterval,
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final bounceValue = math.sin(animation.value * math.pi);

        final yOffset = bounceValue * -10.0;

        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Container(
            width: widget.cubeSize,
            height: widget.cubeSize,
            decoration: BoxDecoration(
              color: primaryColor!.withValues(alpha: 0.3 + bounceValue * 0.7),
              borderRadius: BorderRadius.circular(2.0),
              boxShadow: [
                BoxShadow(
                  color: primaryColor!.withValues(alpha : bounceValue * 0.6),
                  blurRadius: 5.0,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSpacing = widget.gridSize - 1;
    final totalSize = (widget.gridSize * widget.cubeSize) + (totalSpacing * 4.0);
    primaryColor = widget.primaryColor;
    return Center(
      child: SizedBox(
        width: totalSize,
        height: totalSize,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.gridSize * widget.gridSize,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.gridSize,
            mainAxisSpacing: 4.0,
            crossAxisSpacing: 4.0,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            return _buildCube(index);
          },
        ),
      ),
    );
  }
}