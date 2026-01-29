import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class LoadingSpinner extends StatefulWidget {
  final double size;
  final Color? color;

  const LoadingSpinner({super.key, this.size = 40.0, this.color});

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          Icons.sports_soccer,
          size: widget.size,
          color: widget.color ?? AppColors.accentGreen,
        ),
      ),
    );
  }
}
