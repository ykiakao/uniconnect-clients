import 'package:flutter/material.dart';

import 'app_card.dart';

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({required this.child, super.key});
  final Widget child;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          stops: [
            _controller.value - 0.3,
            _controller.value,
            _controller.value + 0.3,
          ],
          transform: GradientRotation(_controller.value * 2 * 3.14159),
        ).createShader(bounds);
      },
      child: Container(
        color: Colors.grey[300],
        child: widget.child,
      ),
    );
  }
}

class ActivityCardSkeleton extends StatelessWidget {
  const ActivityCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 16,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 12,
                width: double.infinity,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 12,
                width: 200,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardListSkeleton extends StatelessWidget {
  final int itemCount;

  const CardListSkeleton({this.itemCount = 3, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: ActivityCardSkeleton(),
        ),
      ),
    );
  }
}
