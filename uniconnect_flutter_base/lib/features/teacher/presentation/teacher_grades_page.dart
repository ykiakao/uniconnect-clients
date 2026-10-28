import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../../shared/widgets/academic_content.dart';

class TeacherGradesPage extends StatefulWidget {
  const TeacherGradesPage({super.key});

  @override
  State<TeacherGradesPage> createState() => _TeacherGradesPageState();
}

class _TeacherGradesPageState extends State<TeacherGradesPage> {
  final _tableController = ScrollController();

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

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
        child: AcademicContent(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            const StatusBanner(
              title: 'Dados de demonstração',
              message:
                  'Alunos e notas ilustrativos. O lançamento de notas ainda não está integrado; nenhuma alteração será publicada.',
              tone: AppBadgeTone.warning,
            ),
            const SizedBox(height: AppSpacing.md),
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
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Buscar aluno...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              onPressed: null,
              icon: Icons.cloud_upload_outlined,
              label: 'Publicar Notas',
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(builder: (context, constraints) {
              final scale =
                  math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
              final tableWidth = math.max(constraints.maxWidth, 640 * scale);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tableWidth > constraints.maxWidth) ...[
                      const Row(children: [
                        Icon(Icons.swipe_outlined,
                            size: 20, color: AppColors.muted),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                            child: Text('Deslize para ver todas as colunas',
                                style: TextStyle(color: AppColors.muted))),
                      ]),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Scrollbar(
                      controller: _tableController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: SingleChildScrollView(
                        controller: _tableController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SizedBox(
                            width: tableWidth,
                            child: AppCard(
                              child: Column(children: [
                                const _TableHeader(),
                                const Divider(height: AppSpacing.lg),
                                ...rows
                                    .map((row) => _StudentGradeRow(row: row)),
                              ]),
                            )),
                      ),
                    ),
                  ]);
            }),
          ],
        )),
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
          LayoutBuilder(builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns =
                (constraints.maxWidth / (48 * scale)).floor().clamp(1, 4);
            final width =
                (constraints.maxWidth - AppSpacing.xs * (columns - 1)) /
                    columns;
            return Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.md,
                children: [
                  for (final metric in const [
                    _Metric(label: '0-5', value: '2'),
                    _Metric(label: '5-7', value: '5'),
                    _Metric(label: '7-9', value: '18'),
                    _Metric(label: '9-10', value: '8'),
                  ])
                    SizedBox(width: width, child: metric),
                ]);
          }),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = constraints.maxWidth >= 220 * scale ? 2 : 1;
            final width =
                (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                    columns;
            return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final metric in const [
                    _SummaryMetric(label: 'Média da Turma', value: '7.8'),
                    _SummaryMetric(label: 'Alunos Aprovados', value: '84%'),
                  ])
                    SizedBox(width: width, child: metric),
                ]);
          }),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
        Expanded(
            flex: 3,
            child: _HeaderCell('ESTUDANTE', alignment: TextAlign.start)),
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
            child: Align(
              alignment: Alignment.center,
              child: AppBadge(
                label: row.$6,
                tone: warning ? AppBadgeTone.warning : AppBadgeTone.primary,
                compact: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.alignment = TextAlign.center});

  final String text;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: alignment,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}
