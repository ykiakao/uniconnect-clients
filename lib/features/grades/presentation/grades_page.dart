import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../models/subject_grade.dart';
import '../providers/grades_provider.dart';

class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectGradesProvider);
    final gpa = subjects.isEmpty
        ? 0.0
        : subjects
                .map((subject) => subject.finalAverage)
                .reduce((a, b) => a + b) /
            subjects.length;

    return Scaffold(
      appBar: const AppHeader(
        title: 'Quadro de notas',
        fallbackRoute: AppRoutes.studentDashboard,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 3),
      body: ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _GpaPanel(gpa: gpa),
              const SizedBox(height: AppSpacing.md),
              const _DeanListPanel(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Semestre Atual',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filtrar'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final subject in subjects)
                _SubjectGradeCard(subject: subject),
              const SizedBox(height: AppSpacing.md),
              const _EvolutionPanel(),
              const SizedBox(height: AppSpacing.md),
              const _AverageSimulatorPanel(),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Gerar Histórico (PDF)',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GpaPanel extends StatelessWidget {
  const _GpaPanel({required this.gpa});

  final double gpa;

  @override
  Widget build(BuildContext context) {
    return _BootstrapPanel(
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COEFICIENTE DE RENDIMENTO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                gpa.toStringAsFixed(1),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  ' / 10.0',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Progresso do Curso',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              value: .75,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('75%', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DeanListPanel extends StatelessWidget {
  const _DeanListPanel();

  @override
  Widget build(BuildContext context) {
    return const _BootstrapPanel(
      color: AppColors.successSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.emoji_events_outlined, color: AppColors.success),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lista do Reitor',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  'Parabéns! Seu desempenho acadêmico este semestre te coloca entre os top 5%.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectGradeCard extends StatelessWidget {
  const _SubjectGradeCard({required this.subject});

  final SubjectGrade subject;

  @override
  Widget build(BuildContext context) {
    final approved = subject.finalAverage >= 7;
    final statusColor = approved ? AppColors.success : AppColors.secondary;
    final statusSoft =
        approved ? AppColors.successSoft : AppColors.secondarySoft;

    return _BootstrapPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.subject,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${subject.code} • ${subject.teacher}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Badge(
                  label: approved ? 'APROVADO' : 'EM CURSO',
                  color: statusColor,
                  softColor: statusSoft,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            subject.finalAverage == 0
                ? '--'
                : subject.finalAverage.toStringAsFixed(1),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _EvolutionPanel extends StatelessWidget {
  const _EvolutionPanel();

  @override
  Widget build(BuildContext context) {
    return _BootstrapPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EVOLUÇÃO ACADÊMICA',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Total de Créditos'),
          const SizedBox(height: AppSpacing.xs),
          const Row(
            children: [
              Expanded(child: Text('142 / 180')),
              Text('22.1   22.2   23.1   24.1'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(value: .78, minHeight: 8),
          ),
        ],
      ),
    );
  }
}

class _AverageSimulatorPanel extends StatefulWidget {
  const _AverageSimulatorPanel();

  @override
  State<_AverageSimulatorPanel> createState() => _AverageSimulatorPanelState();
}

class _AverageSimulatorPanelState extends State<_AverageSimulatorPanel> {
  final _p1Controller = TextEditingController();
  final _p2Controller = TextEditingController();
  final _workController = TextEditingController();

  double get _average {
    final p1 = double.tryParse(_p1Controller.text.replaceAll(',', '.')) ?? 0;
    final p2 = double.tryParse(_p2Controller.text.replaceAll(',', '.')) ?? 0;
    final work =
        double.tryParse(_workController.text.replaceAll(',', '.')) ?? 0;
    return (p1 * .35) + (p2 * .35) + (work * .30);
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    _workController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BootstrapPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simulador de média',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'P1 e P2 valem 35%; trabalho vale 30%.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _GradeField('P1', _p1Controller, _refresh)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _GradeField('P2', _p2Controller, _refresh)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _GradeField('Trab.', _workController, _refresh)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Média prevista: ${_average.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _refresh(String _) => setState(() {});
}

class _GradeField extends StatelessWidget {
  const _GradeField(this.label, this.controller, this.onChanged);

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _BootstrapPanel extends StatelessWidget {
  const _BootstrapPanel({
    required this.child,
    this.color = Colors.white,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color == Colors.white ? AppColors.border : Colors.transparent,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.softColor,
  });

  final String label;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}
