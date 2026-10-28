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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Criar atividade',
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
              title: 'Protótipo de demonstração',
              message:
                  'Formulário ilustrativo, sem integração de publicação. Nenhuma atividade será enviada ou salva.',
              tone: AppBadgeTone.warning,
            ),
            const SizedBox(height: AppSpacing.md),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabeledField(
                      label: 'Selecione a Disciplina',
                      child: TextField(
                        controller: _subjectController,
                        onChanged: (_) =>
                            _clearError(() => _subjectError = null),
                        decoration: InputDecoration(
                          hintText: 'Escolha o curso...',
                          prefixIcon: const Icon(Icons.menu_book_outlined),
                          errorText: _subjectError,
                        ),
                      )),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                      label: 'Título da Atividade',
                      child: TextField(
                        controller: _titleController,
                        onChanged: (_) => _clearError(() => _titleError = null),
                        decoration: InputDecoration(
                          hintText: 'Ex: Projeto Semestral de Urbanismo',
                          prefixIcon: const Icon(Icons.title),
                          errorText: _titleError,
                        ),
                      )),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                      label: 'Descrição e Instruções',
                      child: TextField(
                        controller: _descriptionController,
                        minLines: 4,
                        maxLines: 6,
                        onChanged: (_) =>
                            _clearError(() => _descriptionError = null),
                        decoration: InputDecoration(
                          hintText:
                              'Descreva os objetivos, metodologia e requisitos de entrega...',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          errorText: _descriptionError,
                        ),
                      )),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                      label: 'Data de Entrega',
                      child: TextField(
                        controller: _dueController,
                        onChanged: (_) => _clearError(() => _dueError = null),
                        decoration: InputDecoration(
                          hintText: 'mm/dd/yyyy',
                          prefixIcon: const Icon(Icons.event_outlined),
                          errorText: _dueError,
                        ),
                      )),
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                      label: 'Valor da Atividade (Pontos)',
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) =>
                            _clearError(() => _weightError = null),
                        decoration: InputDecoration(
                          hintText: '0.0 - 10.0',
                          prefixIcon: const Icon(Icons.percent),
                          errorText: _weightError,
                        ),
                      )),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    onPressed: null,
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
            const SizedBox(height: AppSpacing.md),
            const _QuickPreview(),
          ],
        )),
      ),
    );
  }

  void _clearError(VoidCallback update) {
    setState(update);
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ExcludeSemantics(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
      const SizedBox(height: AppSpacing.xs),
      Semantics(label: label, child: child),
    ]);
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
                'Exemplo ilustrativo de público-alvo. Não há envio de notificações neste protótipo.',
          ),
          SizedBox(height: AppSpacing.md),
          _PreviewLine(
            title: 'Histórico',
            text:
                'Exemplo ilustrativo de histórico. Este protótipo não salva atividades.',
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
