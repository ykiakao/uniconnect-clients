import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';

class TeacherGradesPage extends StatelessWidget {
  const TeacherGradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('AC', 'Ana Clara Oliveira', '2024001', '8.5', '--', 'CURSANDO'),
      ('BS', 'Bruno Santos', '2024012', '4.2', '--', 'ALERTA'),
      ('DM', 'Daniela Martins', '2024045', '9.8', '10.0', 'APROVADO'),
      ('EP', 'Eduardo Pereira', '2024098', '7.0', '--', 'CURSANDO'),
    ];

    return Scaffold(
      appBar: const AppHeader(
        title: 'Lançamento de notas',
        fallbackRoute: AppRoutes.teacherDashboard,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'GESTÃO ACADÊMICA',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .9,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lançamento de Notas',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Disciplina: Engenharia de Software II (Turma A)',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _DistributionCard(),
            const SizedBox(height: AppSpacing.md),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Buscar aluno...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Notas publicadas com sucesso.')),
                );
              },
              icon: Icons.cloud_upload_outlined,
              label: 'Publicar Notas',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                children: [
                  const _TableHeader(),
                  const Divider(height: AppSpacing.lg),
                  ...rows.map((row) => _StudentGradeRow(row: row)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribuição',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Expanded(child: _Metric(label: '0-5', value: '2')),
              Expanded(child: _Metric(label: '5-7', value: '5')),
              Expanded(child: _Metric(label: '7-9', value: '18')),
              Expanded(child: _Metric(label: '9-10', value: '8')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(
                child: _SummaryMetric(label: 'Média da Turma', value: '7.8'),
              ),
              Expanded(
                child: _SummaryMetric(label: 'Alunos Aprovados', value: '84%'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 3, child: _HeaderCell('ESTUDANTE')),
        Expanded(child: _HeaderCell('P1')),
        Expanded(child: _HeaderCell('P2')),
        Expanded(flex: 2, child: _HeaderCell('STATUS')),
      ],
    );
  }
}

class _StudentGradeRow extends StatelessWidget {
  const _StudentGradeRow({required this.row});

  final (String, String, String, String, String, String) row;

  @override
  Widget build(BuildContext context) {
    final warning = row.$6 == 'ALERTA';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      warning ? AppColors.secondary : AppColors.primarySoft,
                  child: Text(
                    row.$1,
                    style: TextStyle(
                      color: warning ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        row.$3,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Text(row.$4, textAlign: TextAlign.center)),
          Expanded(child: Text(row.$5, textAlign: TextAlign.center)),
          Expanded(
            flex: 2,
            child: AppBadge(
              label: row.$6,
              tone: warning ? AppBadgeTone.warning : AppBadgeTone.primary,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}
