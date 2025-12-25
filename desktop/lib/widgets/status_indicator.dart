import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool isActive;
  final double size;

  const StatusIndicator({
    super.key,
    required this.isActive,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.green : Colors.grey,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
