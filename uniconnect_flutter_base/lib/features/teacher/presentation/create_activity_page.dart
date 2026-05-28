import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/status_banner.dart';

class CreateActivityPage extends StatefulWidget {
  const CreateActivityPage({super.key});

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final _subjectController =
      TextEditingController(text: 'Arquitetura de Sistemas');
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueController = TextEditingController();
  final _weightController = TextEditingController();
  String? _subjectError;
  String? _titleError;
  String? _descriptionError;
  String? _dueError;
  String? _weightError;

  @override
  void dispose() {
    _subjectController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _dueController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _publish() {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));

    setState(() {
      _subjectError = _subjectController.text.trim().isEmpty
          ? 'Informe a disciplina'
          : null;
      _titleError =
          _titleController.text.trim().isEmpty ? 'Informe o título' : null;
      _descriptionError = _descriptionController.text.trim().length < 10
          ? 'Descreva a atividade com pelo menos 10 caracteres'
          : null;
      _dueError = _dueController.text.trim().isEmpty ? 'Informe o prazo' : null;
      _weightError = weight == null || weight <= 0
          ? 'Informe um peso maior que zero'
          : null;
    });

    if (_subjectError != null ||
        _titleError != null ||
        _descriptionError != null ||
        _dueError != null ||
        _weightError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise os campos destacados.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atividade publicada com sucesso.')),
    );
    _titleController.clear();
    _descriptionController.clear();
    _dueController.clear();
    _weightController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Criar atividade',
        fallbackRoute: AppRoutes.teacherDashboard,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'PORTAL DO PROFESSOR',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .9,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Publicar Nova Atividade Acadêmica',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Defina os parâmetros, prazos e critérios para sua próxima avaliação. O rigor acadêmico começa no planejamento.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _subjectController,
                  onChanged: (_) => _clearError(() => _subjectError = null),
                  decoration: InputDecoration(
                    labelText: 'Selecione a Disciplina',
                    hintText: 'Escolha o curso...',
                    prefixIcon: const Icon(Icons.menu_book_outlined),
                    errorText: _subjectError,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _titleController,
                  onChanged: (_) => _clearError(() => _titleError = null),
                  decoration: InputDecoration(
                    labelText: 'Título da Atividade',
                    hintText: 'Ex: Projeto Semestral de Urbanismo',
                    prefixIcon: const Icon(Icons.title),
                    errorText: _titleError,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  onChanged: (_) => _clearError(() => _descriptionError = null),
                  decoration: InputDecoration(
                    labelText: 'Descrição e Instruções',
                    hintText:
                        'Descreva os objetivos, metodologia e requisitos de entrega...',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    errorText: _descriptionError,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _dueController,
                  onChanged: (_) => _clearError(() => _dueError = null),
                  decoration: InputDecoration(
                    labelText: 'Data de Entrega',
                    hintText: 'mm/dd/yyyy',
                    prefixIcon: const Icon(Icons.event_outlined),
                    errorText: _dueError,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _clearError(() => _weightError = null),
                  decoration: InputDecoration(
                    labelText: 'Valor da Atividade (Pontos)',
                    hintText: '0.0 - 10.0',
                    prefixIcon: const Icon(Icons.percent),
                    errorText: _weightError,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  onPressed: _publish,
                  icon: Icons.publish_outlined,
                  label: 'Publicar Atividade',
                ),
              ],
            ),
          ),
          const StatusBanner(
            title: 'Dica acadêmica',
            message:
                'Certifique-se de anexar a rubrica de avaliação. Atividades com critérios claros aumentam o engajamento dos alunos.',
            tone: AppBadgeTone.warning,
            icon: Icons.lightbulb_outline,
          ),
          const _QuickPreview(),
        ],
      ),
    );
  }

  void _clearError(VoidCallback update) {
    setState(update);
  }
}

class _QuickPreview extends StatelessWidget {
  const _QuickPreview();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VISUALIZAÇÃO RÁPIDA',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          _PreviewLine(
            title: 'Público-alvo',
            text:
                'Todos os alunos matriculados na turma selecionada receberão uma notificação imediata.',
          ),
          SizedBox(height: AppSpacing.md),
          _PreviewLine(
            title: 'Histórico',
            text:
                'Esta atividade será arquivada no portfólio do semestre 2024.1.',
          ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.xxs),
        Text(text, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}
