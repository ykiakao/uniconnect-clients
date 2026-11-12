import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_badge.dart';
import 'app_card.dart';

/// Building blocks shared by the student and teacher screens, so grades,
/// people and stages look the same on both profiles.

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Round avatar with the person's initials.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppColors.primaryTint, shape: BoxShape.circle),
          child: Text(
            initialsOf(name),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

/// Person row: avatar, name, optional subtitle and badges, trailing widget.
class PersonTile extends StatelessWidget {
  const PersonTile({
    super.key,
    required this.name,
    this.subtitle,
    this.badges = const [],
    this.trailing,
  });

  final String name;
  final String? subtitle;
  final List<Widget> badges;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonAvatar(name: name),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: text.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
              ],
              if (badges.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: badges),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// Label on the left, value on the right; [strong] highlights totals.
class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.strong = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              flex: 3,
              child: Text(label,
                  style: (strong ? text.titleSmall : text.bodyMedium)?.copyWith(
                      color: strong ? AppColors.ink : AppColors.inkMuted)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: strong
                        ? text.titleMedium?.copyWith(color: AppColors.primary)
                        : text.titleSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Aberta" / "Fechada" stage badge.
class StageStateBadge extends StatelessWidget {
  const StageStateBadge({super.key, required this.closed});

  final bool closed;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: closed ? 'Fechada' : 'Aberta',
        tone: closed ? AppBadgeTone.neutral : AppBadgeTone.info,
      );
}

/// Pending assessments of a stage, as a badge.
class PendingBadge extends StatelessWidget {
  const PendingBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: switch (count) {
          0 => 'Nenhuma avaliação pendente',
          1 => '1 avaliação pendente',
          _ => '$count avaliações pendentes',
        },
        tone: count == 0 ? AppBadgeTone.success : AppBadgeTone.warning,
      );
}

/// One report stage (N1/N2): header with state, lines, optional footer.
class StageSummaryCard extends StatelessWidget {
  const StageSummaryCard({
    super.key,
    required this.title,
    required this.closed,
    required this.children,
    this.footer,
  });

  final String title;
  final bool closed;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: '$title • ${closed ? 'Fechada' : 'Aberta'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  const IconTile(icon: LucideIcons.clipboardList, size: 36),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Etapa $title',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  StageStateBadge(closed: closed),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerLeft, child: footer!),
            ],
          ],
        ),
      );
}

/// Semester result label and tone shared by student and teacher.
(String, AppBadgeTone) semesterResult(String status) => switch (status) {
      'approved' => ('Aprovado por média', AppBadgeTone.success),
      'final_exam_eligible' => ('Elegível à prova final', AppBadgeTone.warning),
      'below_minimum' => ('Abaixo da média mínima', AppBadgeTone.danger),
      _ => ('Resultado parcial', AppBadgeTone.neutral),
    };

/// Points with a decimal comma, or a placeholder when unavailable.
String formatPoints(String? value, {String missing = '—'}) =>
    value?.replaceAll('.', ',') ?? missing;
