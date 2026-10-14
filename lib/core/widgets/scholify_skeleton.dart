import 'package:flutter/material.dart';

/// A shimmer-style skeleton placeholder (no external dependency).
///
/// Animates a soft gradient sweep across a rounded block, used while real
/// content loads — far more polished than a bare spinner.
class ScholifySkeleton extends StatefulWidget {
  const ScholifySkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ScholifySkeleton> createState() => _ScholifySkeletonState();
}

class _ScholifySkeletonState extends State<ScholifySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surfaceContainerLowest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton version of a summary metric card — matches the real card layout.
class ScholifyCardSkeleton extends StatelessWidget {
  const ScholifyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ScholifySkeleton(
                    width: 40, height: 40, borderRadius: 12),
                const Spacer(),
                ScholifySkeleton(
                  width: 64,
                  height: 28,
                  borderRadius: 14,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ScholifySkeleton(width: 90, height: 12),
            const SizedBox(height: 8),
            const ScholifySkeleton(width: 56, height: 28),
            const SizedBox(height: 8),
            const ScholifySkeleton(width: double.infinity, height: 6),
          ],
        ),
      ),
    );
  }
}
