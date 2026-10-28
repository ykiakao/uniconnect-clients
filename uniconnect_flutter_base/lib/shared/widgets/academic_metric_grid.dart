import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AcademicMetric {
  const AcademicMetric(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;
}

class AcademicMetricGrid extends StatelessWidget {
  const AcademicMetricGrid(
      {super.key, required this.metrics, this.onDark = false});

  final List<AcademicMetric> metrics;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : AppColors.primary;
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth >= 260 * scale
          ? 3
          : constraints.maxWidth >= 160 * scale
              ? 2
              : 1;
      final width =
          (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.md,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: width,
              child: Semantics(
                container: true,
                label: '${metric.label}: ${metric.value}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(metric.icon, color: foreground, size: 22),
                    const SizedBox(height: AppSpacing.xs),
                    Text(metric.value,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700)),
                    Text(metric.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: onDark ? Colors.white : AppColors.muted)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}
